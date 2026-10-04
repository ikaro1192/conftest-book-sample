package terraform

is_terraform_plan if {
	is_array(input.resource_changes)
}

planned_resources contains rc if {
	is_terraform_plan
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.change.actions != ["delete"]
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_eks_cluster"
	not public_endpoint_disabled(rc.change.after)
	msg := sprintf("EKS cluster %q must set endpoint_public_access to false", [rc.address])
}

public_endpoint_disabled(after) if {
	some vpc_config in after.vpc_config
	vpc_config.endpoint_public_access == false
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_eks_cluster"
	not secrets_encrypted(rc.change.after)
	msg := sprintf("EKS cluster %q must enable secrets encryption", [rc.address])
}

secrets_encrypted(after) if {
	some config in after.encryption_config
	"secrets" in config.resources
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_eks_node_group"
	some instance_type in rc.change.after.instance_types
	not allowed_instance_type(instance_type)
	msg := sprintf("EKS node group %q uses disallowed instance type %q", [rc.address, instance_type])
}

allowed_instance_type(instance_type) if {
	instance_type in data.allowlist.eks_node_instance_types
}

iam_policy_types := {"aws_iam_policy", "aws_iam_role_policy"}

deny contains msg if {
	some rc in planned_resources
	rc.type in iam_policy_types
	some statement in policy_statements(rc.change.after.policy)
	statement.Effect == "Allow"
	"*" in as_array(statement.Action)
	msg := sprintf("IAM policy %q must not allow all actions", [rc.address])
}

warn contains msg if {
	some rc in planned_resources
	rc.type in iam_policy_types
	rc.change.after_unknown.policy == true
	msg := sprintf("IAM policy %q is unknown until apply and was not checked", [rc.address])
}

policy_statements(policy) := as_array(json.unmarshal(policy).Statement)

as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)
