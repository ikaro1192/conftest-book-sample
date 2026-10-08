variable "project" {
  type    = string
  default = "conftest-book"
}

variable "env" {
  type    = string
  default = "dev"
}

# OIDCトークンのsubの接頭辞(repo:<owner>@<owner_id>/<repo>@<repo_id>)
variable "github_oidc_sub_prefix" {
  type = string
}

# GitHubと連携済みのCodeConnectionsの接続のARN
variable "codeconnections_arn" {
  type = string
}

# Argo CDの認証に使うIAM Identity Centerのインスタンス
variable "idc_instance_arn" {
  type = string
}

# Argo CDの管理者とするIAM Identity CenterのユーザーのID
variable "argocd_admin_user_id" {
  type = string
}

# terraform/ のstateを保存するS3バケット
variable "tfstate_bucket" {
  type = string
}
