package kubernetes

test_compliant_deployment_is_allowed if {
	mock := {
		"kind": "Deployment",
		"spec": {"template": {"spec": {"containers": [{
			"name": "app",
			"image": "ghcr.io/example/conftest-book-app:v0.1.0",
			"resources": {"limits": {"cpu": "250m", "memory": "128Mi"}},
		}]}}},
	}

	count(deny) == 0 with input as mock
}

test_missing_resource_limits_is_denied if {
	mock := {
		"kind": "Deployment",
		"spec": {"template": {"spec": {"containers": [{
			"name": "app",
			"image": "ghcr.io/example/conftest-book-app:v0.1.0",
		}]}}},
	}

	count(deny) > 0 with input as mock
}

test_latest_tag_is_denied if {
	mock := {
		"kind": "Deployment",
		"spec": {"template": {"spec": {"containers": [{
			"name": "app",
			"image": "ghcr.io/example/conftest-book-app:latest",
			"resources": {"limits": {"cpu": "250m"}},
		}]}}},
	}

	count(deny) > 0 with input as mock
}

test_host_network_is_denied if {
	mock := {
		"kind": "Deployment",
		"spec": {"template": {"spec": {
			"hostNetwork": true,
			"containers": [{
				"name": "app",
				"image": "ghcr.io/example/conftest-book-app:v0.1.0",
				"resources": {"limits": {"cpu": "250m"}},
			}],
		}}},
	}

	count(deny) > 0 with input as mock
}

test_privileged_container_is_denied if {
	mock := {
		"kind": "Deployment",
		"spec": {"template": {"spec": {"containers": [{
			"name": "app",
			"image": "ghcr.io/example/conftest-book-app:v0.1.0",
			"resources": {"limits": {"cpu": "250m"}},
			"securityContext": {"privileged": true},
		}]}}},
	}

	count(deny) > 0 with input as mock
}
