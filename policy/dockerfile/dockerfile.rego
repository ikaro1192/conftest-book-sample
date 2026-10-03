package dockerfile

deny contains msg if {
	cmd := input[_]
	lower(cmd.Cmd) == "from"
	image := cmd.Value[0]
	endswith(image, ":latest")
	msg := sprintf("base image %q must not use the \"latest\" tag", [image])
}

deny contains msg if {
	not user_set
	msg := "Dockerfile must set a non-root USER"
}

user_set if {
	cmd := input[_]
	lower(cmd.Cmd) == "user"
}
