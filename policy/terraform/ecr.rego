package terraform

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_ecr_repository"
	not rc.change.after.image_tag_mutability == "IMMUTABLE"
	msg := sprintf("ECR repository %q must set image_tag_mutability to IMMUTABLE", [rc.address])
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_ecr_repository"
	not scan_on_push_enabled(rc.change.after)
	msg := sprintf("ECR repository %q must enable scan_on_push", [rc.address])
}

scan_on_push_enabled(after) if {
	some config in after.image_scanning_configuration
	config.scan_on_push == true
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_ecr_repository"
	not kms_encrypted(rc.change.after)
	msg := sprintf("ECR repository %q must use KMS encryption", [rc.address])
}

kms_encrypted(after) if {
	some config in after.encryption_configuration
	config.encryption_type == "KMS"
}
