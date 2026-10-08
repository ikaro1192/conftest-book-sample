output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "ecr_push_role_arn" {
  value = aws_iam_role.ecr_push.arn
}

output "argocd_server_url" {
  value = aws_eks_capability.argocd.configuration[0].argo_cd[0].server_url
}
