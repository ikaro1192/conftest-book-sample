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
├── k8s/                    # アプリケーションのDeployment・Service・ServiceAccountとkustomization.yaml
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
│   ├── tfplan_policy_known.json   # 同上で、ARNをplan時点で決まる値から組み立てた構成
│   └── consumers/          # ポリシーの利用者の構成ファイルと検査結果(回帰テスト用)
├── scripts/
│   ├── regression.sh       # testdata/consumers/ を検査し、results.json を書き出す
│   └── policy-docs.sh      # METADATAアノテーションから docs/policies.md を生成する
├── docs/policies.md        # ルールの一覧(生成物)
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
| `policy.yml` | `opa fmt`・`opa check --strict`・`opa test`・`regal lint`・回帰テスト・ドキュメントの確認。mainブランチではGHCRへのポリシーのpush |

検査の結果は、ジョブのサマリーにも書く。forkからのPull Requestでは、コメントせずにサマリーにだけ書く。アクションはコミットのSHAで固定し、Dependabotで更新する。

手元では、pre-commitで同じ検査を実行できる。

```bash
pre-commit install
pre-commit run --all-files
```

## ポリシーの回帰テストとドキュメント

`testdata/consumers/`には、ポリシーの利用者ごとの構成ファイル・データと、検査の結果(`results.json`)を置いている。ポリシーを変更したら、次のスクリプトで結果を書き出し、差分を確認する。

```bash
scripts/regression.sh
git diff testdata/consumers/
```

ルールの一覧`docs/policies.md`は、各ルールの`# METADATA`アノテーションから生成する。

```bash
scripts/policy-docs.sh
```

CIでは、どちらも実行後に`git diff --exit-code`で差分が無いことを確かめる。

## OCIレジストリでのポリシー配布

`policy/`配下は、`.github/workflows/policy.yml`の`publish`ジョブによって、GitHub Container Registry(GHCR)にOPAバンドルとしてpushされる。mainブランチで`test`ジョブが成功したときに動く。タグはコミットのSHAであり、pushしたバンドルのダイジェストはジョブのサマリーに表示される。

`conftest push`と`conftest pull`は`conftest.toml`の`policy`(配列)を読まないため、`--policy`を明示する。

```bash
# ワークフロー内で実行している内容
conftest push --policy policy ghcr.io/<owner>/conftest-book-sample/policy:<コミットのSHA>
```

他のリポジトリからは、ダイジェストで固定して取得する。取得の前に、古いファイルが残らないようにディレクトリを削除する。

```bash
rm -rf vendor
conftest pull --policy vendor ghcr.io/<owner>/conftest-book-sample/policy:<コミットのSHA>@sha256:<ダイジェスト>
conftest test --policy vendor --namespace kubernetes k8s/
```

GHCRのパッケージ可視性は、パッケージの設定画面で確認する。privateのパッケージを他のリポジトリのワークフローから取得するには、パッケージの設定でそのリポジトリに読み取りの権限を与える。

## このリポジトリの位置づけ

書籍リポジトリ(Zenn)からは git submodule として参照している。書籍本文のコードブロックはこのリポジトリのファイルを正とする。
