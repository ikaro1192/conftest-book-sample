package kubernetes

image := "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/conftest-book-dev-app:v0.1.0"

compliant_container := {
	"name": "app",
	"image": image,
	"securityContext": {"readOnlyRootFilesystem": true},
	"resources": {
		"requests": {"cpu": "100m", "memory": "64Mi"},
		"limits": {"cpu": "250m", "memory": "128Mi"},
	},
}

compliant_pod_spec := {
	"serviceAccountName": "conftest-book-app",
	"securityContext": {"runAsNonRoot": true},
	"containers": [compliant_container],
}

deployment(pod_spec) := {
	"apiVersion": "apps/v1",
	"kind": "Deployment",
	"metadata": {"name": "app"},
	"spec": {"template": {"spec": pod_spec}},
}

with_container(container) := object.union(compliant_pod_spec, {"containers": [container]})

test_compliant_deployment_is_allowed if {
	count(deny) == 0 with input as deployment(compliant_pod_spec)
	count(deny_read_only_root_filesystem) == 0 with input as deployment(compliant_pod_spec)
}

test_privileged_container_is_denied if {
	spec := with_container(object.union(compliant_container, {"securityContext": {"privileged": true}}))

	"Deployment/app: container \"app\" must not run in privileged mode" in deny with input as deployment(spec)
}

test_host_pid_is_denied if {
	spec := object.union(compliant_pod_spec, {"hostPID": true})

	"Deployment/app: pod must not set hostPID to true" in deny with input as deployment(spec)
}

test_missing_memory_limit_is_denied if {
	container := object.union(object.remove(compliant_container, ["resources"]), {"resources": {
		"requests": {"cpu": "100m", "memory": "64Mi"},
		"limits": {"cpu": "250m"},
	}})
	spec := with_container(container)

	deny == {"Deployment/app: container \"app\" must set resources.limits.memory"} with input as deployment(spec)
}

test_latest_tag_is_denied if {
	spec := with_container(object.union(compliant_container, {"image": "public.ecr.aws/nginx/nginx"}))

	"Deployment/app: container \"app\" image \"public.ecr.aws/nginx/nginx\" must not use the \"latest\" tag" in deny with input as deployment(spec)
}

test_container_overrides_run_as_non_root if {
	spec := with_container(object.union(compliant_container, {"securityContext": {"runAsNonRoot": false}}))

	"Deployment/app: container \"app\" must set runAsNonRoot to true" in deny with input as deployment(spec)
}

test_container_level_run_as_non_root_is_allowed if {
	container := object.union(compliant_container, {"securityContext": {"runAsNonRoot": true}})
	spec := object.remove(with_container(container), ["securityContext"])

	count(deny) == 0 with input as deployment(spec)
}

test_init_container_is_checked if {
	init := object.union(object.remove(compliant_container, ["securityContext"]), {"name": "init"})
	spec := object.union(compliant_pod_spec, {"initContainers": [init]})

	"Deployment/app: container \"init\" must set readOnlyRootFilesystem to true" in deny_read_only_root_filesystem with input as deployment(spec)
}

test_default_service_account_is_denied if {
	spec := object.remove(compliant_pod_spec, ["serviceAccountName"])

	"Deployment/app: pod must not use the default ServiceAccount" in deny with input as deployment(spec)
}

test_cronjob_pod_spec_is_checked if {
	mock := {
		"apiVersion": "batch/v1",
		"kind": "CronJob",
		"metadata": {"name": "batch"},
		"spec": {"jobTemplate": {"spec": {"template": {"spec": object.union(compliant_pod_spec, {"hostNetwork": true})}}}},
	}

	deny == {"CronJob/batch: pod must not set hostNetwork to true"} with input as mock
}

service_account(role_arn) := {
	"apiVersion": "v1",
	"kind": "ServiceAccount",
	"metadata": {
		"name": "app",
		"annotations": {"eks.amazonaws.com/role-arn": role_arn},
	},
}

allowed_role_prefixes := ["arn:aws:iam::123456789012:role/conftest-book-dev-"]

test_allowed_irsa_role_is_allowed if {
	count(deny) == 0 with input as service_account("arn:aws:iam::123456789012:role/conftest-book-dev-app")
		with data.allowlist.kubernetes_irsa_role_arn_prefixes as allowed_role_prefixes
}

test_other_account_irsa_role_is_denied if {
	"ServiceAccount/app: IAM role \"arn:aws:iam::999999999999:role/conftest-book-dev-app\" is not allowed for IRSA" in deny with input as service_account("arn:aws:iam::999999999999:role/conftest-book-dev-app")
		with data.allowlist.kubernetes_irsa_role_arn_prefixes as allowed_role_prefixes
}

test_missing_allowlist_denies_irsa_role if {
	"ServiceAccount/app: IAM role \"arn:aws:iam::123456789012:role/conftest-book-dev-app\" is not allowed for IRSA" in deny with input as service_account("arn:aws:iam::123456789012:role/conftest-book-dev-app")
}

test_load_balancer_service_is_denied if {
	mock := {
		"apiVersion": "v1",
		"kind": "Service",
		"metadata": {"name": "app"},
		"spec": {"type": "LoadBalancer"},
	}

	"Service/app: Service type LoadBalancer is not allowed" in deny with input as mock
}

test_non_kubernetes_input_is_ignored if {
	count(deny) == 0 with input as [{"Cmd": "from", "Stage": 0, "Value": ["golang:1.27"]}]
	count(deny) == 0 with input as {"resource_changes": []}
}

test_single_replica_is_warned if {
	d := object.union(deployment(compliant_pod_spec), {"spec": {"replicas": 1}})
	warn == {"Deployment/app: replicas must be at least 2"} with input as d
}

test_two_replicas_are_not_warned if {
	d := object.union(deployment(compliant_pod_spec), {"spec": {"replicas": 2}})
	count(warn) == 0 with input as d
}
