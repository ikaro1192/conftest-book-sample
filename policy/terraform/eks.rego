package main

deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_eks_cluster"
	resource.change.after.vpc_config[_].endpoint_public_access == true
	msg := sprintf("EKS cluster %q must not expose a public API endpoint", [resource.address])
}

deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_eks_cluster"
	count(resource.change.after.encryption_config) == 0
	msg := sprintf("EKS cluster %q must enable secrets encryption", [resource.address])
}

allowed_instance_types := {"t3.medium", "t3.large"}

deny[msg] {
	resource := input.resource_changes[_]
	resource.type == "aws_eks_node_group"
	instance_type := resource.change.after.instance_types[_]
	not allowed_instance_types[instance_type]
	msg := sprintf("EKS node group %q uses disallowed instance type %q", [resource.address, instance_type])
}
