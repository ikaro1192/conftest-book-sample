package dockerfile

instruction(stage, cmd, value) := {"Cmd": cmd, "Stage": stage, "Value": value}

allowed_repositories := ["public.ecr.aws/docker/library/golang", "gcr.io/distroless/static-debian12"]

compliant := [
	instruction(0, "from", ["public.ecr.aws/docker/library/golang:1.23", "AS", "build"]),
	instruction(0, "run", ["go build -o /app/server ."]),
	instruction(1, "from", ["gcr.io/distroless/static-debian12:nonroot"]),
	instruction(1, "copy", ["/app/server", "/server"]),
	instruction(1, "user", ["nonroot:nonroot"]),
	instruction(1, "entrypoint", ["/server"]),
]

test_compliant_dockerfile_is_allowed if {
	count(deny) == 0 with input as compliant
		with data.allowlist.dockerfile_base_image_repositories as allowed_repositories
	count(warn) == 0 with input as compliant
}

test_latest_tag_is_denied if {
	mock := [
		instruction(0, "from", ["public.ecr.aws/docker/library/golang:latest"]),
		instruction(0, "user", ["nonroot"]),
	]

	"base image \"public.ecr.aws/docker/library/golang:latest\" must not use the \"latest\" tag" in deny with input as mock
}

test_missing_tag_is_denied if {
	mock := [
		instruction(0, "from", ["public.ecr.aws/docker/library/golang"]),
		instruction(0, "user", ["nonroot"]),
	]

	"base image \"public.ecr.aws/docker/library/golang\" must not use the \"latest\" tag" in deny with input as mock
}

test_digest_is_allowed if {
	mock := [
		instruction(0, "from", ["public.ecr.aws/docker/library/golang@sha256:0123456789abcdef"]),
		instruction(0, "user", ["nonroot"]),
	]

	count(deny) == 0 with input as mock
		with data.allowlist.dockerfile_base_image_repositories as allowed_repositories
}

test_stage_name_is_not_base_image if {
	mock := [
		instruction(0, "from", ["public.ecr.aws/docker/library/golang:1.23", "AS", "build"]),
		instruction(1, "from", ["build"]),
		instruction(1, "user", ["nonroot"]),
	]

	count(deny) == 0 with input as mock
		with data.allowlist.dockerfile_base_image_repositories as allowed_repositories
}

test_docker_hub_image_is_denied if {
	mock := [
		instruction(0, "from", ["golang:1.23"]),
		instruction(0, "user", ["nonroot"]),
	]

	"base image \"golang:1.23\" (repository \"docker.io/library/golang\") is not in the allowlist" in deny with input as mock
		with data.allowlist.dockerfile_base_image_repositories as allowed_repositories
}

test_missing_allowlist_denies_base_image if {
	"base image \"public.ecr.aws/docker/library/golang:1.23\" (repository \"public.ecr.aws/docker/library/golang\") is not in the allowlist" in deny with input as compliant
}

test_missing_user_is_denied if {
	mock := [instruction(0, "from", ["public.ecr.aws/docker/library/golang:1.23"])]

	"Dockerfile must set a non-root USER" in deny with input as mock
}

test_user_only_in_build_stage_is_denied if {
	mock := [
		instruction(0, "from", ["public.ecr.aws/docker/library/golang:1.23", "AS", "build"]),
		instruction(0, "user", ["nonroot"]),
		instruction(1, "from", ["gcr.io/distroless/static-debian12:nonroot"]),
		instruction(1, "entrypoint", ["/server"]),
	]

	"Dockerfile must set a non-root USER" in deny with input as mock
}

test_root_user_in_final_stage_is_denied if {
	mock := [
		instruction(0, "from", ["gcr.io/distroless/static-debian12:nonroot"]),
		instruction(0, "user", ["nonroot"]),
		instruction(0, "user", ["0:0"]),
	]

	"final stage must not run as root user \"0:0\"" in deny with input as mock
}

test_add_is_warned if {
	mock := [
		instruction(0, "from", ["gcr.io/distroless/static-debian12:nonroot"]),
		instruction(0, "add", ["server", "/server"]),
		instruction(0, "user", ["nonroot"]),
	]

	"use COPY instead of ADD: server /server" in warn with input as mock
}

test_non_dockerfile_input_is_ignored if {
	count(deny) == 0 with input as {"kind": "Deployment"}
	count(warn) == 0 with input as {"kind": "Deployment"}
}
