package main

deny[msg] {
	cmd := input[_]
	lower(cmd.Cmd) == "from"
	image := cmd.Value[0]
	endswith(image, ":latest")
	msg := sprintf("base image %q must not use the \"latest\" tag", [image])
}

deny[msg] {
	not user_set
	msg := "Dockerfile must set a non-root USER"
}

user_set {
	cmd := input[_]
	lower(cmd.Cmd) == "user"
}
