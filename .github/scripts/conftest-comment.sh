#!/usr/bin/env bash
# conftest test --output json の結果を、Pull Requestのコメントとして投稿・更新する。
# 使い方: conftest-comment.sh <見出し> <結果のJSONファイル>
# 環境変数: GH_TOKEN, GH_REPO, PR_NUMBER
set -euo pipefail

title=$1
result=$2
marker="<!-- conftest: ${title} -->"

failures=$(jq '[.[].failures // [] | length] | add // 0' "$result")
warnings=$(jq '[.[].warnings // [] | length] | add // 0' "$result")

{
  echo "$marker"
  echo "### Conftest: ${title}"
  echo
  if [ "$failures" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo "違反はありません。"
  else
    echo "違反 ${failures} 件、警告 ${warnings} 件"
    echo
    echo "| 結果 | ファイル | メッセージ |"
    echo "| --- | --- | --- |"
    jq -r '.[] | .filename as $f
      | ((.failures // [])[] | "| FAIL | `\($f)` | \(.msg) |"),
        ((.warnings // [])[] | "| WARN | `\($f)` | \(.msg) |")' "$result"
  fi
} > comment.md

# 同じ見出しのコメントがあれば更新し、無ければ違反があるときだけ投稿する
comment_id=$(gh api "repos/${GH_REPO}/issues/${PR_NUMBER}/comments" --paginate \
  --jq ".[] | select(.body | startswith(\"${marker}\")) | .id" | tail -n 1)

if [ -n "$comment_id" ]; then
  gh api --method PATCH "repos/${GH_REPO}/issues/comments/${comment_id}" -F body=@comment.md > /dev/null
elif [ "$failures" -gt 0 ] || [ "$warnings" -gt 0 ]; then
  gh pr comment "$PR_NUMBER" --body-file comment.md
fi
