# Changelog

`policy/`のライブラリの変更履歴である。バージョンは、セマンティックバージョニングに従う。

## v1.1.0

### 追加

- `kubernetes`: Deploymentの`replicas`が2未満であれば警告する。v2.0.0で違反に変える

## v1.0.0

- 最初のリリース。`terraform`・`dockerfile`・`kubernetes`・`kubernetes_combined`の四つのパッケージと、`lib.image`パッケージを含む
