#!/usr/bin/env bash
# policy/ のMETADATAアノテーションから、ルールの一覧を docs/policies.md に書き出す。
# 使い方: scripts/policy-docs.sh
set -euo pipefail

cd "$(dirname "$0")/.."

{
  printf '# ポリシーの一覧\n\n'
  printf 'このファイルは`scripts/policy-docs.sh`で生成する。直接編集しない。\n\n'
  opa inspect --annotations --format json policy/ | jq -r '
    def pkg: if .annotations.scope == "package" then .path[1:] else .path[1:-1] end | map(.value) | join(".");

    .annotations | group_by(pkg)[]
    | (map(select(.annotations.scope == "package"))[0].annotations) as $pkg
    | (map(select(.annotations.scope == "rule")) | sort_by(.location.file, .location.row)) as $rules
    | select($rules | length > 0)
    | "## `\(.[0] | pkg)`: \($pkg.title)",
      "",
      $pkg.description,
      "",
      ($rules[] |
        "### \(.annotations.title)",
        "",
        "| 項目 | 内容 |",
        "| --- | --- |",
        "| ルール | `\(.path[-1].value)` |",
        "| ファイル | `\(.location.file)` |",
        "| 説明 | \(.annotations.description) |",
        "| 修正方法 | \(.annotations.custom.remediation // "-") |",
        "| 参考 | \([.annotations.related_resources[]?.ref] | join("<br>") | if . == "" then "-" else . end) |",
        "")
  '
} >| docs/policies.md
