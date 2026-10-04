locals {
  name_prefix = "${var.project}-${var.env}"

  # terraform/ のstateのロックファイル
  tfstate_lock_key = "terraform.tfstate.tflock"
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "main" {
  name = local.name_prefix
}

data "aws_ecr_repository" "app" {
  name = "${local.name_prefix}-app"
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_security_group" "node" {
  name   = "${local.name_prefix}-node-sg"
  vpc_id = data.aws_eks_cluster.main.vpc_config[0].vpc_id
}
