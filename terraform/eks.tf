resource "aws_kms_key" "eks" {
  description         = "EKS secrets encryption for ${local.name_prefix}"
  enable_key_rotation = true
}

resource "aws_eks_cluster" "main" {
  name     = local.name_prefix
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = [
      for k, v in local.subnets : aws_subnet.this[k].id
    ]
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.node.id]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-default"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    for k, v in local.subnets : aws_subnet.this[k].id if v.tier == "private"
  ]

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}
