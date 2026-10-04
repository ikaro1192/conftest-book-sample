# EKSクラスタへデプロイするGitHub Actionsのジョブを、VPC内で実行するCodeBuildのランナー

resource "aws_security_group" "runner" {
  name        = "${local.name_prefix}-runner-sg"
  description = "CodeBuild-hosted GitHub Actions runner"
  vpc_id      = data.aws_eks_cluster.main.vpc_config[0].vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-runner-sg"
  }
}

# ランナーからKubernetes APIのエンドポイント(443番ポート)への通信を許可する
resource "aws_vpc_security_group_ingress_rule" "node_from_runner" {
  security_group_id            = data.aws_security_group.node.id
  referenced_security_group_id = aws_security_group.runner.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

data "aws_iam_policy_document" "runner_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "${local.name_prefix}-runner"
  assume_role_policy = data.aws_iam_policy_document.runner_assume.json
}

data "aws_iam_policy_document" "runner" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}-runner*"]
  }

  # VPC内で実行するためのネットワークインターフェースの操作
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:ap-northeast-1:${data.aws_caller_identity.current.account_id}:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "codeconnections:GetConnectionToken",
      "codeconnections:GetConnection",
      "codeconnections:UseConnection",
    ]
    resources = [var.codeconnections_arn]
  }

  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [data.aws_eks_cluster.main.arn]
  }
}

resource "aws_iam_role_policy" "runner" {
  name   = "runner"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.runner.json
}

resource "aws_codebuild_project" "runner" {
  name         = "${local.name_prefix}-runner"
  service_role = aws_iam_role.runner.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type     = "GITHUB"
    location = "https://github.com/${var.github_repository}.git"

    auth {
      type     = "CODECONNECTIONS"
      resource = var.codeconnections_arn
    }
  }

  vpc_config {
    vpc_id             = data.aws_eks_cluster.main.vpc_config[0].vpc_id
    subnets            = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.runner.id]
  }

  depends_on = [aws_iam_role_policy.runner]
}

# ワークフローのジョブがキューに入ったときに、CodeBuildのビルドとしてランナーを起動する
resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }
  }
}

# ランナーのロールに、defaultの名前空間の編集権限を与える
resource "aws_eks_access_entry" "runner" {
  cluster_name  = data.aws_eks_cluster.main.name
  principal_arn = aws_iam_role.runner.arn
}

resource "aws_eks_access_policy_association" "runner" {
  cluster_name  = data.aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.runner.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }
}
