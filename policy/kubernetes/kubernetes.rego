package kubernetes

import data.lib.image

is_kubernetes if {
	is_string(input.apiVersion)
	is_string(input.kind)
}

resource_id := sprintf("%s/%s", [input.kind, object.get(input, ["metadata", "name"], "")]) if is_kubernetes

pod_template_kinds := {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job"}

pod_spec := input.spec.template.spec if {
	is_kubernetes
	input.kind in pod_template_kinds
}

pod_spec := input.spec.jobTemplate.spec.template.spec if {
	is_kubernetes
	input.kind == "CronJob"
}

pod_spec := input.spec if {
	is_kubernetes
	input.kind == "Pod"
}

containers contains container if {
	some container in pod_spec.containers
}

containers contains container if {
	some container in pod_spec.initContainers
}

deny contains msg if {
	some container in containers
	container.securityContext.privileged == true
	msg := sprintf("%s: container %q must not run in privileged mode", [resource_id, container.name])
}

deny contains msg if {
	some field in ["hostNetwork", "hostPID", "hostIPC"]
	pod_spec[field] == true
	msg := sprintf("%s: pod must not set %s to true", [resource_id, field])
}

deny contains msg if {
	some container in containers
	some kind in ["requests", "limits"]
	some name in ["cpu", "memory"]
	not container.resources[kind][name]
	msg := sprintf("%s: container %q must set resources.%s.%s", [resource_id, container.name, kind, name])
}

deny contains msg if {
	some container in containers
	not image.pinned(container.image)
	msg := sprintf("%s: container %q image %q must not use the \"latest\" tag", [resource_id, container.name, container.image])
}

deny contains msg if {
	some container in containers
	not run_as_non_root(container)
	msg := sprintf("%s: container %q must set runAsNonRoot to true", [resource_id, container.name])
}

run_as_non_root(container) if {
	pod_default := object.get(pod_spec, ["securityContext", "runAsNonRoot"], false)
	object.get(container, ["securityContext", "runAsNonRoot"], pod_default) == true
}

deny_read_only_root_filesystem contains msg if {
	some container in containers
	not container.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("%s: container %q must set readOnlyRootFilesystem to true", [resource_id, container.name])
}

deny contains msg if {
	spec := pod_spec
	not dedicated_service_account(spec)
	msg := sprintf("%s: pod must not use the default ServiceAccount", [resource_id])
}

dedicated_service_account(spec) if {
	spec.serviceAccountName != "default"
}

deny contains msg if {
	is_kubernetes
	input.kind == "ServiceAccount"
	role_arn := input.metadata.annotations["eks.amazonaws.com/role-arn"]
	not allowed_irsa_role(role_arn)
	msg := sprintf("%s: IAM role %q is not allowed for IRSA", [resource_id, role_arn])
}

allowed_irsa_role(role_arn) if {
	some prefix in data.allowlist.kubernetes_irsa_role_arn_prefixes
	startswith(role_arn, prefix)
}

deny contains msg if {
	is_kubernetes
	input.kind == "Service"
	input.spec.type == "LoadBalancer"
	msg := sprintf("%s: Service type LoadBalancer is not allowed", [resource_id])
}
