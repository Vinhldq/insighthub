output "namespace_name" {
  description = "Kubernetes namespace for InsightHub"
  value       = module.irsa.namespace_name
}

output "service_account_name" {
  description = "Kubernetes service account with IRSA"
  value       = module.irsa.service_account_name
}

output "iam_role_arn" {
  description = "IAM role ARN for IRSA"
  value       = module.irsa.role_arn
}

# Database outputs
output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = module.database.endpoint
  sensitive   = false
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.database.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.database.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.database.db_name
}

output "rds_credentials_secret_arn" {
  description = "AWS Secrets Manager ARN for RDS credentials"
  value       = module.database.credentials_secret_arn
  sensitive   = true
}

# Cache outputs
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.cache.endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.cache.port
}

output "redis_connection_secret_arn" {
  description = "AWS Secrets Manager ARN for Redis connection"
  value       = module.cache.connection_secret_arn
  sensitive   = true
}

# KMS
output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.database.kms_key_arn
}

# Monitoring
output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.database.log_group_name
}
