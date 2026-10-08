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
│   └── ci/                 # 付録B: GitHub ActionsのOIDCプロバイダ・IAMロール。付録D: Argo CD(EKS Capabilities)
├── k8s/                    # アプリケーションのDeployment・Service・ServiceAccountとkustomization.yaml
├── deploy/dev/             # 付録D: デプロイ用のKustomizeのオーバーレイ(イメージはCIで置き換える)
├── .github/                # GitHub Actionsのワークフロー(terraform/app/policy)
├── .regal/config.yaml      # Regalの設定
├── .pre-commit-config.yaml # pre-commitの設定
├── conftest.toml           # --policy policy と --data data の指定
├── data/
│   ├── allowlist.yaml      # ポリシーが参照する許可リスト
│   └── exceptions.yaml     # Conftestのexceptionルールが参照する例外の一覧
├── testdata/
│   ├── tfplan.json         # AWSアカウント不要で試せるterraform plan結果(規約に準拠)
│   ├── tfplan_bad.json     # 同上(規約違反を含む構成)
│   ├── tfplan_policy_unknown.json # IAMポリシーにクラスタのARNを埋め込んだ構成(policyがapplyまで決まらない)
│   └── tfplan_policy_known.json   # 同上で、ARNをplan時点で決まる値から組み立てた構成
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

AWSアカウントを用意しない場合は、`testdata/`のplan結果をそのまま使える。

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

## CI

`.github/workflows/`の三つのワークフローで、Conftestの検査をCIに組み込んでいる。AWSの認証情報は使わない。

| ワークフロー | 内容 |
| --- | --- |
| `terraform.yml` | `testdata/tfplan.json`を、変更したポリシーとデータで検査し、結果をPull Requestにコメントする。`terraform plan`は実行しない |
| `app.yml` | Dockerfileと、`k8s/`からKustomizeで生成したマニフェストを検査し、結果をPull Requestにコメントする。検査を通ったらコンテナイメージをビルドする |
| `policy.yml` | `opa fmt`・`opa check --strict`・`opa test`・`regal lint` |

検査の結果は、ジョブのサマリーにも書く。forkからのPull Requestでは、コメントせずにサマリーにだけ書く。アクションはコミットのSHAで固定し、Dependabotで更新する。

手元では、pre-commitで同じ検査を実行できる。

```bash
pre-commit install
pre-commit run --all-files
```

## 付録B: GitHub Actions用のAWSリソース

GitHub ActionsのOIDCプロバイダとIAMロールは`terraform/ci/`にあり、手元から適用する。

```bash
terraform -chdir=terraform/ci init -backend-config="bucket=<stateのバケット>"
terraform -chdir=terraform/ci apply \
  -var="github_oidc_sub_prefix=$(gh api repos/<owner>/conftest-book-sample/actions/oidc/customization/sub --jq .sub_claim_prefix)" \
  -var="tfstate_bucket=<stateのバケット>"
```

## 付録C: Terraformのplanとapply

付録Cでは、`terraform.yml`を、AWSに接続してplanとapplyを実行するものに置き換える。

| ワークフロー | Pull Request | mainブランチ |
| --- | --- | --- |
| `terraform.yml` | plan、検査、結果をコメント | plan、検査、apply |

applyのジョブはEnvironment `production`(mainブランチに限定)で実行する。ワークフローは、リポジトリの変数`TFSTATE_BUCKET`・`AWS_PLAN_ROLE_ARN`・`AWS_APPLY_ROLE_ARN`を参照する。

## 付録D: Argo CDとデプロイ

付録Dでは、`terraform/ci/`にArgo CD(EKS Capabilities)を加える。IAM Identity CenterのインスタンスとArgo CDの管理者のユーザー、GitHubとのCodeConnectionsの接続は、あらかじめコンソールで作成しておく。

```bash
terraform -chdir=terraform/ci apply \
  -var="github_oidc_sub_prefix=$(gh api repos/<owner>/conftest-book-sample/actions/oidc/customization/sub --jq .sub_claim_prefix)" \
  -var="codeconnections_arn=<CodeConnectionsの接続のARN>" \
  -var="idc_instance_arn=<IAM Identity CenterのインスタンスのARN>" \
  -var="argocd_admin_user_id=<Argo CDの管理者のユーザーのID>" \
  -var="tfstate_bucket=<stateのバケット>"
```

Argo CDへのクラスタとApplicationの登録は、Argo CDのUIで発行したトークンを使い、`argocd` CLIで行う。

また、`app.yml`を、AWSに接続するものに置き換える。

| ワークフロー | Pull Request | mainブランチ |
| --- | --- | --- |
| `app.yml` | Dockerfileとマニフェストの検査、結果をコメント、ビルド | 検査、ECRへのpush、`deploy/dev/`のイメージを書き換えて検査し、mainブランチにコミット |

クラスタへの適用は、Argo CDが`deploy/dev/`をmainブランチから同期して行う。ワークフローは、リポジトリの変数`AWS_ECR_PUSH_ROLE_ARN`・`ECR_REPOSITORY_URL`を参照する。

## OCIレジストリでのポリシー配布

`policy/`配下はGitHub Actions(`.github/workflows/policy-publish.yml`)によって、GitHub Container Registry(GHCR)にOPAバンドルとしてpushされる。ワークフローを手動で実行したときだけ動く。

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
