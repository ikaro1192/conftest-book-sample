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

deny contains msg if {
	some ref in base_images
	not image.pinned(ref)
	msg := sprintf("base image %q must not use the \"latest\" tag", [ref])
}

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

final_stage_users := [user |
	some cmd in input
	cmd.Stage == final_stage
	lower(cmd.Cmd) == "user"
	user := cmd.Value[0]
]

deny contains msg if {
	is_dockerfile
	count(final_stage_users) == 0
	msg := "Dockerfile must set a non-root USER"
}

deny contains msg if {
	user := final_stage_users[count(final_stage_users) - 1]
	split(user, ":")[0] in {"root", "0"}
	msg := sprintf("final stage must not run as root user %q", [user])
}

warn contains msg if {
	is_dockerfile
	some cmd in input
	lower(cmd.Cmd) == "add"
	msg := sprintf("use COPY instead of ADD: %s", [concat(" ", cmd.Value)])
}
