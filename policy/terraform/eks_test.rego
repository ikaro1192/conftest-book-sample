package terraform

plan(resource_change) := {"resource_changes": [resource_change]}

cluster(actions, after) := {
	"address": "aws_eks_cluster.main",
	"mode": "managed",
	"type": "aws_eks_cluster",
	"change": {"actions": actions, "after": after, "after_unknown": {}},
}

node_group(instance_types) := {
	"address": "aws_eks_node_group.default",
	"mode": "managed",
	"type": "aws_eks_node_group",
	"change": {"actions": ["create"], "after": {"instance_types": instance_types}, "after_unknown": {}},
}

role_policy(after, after_unknown) := {
	"address": "aws_iam_role_policy.example",
	"mode": "managed",
	"type": "aws_iam_role_policy",
	"change": {"actions": ["create"], "after": after, "after_unknown": after_unknown},
}

allowed_instance_types := ["t3.medium", "t3.large"]

test_compliant_cluster_is_allowed if {
	after := {
		"vpc_config": [{"endpoint_public_access": false}],
		"encryption_config": [{"resources": ["secrets"]}],
	}

	count(deny) == 0 with input as plan(cluster(["create"], after))
}

test_public_endpoint_is_denied if {
	after := {
		"vpc_config": [{"endpoint_public_access": true}],
		"encryption_config": [{"resources": ["secrets"]}],
	}

	"EKS cluster \"aws_eks_cluster.main\" must set endpoint_public_access to false" in deny with input as plan(cluster(["create"], after))
}

test_unknown_public_endpoint_is_denied if {
	after := {
		"vpc_config": [{}],
		"encryption_config": [{"resources": ["secrets"]}],
	}

	"EKS cluster \"aws_eks_cluster.main\" must set endpoint_public_access to false" in deny with input as plan(cluster(["create"], after))
}

test_missing_encryption_config_is_denied if {
	after := {
		"vpc_config": [{"endpoint_public_access": false}],
		"encryption_config": [],
	}

	"EKS cluster \"aws_eks_cluster.main\" must enable secrets encryption" in deny with input as plan(cluster(["create"], after))
}

test_deleted_cluster_is_ignored if {
	count(deny) == 0 with input as plan(cluster(["delete"], null))
}

test_allowed_instance_type_is_allowed if {
	count(deny) == 0 with input as plan(node_group(["t3.medium"]))
		with data.allowlist.eks_node_instance_types as allowed_instance_types
}

test_disallowed_instance_type_is_denied if {
	"EKS node group \"aws_eks_node_group.default\" uses disallowed instance type \"m5.xlarge\"" in deny with input as plan(node_group(["m5.xlarge"]))
		with data.allowlist.eks_node_instance_types as allowed_instance_types
}

test_missing_allowlist_denies_instance_type if {
	"EKS node group \"aws_eks_node_group.default\" uses disallowed instance type \"t3.medium\"" in deny with input as plan(node_group(["t3.medium"]))
}

test_wildcard_action_is_denied if {
	policy := json.marshal({"Statement": [{"Effect": "Allow", "Action": "*", "Resource": "*"}]})

	"IAM policy \"aws_iam_role_policy.example\" must not allow all actions" in deny with input as plan(role_policy({"policy": policy}, {}))
}

test_wildcard_action_in_array_is_denied if {
	policy := json.marshal({"Statement": {"Effect": "Allow", "Action": ["s3:GetObject", "*"], "Resource": "*"}})

	"IAM policy \"aws_iam_role_policy.example\" must not allow all actions" in deny with input as plan(role_policy({"policy": policy}, {}))
}

test_specific_action_is_allowed if {
	policy := json.marshal({"Statement": [{"Effect": "Allow", "Action": "eks:DescribeCluster", "Resource": "*"}]})

	count(deny) == 0 with input as plan(role_policy({"policy": policy}, {}))
}

test_unknown_policy_is_warned if {
	"IAM policy \"aws_iam_role_policy.example\" is unknown until apply and was not checked" in warn with input as plan(role_policy({}, {"policy": true}))
}

test_non_plan_input_is_ignored if {
	count(deny) == 0 with input as [{"Cmd": "from", "Value": ["golang:1.23"]}]
}
