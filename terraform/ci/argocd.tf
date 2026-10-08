# EKS CapabilitiesのArgo CD。mainブランチのマニフェストをクラスタに同期する

data "aws_iam_policy_document" "argocd_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "argocd" {
  name               = "${local.name_prefix}-argocd"
  assume_role_policy = data.aws_iam_policy_document.argocd_assume.json
}

# CodeConnectionsの接続で、GitHubのリポジトリを取得する
data "aws_iam_policy_document" "argocd" {
  statement {
    actions   = ["codeconnections:UseConnection"]
    resources = [var.codeconnections_arn]
  }
}

resource "aws_iam_role_policy" "argocd" {
  name   = "argocd"
  role   = aws_iam_role.argocd.id
  policy = data.aws_iam_policy_document.argocd.json
}

resource "aws_eks_capability" "argocd" {
  cluster_name              = data.aws_eks_cluster.main.name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.argocd.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      namespace = "argocd"

      aws_idc {
        idc_instance_arn = var.idc_instance_arn
        idc_region       = "ap-northeast-1"
      }

      rbac_role_mapping {
        role = "ADMIN"

        identity {
          id   = var.argocd_admin_user_id
          type = "SSO_USER"
        }
      }
    }
  }

  depends_on = [aws_iam_role_policy.argocd]
}

# EKSは、capabilityのロールのアクセスエントリを作成する。ただし、Kubernetesの権限は与えない
# クラスタ全体の読み取りと、defaultの名前空間の編集を与える
resource "aws_eks_access_policy_association" "argocd_view" {
  cluster_name  = data.aws_eks_cluster.main.name
  principal_arn = aws_iam_role.argocd.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_capability.argocd]
}

resource "aws_eks_access_policy_association" "argocd_edit" {
  cluster_name  = data.aws_eks_cluster.main.name
  principal_arn = aws_iam_role.argocd.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [aws_eks_capability.argocd]
}
