output "endpoint" { value = aws_db_instance.insighthub.endpoint }
output "address" { value = aws_db_instance.insighthub.address }
output "port" { value = aws_db_instance.insighthub.port }
output "db_name" { value = aws_db_instance.insighthub.db_name }
output "credentials_secret_arn" { value = aws_secretsmanager_secret.rds_credentials.arn }
output "security_group_id" { value = aws_security_group.rds.id }
output "kms_key_arn" { value = aws_kms_key.rds.arn }
output "log_group_name" { value = aws_cloudwatch_log_group.insighthub.name }
