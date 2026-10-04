package terraform

ecr_repository(after) := {
	"address": "aws_ecr_repository.app",
	"mode": "managed",
	"type": "aws_ecr_repository",
	"change": {"actions": ["create"], "after": after, "after_unknown": {}},
}

compliant_ecr_after := {
	"image_tag_mutability": "IMMUTABLE",
	"image_scanning_configuration": [{"scan_on_push": true}],
	"encryption_configuration": [{"encryption_type": "KMS"}],
}

test_compliant_ecr_repository_is_allowed if {
	count(deny) == 0 with input as plan(ecr_repository(compliant_ecr_after))
}

test_mutable_tags_are_denied if {
	after := object.union(compliant_ecr_after, {"image_tag_mutability": "MUTABLE"})

	"ECR repository \"aws_ecr_repository.app\" must set image_tag_mutability to IMMUTABLE" in deny with input as plan(ecr_repository(after))
}

test_scan_on_push_disabled_is_denied if {
	after := object.union(compliant_ecr_after, {"image_scanning_configuration": [{"scan_on_push": false}]})

	"ECR repository \"aws_ecr_repository.app\" must enable scan_on_push" in deny with input as plan(ecr_repository(after))
}

test_aes256_encryption_is_denied if {
	after := object.union(compliant_ecr_after, {"encryption_configuration": [{"encryption_type": "AES256"}]})

	"ECR repository \"aws_ecr_repository.app\" must use KMS encryption" in deny with input as plan(ecr_repository(after))
}

test_omitted_ecr_blocks_are_denied if {
	after := {
		"image_tag_mutability": "IMMUTABLE",
		"image_scanning_configuration": [],
		"encryption_configuration": [],
	}

	deny == {
		"ECR repository \"aws_ecr_repository.app\" must enable scan_on_push",
		"ECR repository \"aws_ecr_repository.app\" must use KMS encryption",
	} with input as plan(ecr_repository(after))
}
