locals {
  name_prefix = "${var.project}-${var.env}"

  subnets = {
    "public-a" = { az = "ap-northeast-1a", cidr = "10.0.0.0/24", tier = "public" }
    "public-c" = { az = "ap-northeast-1c", cidr = "10.0.1.0/24", tier = "public" }
    "node-a"   = { az = "ap-northeast-1a", cidr = "10.0.10.0/24", tier = "private" }
    "node-c"   = { az = "ap-northeast-1c", cidr = "10.0.11.0/24", tier = "private" }
  }
}
