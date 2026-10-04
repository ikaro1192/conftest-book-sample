package terraform

# METADATA
# scope: rule
# title: ECRリポジトリのタグを変更不可にする
# description: aws_ecr_repository の image_tag_mutability を IMMUTABLE にする。
# related_resources:
#   - ref: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html
# custom:
#   remediation: image_tag_mutability = "IMMUTABLE" を書く。
deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_ecr_repository"
	not rc.change.after.image_tag_mutability == "IMMUTABLE"
	msg := sprintf("ECR repository %q must set image_tag_mutability to IMMUTABLE", [rc.address])
}

# METADATA
# scope: rule
# title: ECRリポジトリのプッシュ時スキャンを有効にする
# description: aws_ecr_repository の image_scanning_configuration.scan_on_push を true にする。
# custom:
#   remediation: image_scanning_configuration ブロックに scan_on_push = true を書く。
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

# METADATA
# scope: rule
# title: ECRリポジトリをKMSで暗号化する
# description: aws_ecr_repository の encryption_configuration.encryption_type を KMS にする。
# custom:
#   remediation: encryption_configuration ブロックに encryption_type = "KMS" を書く。
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
