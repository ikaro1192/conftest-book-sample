# METADATA
# title: Dockerfileの規約
# description: conftest が解析したDockerfileの命令の配列を検査する。
package dockerfile

import data.lib.image

is_dockerfile if {
	some cmd in input
	lower(cmd.Cmd) == "from"
}

from_instructions contains cmd if {
	is_dockerfile
	some cmd in input
	lower(cmd.Cmd) == "from"
}

stage_names contains name if {
	some cmd in from_instructions
	count(cmd.Value) == 3
	lower(cmd.Value[1]) == "as"
	name := cmd.Value[2]
}

base_images contains ref if {
	some cmd in from_instructions
	ref := cmd.Value[0]
	not ref in stage_names
	ref != "scratch"
}

# METADATA
# scope: rule
# title: ベースイメージのタグを固定する
# description: FROM のイメージに、latest 以外のタグかダイジェストを指定する。
# custom:
#   remediation: "golang:1.27 のようにタグを書くか、@sha256: に続けてダイジェストを書く。"
deny contains msg if {
	some ref in base_images
	not image.pinned(ref)
	msg := sprintf("base image %q must not use the \"latest\" tag", [ref])
}

# METADATA
# scope: rule
# title: ベースイメージを許可リストに限る
# description: FROM のイメージのリポジトリは、data.allowlist.dockerfile_base_image_repositories のいずれかとする。
# custom:
#   remediation: 許可リストにあるリポジトリを使う。別のリポジトリが必要な場合は、利用側の許可リストに加える。
deny contains msg if {
	some ref in base_images
	repository := image.repository(ref)
	not allowed_repository(repository)
	msg := sprintf("base image %q (repository %q) is not in the allowlist", [ref, repository])
}

allowed_repository(repository) if {
	repository in data.allowlist.dockerfile_base_image_repositories
}

final_stage := max({cmd.Stage | some cmd in from_instructions})

final_stage_users := [cmd.Value[0] |
	some cmd in input
	cmd.Stage == final_stage
	lower(cmd.Cmd) == "user"
]

# METADATA
# scope: rule
# title: 最終ステージでUSERを指定する
# description: 最終ステージに USER 命令が無いと、コンテナは root で動く。
# custom:
#   remediation: 最終ステージに USER nonroot や USER 10001 のように、root 以外のユーザーを書く。
deny contains msg if {
	is_dockerfile
	count(final_stage_users) == 0
	msg := "Dockerfile must set a non-root USER"
}

# METADATA
# scope: rule
# title: 最終ステージでrootをUSERにしない
# description: 最終ステージの最後の USER 命令のユーザーは、root と 0 以外とする。
# custom:
#   remediation: 最終ステージの USER に、root 以外のユーザーを書く。
deny contains msg if {
	user := final_stage_users[count(final_stage_users) - 1]
	split(user, ":")[0] in {"root", "0"}
	msg := sprintf("final stage must not run as root user %q", [user])
}

# METADATA
# scope: rule
# title: ADDではなくCOPYを使う
# description: ADD は、URLからの取得とアーカイブの展開も行う。ファイルのコピーには COPY を使う。
# related_resources:
#   - ref: https://docs.docker.com/build/building/best-practices/#add-or-copy
# custom:
#   remediation: ADD を COPY に書き換える。
warn contains msg if {
	is_dockerfile
	some cmd in input
	lower(cmd.Cmd) == "add"
	msg := sprintf("use COPY instead of ADD: %s", [concat(" ", cmd.Value)])
}
