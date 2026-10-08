locals {
  account_id = data.aws_caller_identity.current.account_id

  # terraform/ が作成するIAMロール
  apply_managed_roles = [
    "arn:aws:iam::${local.account_id}:role/${local.name_prefix}-eks-cluster",
    "arn:aws:iam::${local.account_id}:role/${local.name_prefix}-eks-node",
  ]

  # terraform/ がIAMロールに付けるAWS管理ポリシー
  apply_attachable_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]

  # terraform/ がEC2の作成時に付けるタグ(default_tags)
  apply_ec2_create_actions = [
    "ec2:CreateVpc",
    "ec2:CreateSubnet",
    "ec2:CreateInternetGateway",
    "ec2:AllocateAddress",
    "ec2:CreateNatGateway",
    "ec2:CreateRouteTable",
    "ec2:CreateSecurityGroup",
  ]
}

# applyのロールの権限。読み取りはReadOnlyAccessで許可し、変更は terraform/ のリソースに限る
resource "aws_iam_role_policy_attachment" "apply_read_only" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "apply" {
  # stateとロックファイルの書き込み
  statement {
    sid     = "State"
    actions = ["s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tfstate_bucket}/terraform.tfstate",
      "arn:aws:s3:::${var.tfstate_bucket}/${local.tfstate_lock_key}",
    ]
  }

  # IAMロールの作成・変更は、terraform/ のロールに限る
  statement {
    sid = "IamRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = local.apply_managed_roles
  }

  # ロールに付けられるポリシーを、EKSのAWS管理ポリシーに限る
  statement {
    sid       = "IamAttachEksPolicies"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = local.apply_managed_roles

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = local.apply_attachable_policies
    }
  }

  # ロールを渡せる先を、EKSに限る
  statement {
    sid       = "IamPassRoleToEks"
    actions   = ["iam:PassRole"]
    resources = local.apply_managed_roles

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com"]
    }
  }

  statement {
    sid       = "IamEksServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com"]
    }
  }

  statement {
    sid = "Eks"
    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:AssociateEncryptionConfig",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "eks:TagResource",
      "eks:UntagResource",
    ]
    resources = [
      "arn:aws:eks:ap-northeast-1:${local.account_id}:cluster/${local.name_prefix}",
      "arn:aws:eks:ap-northeast-1:${local.account_id}:nodegroup/${local.name_prefix}/*",
    ]
  }

  statement {
    sid = "Ecr"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutImageTagMutability",
      "ecr:PutImageScanningConfiguration",
      "ecr:TagResource",
      "ecr:UntagResource",
    ]
    resources = ["arn:aws:ecr:ap-northeast-1:${local.account_id}:repository/${local.name_prefix}-*"]
  }

  # KMSキーは、作成時にタグを付けたものに限る
  statement {
    sid       = "KmsCreate"
    actions   = ["kms:CreateKey", "kms:TagResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Env"
      values   = [var.env]
    }
  }

  statement {
    sid = "KmsTagged"
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:UpdateKeyDescription",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
    ]
    resources = ["arn:aws:kms:ap-northeast-1:${local.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Env"
      values   = [var.env]
    }
  }

  # EC2のリソースは、作成時にタグを付けたものに限る
  statement {
    sid       = "Ec2Create"
    actions   = local.apply_ec2_create_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Env"
      values   = [var.env]
    }
  }

  statement {
    sid       = "Ec2TagOnCreate"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = [for a in local.apply_ec2_create_actions : trimprefix(a, "ec2:")]
    }
  }

  # Elastic IPの関連付けの解除は、リソースを単位としないため、タグで限定できない
  statement {
    sid       = "Ec2Untaggable"
    actions   = ["ec2:DisassociateAddress"]
    resources = ["*"]
  }

  statement {
    sid = "Ec2Tagged"
    actions = concat(local.apply_ec2_create_actions, [
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:ModifyVpcAttribute",
      "ec2:ModifySubnetAttribute",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateRoute",
      "ec2:ReplaceRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ReleaseAddress",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteSubnet",
      "ec2:DeleteVpc",
    ])
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Env"
      values   = [var.env]
    }
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}
