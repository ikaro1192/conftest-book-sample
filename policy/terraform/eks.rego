# METADATA
# title: Terraformのplan結果の規約
# description: terraform show -json で出力したplan結果を検査する。
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

# METADATA
# scope: rule
# title: EKSクラスタのAPIエンドポイントを公開しない
# description: aws_eks_cluster の vpc_config.endpoint_public_access を false にする。
# related_resources:
#   - ref: https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html
# custom:
#   remediation: vpc_config に endpoint_public_access = false を書く。
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

# METADATA
# scope: rule
# title: EKSクラスタのSecretを暗号化する
# description: aws_eks_cluster の encryption_config の resources に secrets を含める。
# related_resources:
#   - ref: https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html
# custom:
#   remediation: encryption_config ブロックを書き、resources に secrets、provider に KMS キーを指定する。
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

# METADATA
# scope: rule
# title: ノードグループのインスタンスタイプを許可リストに限る
# description: aws_eks_node_group の instance_types は、data.allowlist.eks_node_instance_types のいずれかとする。
# custom:
#   remediation: 許可リストにあるインスタンスタイプを使う。別のタイプが必要な場合は、利用側の許可リストに加える。
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

# METADATA
# scope: rule
# title: IAMポリシーで全アクションを許可しない
# description: aws_iam_policy と aws_iam_role_policy の Effect が Allow の文で、Action に "*" を書かない。
# related_resources:
#   - ref: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
# custom:
#   remediation: 必要なアクションを列挙する。
deny contains msg if {
	some rc in planned_resources
	rc.type in iam_policy_types
	some statement in policy_statements(rc.change.after.policy)
	statement.Effect == "Allow"
	"*" in as_array(statement.Action)
	msg := sprintf("IAM policy %q must not allow all actions", [rc.address])
}

# METADATA
# scope: rule
# title: applyまで内容が決まらないIAMポリシーを警告する
# description: policy の値が after_unknown のIAMポリシーは、plan結果では検査できない。
# custom:
#   remediation: planの時点で値が決まる入力だけでポリシーの文書を組み立てる。
warn contains msg if {
	some rc in planned_resources
	rc.type in iam_policy_types
	rc.change.after_unknown.policy == true
	msg := sprintf("IAM policy %q is unknown until apply and was not checked", [rc.address])
}

policy_statements(policy) := as_array(json.unmarshal(policy).Statement)

as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)
