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
