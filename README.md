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
├── testdata/
│   └── tfplan.json         # AWSアカウント不要で試せるterraform plan結果のサンプル
└── policy/                 # Conftest/Regoポリシー(対象ごとにディレクトリ・パッケージを分割)
    ├── terraform/          # package terraform
    ├── dockerfile/         # package dockerfile
    └── kubernetes/         # package kubernetes
```

対象ごとにパッケージ名(namespace)を分けているのは、`opa test policy/`のようにポリシー全体を一括テストしたときに、異なる対象向けのルールが同じ`deny`集合へ混ざり込むのを避けるためである。

## ローカルで動かす

```bash
cd app
go vet ./...
go test ./...
go run .
curl http://localhost:8080/healthz          # => ok
```

## ポリシー自体のテスト

各ポリシーは`opa test`によるユニットテストを持つ(`<対象>_test.rego`)。AWSアカウントやDockerイメージを用意せずに、ポリシーの正しさだけを検証できる。

```bash
opa test policy/ -v
```

## Terraformの検証

実際のAWSアカウントで試す場合は、S3バックエンド用のバケットを用意した上で、通常のTerraformワークフローを実行する。

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

AWSアカウントを用意しない場合は、`testdata/tfplan.json`をそのまま使える。

## Conftestでのポリシー検査

ポリシーをパッケージごとに分けているため、`--namespace`で対象を明示する。

```bash
# Terraform plan結果
conftest test --policy policy/terraform --namespace terraform testdata/tfplan.json

# Dockerfile
conftest test --policy policy/dockerfile --namespace dockerfile app/Dockerfile

# Kubernetesマニフェスト
conftest test --policy policy/kubernetes --namespace kubernetes k8s/
```

## このリポジトリの位置づけ

書籍リポジトリ(Zenn)からは git submodule として参照している。書籍本文のコードブロックはこのリポジトリのファイルを正とする。
