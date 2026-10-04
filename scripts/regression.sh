#!/usr/bin/env bash
# testdata/consumers/ の各利用者の構成ファイルを、policy/ のポリシーで検査する。
# 結果を利用者ごとの results.json に書き出す。
# 使い方: scripts/regression.sh
set -euo pipefail

cd "$(dirname "$0")/.."

for dir in testdata/consumers/*/; do
  {
    for ns in terraform dockerfile kubernetes; do
      if [ -d "${dir}${ns}" ]; then
        conftest test --no-fail --output json --policy policy --data "${dir}data" \
          --namespace "$ns" "${dir}${ns}"
      fi
    done
    if [ -d "${dir}kubernetes" ]; then
      conftest test --no-fail --output json --policy policy --data "${dir}data" \
        --namespace kubernetes_combined --combine "${dir}kubernetes"
    fi
  } | jq -s '
    # 違反・警告・例外のメッセージだけを残し、ファイル名と名前空間の順に並べる
    [.[][] | {
      filename,
      namespace,
      failures: ([.failures[]?.msg] | sort),
      warnings: ([.warnings[]?.msg] | sort),
      exceptions: ([.exceptions[]?.msg] | sort)
    }] | sort_by(.filename, .namespace)
  ' > "${dir}results.json"
done
