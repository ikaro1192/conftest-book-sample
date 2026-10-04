package lib.image

test_parse_splits_tag_and_digest if {
	parse("gcr.io/distroless/static-debian12:nonroot@sha256:abc") == {
		"name": "gcr.io/distroless/static-debian12",
		"tag": "nonroot",
		"digest": "sha256:abc",
	}
}

test_parse_keeps_registry_port if {
	parse("localhost:5000/app:1.0").name == "localhost:5000/app"
}

test_pinned if {
	pinned("golang:1.27")
	pinned("golang@sha256:abc")
	not pinned("golang")
	not pinned("golang:latest")
}

test_repository if {
	repository("golang:1.27") == "docker.io/library/golang"
	repository("bitnami/redis:7") == "docker.io/bitnami/redis"
	repository("gcr.io/distroless/static-debian12:nonroot") == "gcr.io/distroless/static-debian12"
	repository("localhost:5000/app:1.0") == "localhost:5000/app"
}
