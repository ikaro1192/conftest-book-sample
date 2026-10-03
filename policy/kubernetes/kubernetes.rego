package kubernetes

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.resources.limits
	msg := sprintf("container %q must set resource limits", [container.name])
}

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("container %q must not use the \"latest\" image tag", [container.name])
}

deny contains msg if {
	input.kind == "Deployment"
	input.spec.template.spec.hostNetwork == true
	msg := "pod must not use hostNetwork"
}

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	container.securityContext.privileged == true
	msg := sprintf("container %q must not run in privileged mode", [container.name])
}
