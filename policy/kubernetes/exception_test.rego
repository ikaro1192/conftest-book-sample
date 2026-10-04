package kubernetes

legacy := {
	"apiVersion": "apps/v1",
	"kind": "Deployment",
	"metadata": {"name": "legacy-report"},
	"spec": {"template": {"spec": compliant_pod_spec}},
}

legacy_exception := {
	"resource": "Deployment/legacy-report",
	"rules": ["read_only_root_filesystem"],
	"reason": "writes reports to /var/cache/report",
	"expires": "2100-12-31T23:59:59+09:00",
}

before_expiry := time.parse_rfc3339_ns("2100-12-01T00:00:00+09:00")

after_expiry := time.parse_rfc3339_ns("2101-01-01T00:00:00+09:00")

test_exception_is_applied if {
	exception == {["read_only_root_filesystem"]} with input as legacy
		with data.exceptions.kubernetes as [legacy_exception]
		with time.now_ns as before_expiry
}

test_expired_exception_is_ignored if {
	count(exception) == 0 with input as legacy
		with data.exceptions.kubernetes as [legacy_exception]
		with time.now_ns as after_expiry
}

test_exception_without_reason_is_ignored if {
	count(exception) == 0 with input as legacy
		with data.exceptions.kubernetes as [object.union(legacy_exception, {"reason": ""})]
		with time.now_ns as before_expiry
}

test_other_resource_is_not_excepted if {
	count(exception) == 0 with input as deployment(compliant_pod_spec)
		with data.exceptions.kubernetes as [legacy_exception]
		with time.now_ns as before_expiry
}

test_only_exceptable_rules_are_returned if {
	e := object.union(legacy_exception, {"rules": ["", "read_only_root_filesystem"]})

	exception == {["read_only_root_filesystem"]} with input as legacy
		with data.exceptions.kubernetes as [e]
		with time.now_ns as before_expiry
}

test_non_exceptable_rules_are_ignored if {
	e := object.union(legacy_exception, {"rules": [""]})

	count(exception) == 0 with input as legacy
		with data.exceptions.kubernetes as [e]
		with time.now_ns as before_expiry
}
