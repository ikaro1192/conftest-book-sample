# conftest-book-sample

書籍「**ConftestではじめるPolicy as Code**」のサンプルコードである。書籍の各章で説明するコードを、実際に動く一つのモノレポとしてまとめている。

## 構成

```text
.
├── app/                    # Goアプリケーション(ヘルスチェックのみの最小HTTP API)
│   ├── main.go
│   ├── main_test.go
│   └── Dockerfile          # distroless nonrootによるマルチステージビルド
├── terraform/              # VPC・Amazon EKSクラスタ・ノードグループ・IAM
├── k8s/                    # アプリケーションのDeployment・Service
└── policy/                 # Conftest/Regoポリシー(対象ごとにディレクトリを分割)
    ├── terraform/
    ├── dockerfile/
    └── kubernetes/
```

## ローカルで動かす

```bash
cd app
go vet ./...
go test ./...
go run .
curl http://localhost:8080/healthz          # => ok
```

## Terraformの検証

AWSアカウントとS3バックエンド用のバケットを用意した上で、通常のTerraformワークフローを実行する。

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

## Conftestでのポリシー検査

```bash
# Terraform plan結果
conftest test --policy policy/terraform tfplan.json

# Dockerfile
conftest test --policy policy/dockerfile app/Dockerfile

# Kubernetesマニフェスト
conftest test --policy policy/kubernetes k8s/
```

## このリポジトリの位置づけ

書籍リポジトリ(Zenn)からは git submodule として参照している。書籍本文のコードブロックはこのリポジトリのファイルを正とする。
