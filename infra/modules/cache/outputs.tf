# cache module outputs
output "endpoint" {
  value       = aws_elasticache_cluster.insighthub.cache_nodes[0].address
  description = "Redis endpoint"
}
output "port" {
  value       = aws_elasticache_cluster.insighthub.port
  description = "Redis port"
}
output "connection_secret_arn" {
  value       = aws_secretsmanager_secret.redis_connection.arn
  description = "Redis secret ARN"
}
output "security_group_id" {
  value       = aws_security_group.redis.id
  description = "Redis SG ID"
}
