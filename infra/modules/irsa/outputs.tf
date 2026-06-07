# irsa module outputs
output "namespace_name" {
  value       = kubernetes_namespace.insighthub.metadata[0].name
  description = "K8s namespace"
}
output "service_account_name" {
  value       = kubernetes_service_account.insighthub.metadata[0].name
  description = "Service account"
}
output "role_arn" {
  value       = aws_iam_role.insighthub.arn
  description = "IAM role ARN"
}
