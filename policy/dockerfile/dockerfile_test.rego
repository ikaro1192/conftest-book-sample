package dockerfile

test_compliant_dockerfile_is_allowed if {
	mock := [
		{"Cmd": "from", "Value": ["golang:1.23"]},
		{"Cmd": "workdir", "Value": ["/src"]},
		{"Cmd": "from", "Value": ["gcr.io/distroless/static-debian12:nonroot"]},
		{"Cmd": "user", "Value": ["nonroot:nonroot"]},
		{"Cmd": "entrypoint", "Value": ["/server"]},
	]

	count(deny) == 0 with input as mock
}

test_latest_tag_is_denied if {
	mock := [
		{"Cmd": "from", "Value": ["golang:latest"]},
		{"Cmd": "user", "Value": ["nonroot"]},
	]

	count(deny) > 0 with input as mock
}

test_missing_user_is_denied if {
	mock := [{"Cmd": "from", "Value": ["golang:1.23"]}]

	count(deny) > 0 with input as mock
}
