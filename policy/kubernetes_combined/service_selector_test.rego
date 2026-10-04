package kubernetes_combined

doc(path, contents) := {"path": path, "contents": contents}

deployment(name, labels) := {
	"apiVersion": "apps/v1",
	"kind": "Deployment",
	"metadata": {"name": name},
	"spec": {"template": {"metadata": {"labels": labels}}},
}

service(name, selector) := {
	"apiVersion": "v1",
	"kind": "Service",
	"metadata": {"name": name},
	"spec": {"selector": selector},
}

test_matching_selector_is_allowed if {
	count(deny) == 0 with input as [
		doc("deployment.yaml", deployment("app", {"app": "web", "tier": "frontend"})),
		doc("service.yaml", service("app", {"app": "web"})),
	]
}

test_unmatched_selector_is_denied if {
	mock := [
		doc("deployment.yaml", deployment("app", {"app": "web"})),
		doc("service.yaml", service("app", {"app": "api"})),
	]

	deny == {"Service/app: selector {\"app\": \"api\"} does not match any pod template labels"} with input as mock
}

test_partially_matched_selector_is_denied if {
	mock := [
		doc("deployment.yaml", deployment("app", {"app": "web"})),
		doc("service.yaml", service("app", {"app": "web", "tier": "frontend"})),
	]

	count(deny) == 1 with input as mock
}

test_service_without_selector_is_ignored if {
	mock := [doc("service.yaml", {
		"apiVersion": "v1",
		"kind": "Service",
		"metadata": {"name": "external"},
		"spec": {"type": "ExternalName", "externalName": "example.com"},
	})]

	count(deny) == 0 with input as mock
}

test_single_file_input_is_ignored if {
	count(deny) == 0 with input as service("app", {"app": "api"})
}
