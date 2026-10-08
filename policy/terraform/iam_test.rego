package terraform

github_provider_arn := "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"

role(assume_role_policy) := {
	"address": "aws_iam_role.example",
	"mode": "managed",
	"type": "aws_iam_role",
	"change": {"actions": ["create"], "after": {"assume_role_policy": json.marshal(assume_role_policy)}, "after_unknown": {}},
}

github_trust(condition) := {"Statement": [{
	"Effect": "Allow",
	"Action": "sts:AssumeRoleWithWebIdentity",
	"Principal": {"Federated": github_provider_arn},
	"Condition": condition,
}]}

test_github_trust_with_sub_is_allowed if {
	condition := {"StringEquals": {
		"token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
		"token.actions.githubusercontent.com:sub": "repo:example/repo:pull_request",
	}}

	count(deny) == 0 with input as plan(role(github_trust(condition)))
}

test_github_trust_without_sub_is_denied if {
	condition := {"StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"}}

	"IAM role \"aws_iam_role.example\" must restrict the sub claim of GitHub OIDC tokens with StringEquals" in deny with input as plan(role(github_trust(condition)))
}

test_github_trust_with_string_like_sub_is_denied if {
	condition := {"StringLike": {"token.actions.githubusercontent.com:sub": "repo:example/*"}}

	"IAM role \"aws_iam_role.example\" must restrict the sub claim of GitHub OIDC tokens with StringEquals" in deny with input as plan(role(github_trust(condition)))
}

test_service_trust_is_allowed if {
	trust := {"Statement": [{
		"Effect": "Allow",
		"Action": "sts:AssumeRole",
		"Principal": {"Service": "eks.amazonaws.com"},
	}]}

	count(deny) == 0 with input as plan(role(trust))
}

attachment(policy_arn) := {
	"address": "aws_iam_role_policy_attachment.example",
	"mode": "managed",
	"type": "aws_iam_role_policy_attachment",
	"change": {"actions": ["create"], "after": {"role": "example", "policy_arn": policy_arn}, "after_unknown": {}},
}

test_administrator_access_is_denied if {
	"IAM role policy attachment \"aws_iam_role_policy_attachment.example\" must not attach AdministratorAccess" in deny with input as plan(attachment("arn:aws:iam::aws:policy/AdministratorAccess"))
}

test_read_only_access_is_allowed if {
	count(deny) == 0 with input as plan(attachment("arn:aws:iam::aws:policy/ReadOnlyAccess"))
}

test_unknown_assume_role_policy_is_warned if {
	rc := {
		"address": "aws_iam_role.example",
		"mode": "managed",
		"type": "aws_iam_role",
		"change": {"actions": ["create"], "after": {}, "after_unknown": {"assume_role_policy": true}},
	}

	"IAM role \"aws_iam_role.example\" has an assume role policy unknown until apply and was not checked" in warn with input as plan(rc)
}
