package terraform

test_public_endpoint_is_denied if {
	mock := {"resource_changes": [{
		"address": "aws_eks_cluster.main",
		"type": "aws_eks_cluster",
		"change": {"after": {
			"vpc_config": [{"endpoint_public_access": true}],
			"encryption_config": [{"resources": ["secrets"]}],
		}},
	}]}

	count(deny) > 0 with input as mock
}

test_private_endpoint_is_allowed if {
	mock := {"resource_changes": [{
		"address": "aws_eks_cluster.main",
		"type": "aws_eks_cluster",
		"change": {"after": {
			"vpc_config": [{"endpoint_public_access": false}],
			"encryption_config": [{"resources": ["secrets"]}],
		}},
	}]}

	count(deny) == 0 with input as mock
}

test_missing_encryption_config_is_denied if {
	mock := {"resource_changes": [{
		"address": "aws_eks_cluster.main",
		"type": "aws_eks_cluster",
		"change": {"after": {
			"vpc_config": [{"endpoint_public_access": false}],
			"encryption_config": [],
		}},
	}]}

	count(deny) > 0 with input as mock
}

test_disallowed_instance_type_is_denied if {
	mock := {"resource_changes": [{
		"address": "aws_eks_node_group.default",
		"type": "aws_eks_node_group",
		"change": {"after": {"instance_types": ["m7g.xlarge"]}},
	}]}

	count(deny) > 0 with input as mock
}

test_allowed_instance_type_is_allowed if {
	mock := {"resource_changes": [{
		"address": "aws_eks_node_group.default",
		"type": "aws_eks_node_group",
		"change": {"after": {"instance_types": ["t4g.medium"]}},
	}]}

	count(deny) == 0 with input as mock
}
