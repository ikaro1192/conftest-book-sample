variable "project" {
  type    = string
  default = "conftest-book"
}

variable "env" {
  type    = string
  default = "dev"
}

# GitHubのリポジトリ(<owner>/<repo>)
variable "github_repository" {
  type = string
}

# GitHubと連携済みのCodeConnectionsの接続のARN
variable "codeconnections_arn" {
  type = string
}

# terraform/ のstateを保存するS3バケット
variable "tfstate_bucket" {
  type = string
}
