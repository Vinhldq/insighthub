terraform {
  required_version = ">= 1.0"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for security group egress rules"
}
variable "private_subnet_ids" { type = list(string) }
variable "enable_encryption" { type = bool }
variable "enable_multi_az" { type = bool }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "database_name" { type = string }
variable "master_username" { type = string }
variable "kms_key_arn" { type = string }
variable "eks_cluster_name" { type = string }
variable "tags" { type = map(string) }

locals {
  prefix = "insighthub-${var.environment}"
}

provider "aws" { region = var.aws_region }

# ========== Secrets Manager ==========
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "insighthub/${var.environment}/rds-credentials"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
  tags                    = merge(var.tags, { Name = "${local.prefix}-rds-creds" })
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id     = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({ username = var.master_username, password = random_password.rds_password.result })
}

# ========== Subnet Group ==========
resource "aws_db_subnet_group" "insighthub" {
  name       = "${local.prefix}-db"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${local.prefix}-db-subnet" })
}

# ========== Security Group ==========
resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds-sg"
  description = "PostgreSQL 5432 from EKS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${local.prefix}-rds-sg" })
}

data "aws_security_group" "eks_nodes" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [var.eks_cluster_name]
  }
  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["NodeSecurityGroup"]
  }
}

# ========== KMS Key ==========
resource "aws_kms_key" "rds" {
  description             = "KMS for InsightHub RDS"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.prefix}-kms-policy"
    Statement = [
      {
        Sid       = "EnableIAMPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowRDS"
        Effect    = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action = [
          "kms:Decrypt", "kms:DescribeKey", "kms:Encrypt",
          "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:CreateGrant"
        ]
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "rds.${var.aws_region}.amazonaws.com" } }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${local.prefix}-rds-key" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

data "aws_caller_identity" "current" {}

# ========== RDS Instance ==========
resource "aws_db_parameter_group" "insighthub" {
  family = "postgres16"
  name   = "${local.prefix}-pg-params"
  parameter {
    name  = "shared_preload_libraries"
    value = "pgvector"
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  parameter {
    name  = "log_duration"
    value = "1"
  }
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  tags = merge(var.tags, { Name = "${local.prefix}-pg-params" })
}

# IAM Role for RDS monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.prefix}-rds-monitoring" })
}

resource "aws_db_instance" "insighthub" {
  identifier        = "${local.prefix}-db"
  engine            = "postgres"
  engine_version    = "16.1"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = var.enable_encryption
  kms_key_id        = var.enable_encryption ? aws_kms_key.rds.arn : null

  db_name                = var.database_name
  username               = var.master_username
  password               = random_password.rds_password.result
  db_subnet_group_name   = aws_db_subnet_group.insighthub.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  parameter_group_name = aws_db_parameter_group.insighthub.name
  publicly_accessible  = false

  multi_az                   = var.enable_multi_az
  backup_retention_period    = 7
  backup_window              = "03:00-04:00"
  maintenance_window         = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true
  deletion_protection        = true

  skip_final_snapshot                 = var.environment == "dev"
  final_snapshot_identifier           = var.environment != "dev" ? "${local.prefix}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  copy_tags_to_snapshot               = true
  enable_cloudwatch_logs_exports      = ["postgresql"]
  iam_database_authentication_enabled = true

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = false
  performance_insights_kms_key_id = var.enable_encryption ? aws_kms_key.rds.arn : null

  tags       = merge(var.tags, { Name = "${local.prefix}-rds" })
  depends_on = [aws_secretsmanager_secret_version.rds_credentials]
}

# ========== CloudWatch Logs ==========
resource "aws_cloudwatch_log_group" "insighthub" {
  name              = "/aws/insighthub/${var.environment}"
  retention_in_days = 30
  kms_key_id        = var.enable_encryption ? aws_kms_key.rds.arn : null
  tags              = merge(var.tags, { Name = "${local.prefix}-logs" })
}

# ========== Outputs ==========
output "endpoint" { value = aws_db_instance.insighthub.endpoint }
output "address" { value = aws_db_instance.insighthub.address }
output "port" { value = aws_db_instance.insighthub.port }
output "db_name" { value = aws_db_instance.insighthub.db_name }
output "credentials_secret_arn" { value = aws_secretsmanager_secret.rds_credentials.arn }
output "security_group_id" { value = aws_security_group.rds.id }
output "kms_key_arn" { value = aws_kms_key.rds.arn }
output "log_group_name" { value = aws_cloudwatch_log_group.insighthub.name }
