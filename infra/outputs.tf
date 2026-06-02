output "namespace_name" {
  description = "Kubernetes namespace for InsightHub"
  value       = kubernetes_namespace.insighthub.metadata[0].name
}

output "service_account_name" {
  description = "Service account name with IRSA"
  value       = kubernetes_service_account.insighthub.metadata[0].name
}

output "iam_role_arn" {
  description = "IAM role ARN for IRSA"
  value       = aws_iam_role.insighthub.arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.insighthub.endpoint
  sensitive   = false
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.insighthub.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.insighthub.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.insighthub.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.insighthub.username
  sensitive   = true
}

output "rds_credentials_secret_arn" {
  description = "AWS Secrets Manager secret ARN for RDS credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_cluster.insighthub.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.insighthub.port
}

output "redis_connection_secret_arn" {
  description = "AWS Secrets Manager secret ARN for Redis connection"
  value       = aws_secretsmanager_secret.redis_connection.arn
}

# CloudWatch
output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.insighthub.name
}
