# conftest-book-sample

書籍「**ConftestではじめるPolicy as Code**」のサンプルコードである。書籍の各章で説明するコードを、実際に動く一つのモノレポとしてまとめている。

## 構成

```text
.
├── app/                    # Goアプリケーション(ヘルスチェックのみの最小HTTP API)
│   ├── main.go
│   ├── main_test.go
│   └── Dockerfile          # distroless nonrootによるマルチステージビルド
├── terraform/              # VPC・Amazon EKSクラスタ・ノードグループ・IAM・ECRリポジトリ
│   └── ci/                 # GitHub ActionsのOIDCプロバイダ・IAMロール・CodeBuildのランナー
├── k8s/                    # アプリケーションのDeployment・Service・ServiceAccountとkustomization.yaml
├── deploy/dev/             # デプロイ用のKustomizeのオーバーレイ(イメージはCIで置き換える)
├── .github/                # GitHub Actionsのワークフロー(terraform/app/policy)
├── .regal/config.yaml      # Regalの設定
├── .pre-commit-config.yaml # pre-commitの設定
├── conftest.toml           # --policy policy と --data data の指定
├── data/
│   ├── allowlist.yaml      # ポリシーが参照する許可リスト
│   └── exceptions.yaml     # Conftestのexceptionルールが参照する例外の一覧
├── testdata/
│   ├── tfplan.json         # AWSアカウント不要で試せるterraform plan結果(規約に準拠)
│   └── tfplan_bad.json     # 同上(規約違反を含む構成)
└── policy/                 # Conftest/Regoポリシー(対象ごとにディレクトリ・パッケージを分割)
    ├── terraform/          # package terraform
    ├── dockerfile/         # package dockerfile
    ├── kubernetes/         # package kubernetes(exception.rego に例外のルール)
    ├── kubernetes_combined/ # package kubernetes_combined(--combine で複数ファイルをまとめて検査)
    └── lib/                # package lib.image(共通の関数。denyを持たない)
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

実際のAWSアカウントで試す場合は、S3バックエンド用のバケットを用意した上で、通常のTerraformワークフローを実行する。バケットを用意しない場合は、`terraform/backend_override.tf`に`terraform { backend "local" {} }`を書けばローカルのstateで実行できる(`*_override.tf`はGit管理対象外)。

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

AWSアカウントを用意しない場合は、`testdata/tfplan.json`・`testdata/tfplan_bad.json`をそのまま使える。

## Conftestでのポリシー検査

ポリシーをパッケージごとに分けているため、`--namespace`で対象を明示する。`--policy policy`と`--data data`は`conftest.toml`に書いてある。`policy/lib/`の共通の関数を読み込むため、`--policy`には`policy/`全体を指定する。

```bash
# Terraform plan結果
conftest test --namespace terraform testdata/tfplan.json

# Dockerfile
conftest test --namespace dockerfile app/Dockerfile

# Kubernetesマニフェスト
conftest test --namespace kubernetes k8s/

# Kubernetesマニフェストの組み合わせ(Serviceのselectorなど)
conftest test --namespace kubernetes_combined --combine k8s/

# Kustomizeで生成したマニフェスト
kubectl kustomize k8s | conftest test --namespace kubernetes -
```

コマンドラインで`--data`を指定すると、`conftest.toml`の`data`は使われない。ポリシーが参照するデータは`data/`に置く。

## CI/CD

`.github/workflows/`の三つのワークフローで、Conftestの検査をCI/CDに組み込んでいる。

| ワークフロー | Pull Request | mainブランチ |
| --- | --- | --- |
| `terraform.yml` | plan、検査、結果をコメント | plan、検査、apply |
| `app.yml` | Dockerfileとマニフェストの検査、ビルド | 検査、ECRへのpush、VPC内のCodeBuildランナーからデプロイ |
| `policy.yml` | `opa fmt`・`opa check --strict`・`opa test`・`regal lint` | 同左 |

AWSへの認証はGitHub ActionsのOIDCトークンで行う。必要なIAMロールとランナーは`terraform/ci/`にあり、手元から適用する。

```bash
terraform -chdir=terraform/ci init -backend-config="bucket=<stateのバケット>"
terraform -chdir=terraform/ci apply \
  -var="github_repository=<owner>/conftest-book-sample" \
  -var="github_oidc_sub_prefix=$(gh api repos/<owner>/conftest-book-sample/actions/oidc/customization/sub --jq .sub_claim_prefix)" \
  -var="codeconnections_arn=<CodeConnectionsの接続のARN>" \
  -var="tfstate_bucket=<stateのバケット>"
```

ワークフローは、リポジトリの変数`TFSTATE_BUCKET`・`AWS_PLAN_ROLE_ARN`・`AWS_APPLY_ROLE_ARN`・`AWS_ECR_PUSH_ROLE_ARN`・`ECR_REPOSITORY_URL`を参照する。

手元では、pre-commitで同じ検査を実行できる。

```bash
pre-commit install
pre-commit run --all-files
```

## OCIレジストリでのポリシー配布

`policy/`配下はGitHub Actions(`.github/workflows/policy-publish.yml`)によって、GitHub Container Registry(GHCR)にOPAバンドルとしてpushされる。`main`ブランチの`policy/**`が変更されたとき、またはワークフローの手動実行で動く。

```bash
# ワークフロー内で実行している内容(ローカルでも同様に実行できる)
conftest push ghcr.io/ikaro1192/conftest-book-sample/policy:latest
```

他のリポジトリやCI環境からは、`conftest pull`でこのバンドルを取得して使う。

```bash
conftest pull ghcr.io/ikaro1192/conftest-book-sample/policy:latest
conftest test --policy policy --namespace kubernetes k8s/
```

バージョンを固定して参照したい場合は、`:latest`の代わりにコミットSHAのタグ(`conftest push`で同時にpushされる)を指定する。

GHCRのパッケージ可視性は、リンク先リポジトリの可視性を自動では継承しない。このリポジトリはprivateであり、個人アカウント配下で新規publishするパッケージのデフォルト可視性もprivateである。ただし、意図したとおりになっているかはGitHubのパッケージ設定画面(`https://github.com/users/ikaro1192/packages/container/package/conftest-book-sample%2Fpolicy`)で確認しておくこと。

## このリポジトリの位置づけ

書籍リポジトリ(Zenn)からは git submodule として参照している。書籍本文のコードブロックはこのリポジトリのファイルを正とする。
