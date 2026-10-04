# Changelog

`policy/`のライブラリの変更履歴である。バージョンは、セマンティックバージョニングに従う。

## v2.0.0

### 破壊的な変更

- `kubernetes`: Deploymentの`replicas`が2未満であれば違反とする。v1.1.0では警告だった

## v1.1.0

### 追加

- `kubernetes`: Deploymentの`replicas`が2未満であれば警告する。v2.0.0で違反に変える

## v1.0.0

- 最初のリリース。`terraform`・`dockerfile`・`kubernetes`・`kubernetes_combined`の四つのパッケージと、`lib.image`パッケージを含む
