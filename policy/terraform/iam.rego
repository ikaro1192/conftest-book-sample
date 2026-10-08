package terraform

github_oidc_host := "token.actions.githubusercontent.com"

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_iam_role"
	some statement in policy_statements(rc.change.after.assume_role_policy)
	trusts_github_oidc(statement)
	not sub_restricted(statement)
	msg := sprintf("IAM role %q must restrict the sub claim of GitHub OIDC tokens with StringEquals", [rc.address])
}

trusts_github_oidc(statement) if {
	statement.Effect == "Allow"
	some principal in as_array(statement.Principal.Federated)
	endswith(principal, concat("/", ["oidc-provider", github_oidc_host]))
}

sub_restricted(statement) if {
	statement.Condition.StringEquals[concat(":", [github_oidc_host, "sub"])]
}

deny contains msg if {
	some rc in planned_resources
	rc.type == "aws_iam_role_policy_attachment"
	rc.change.after.policy_arn == "arn:aws:iam::aws:policy/AdministratorAccess"
	msg := sprintf("IAM role policy attachment %q must not attach AdministratorAccess", [rc.address])
}

warn contains msg if {
	some rc in planned_resources
	rc.type == "aws_iam_role"
	rc.change.after_unknown.assume_role_policy == true
	msg := sprintf("IAM role %q has an assume role policy unknown until apply and was not checked", [rc.address])
}
