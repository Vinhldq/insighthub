terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.27" }
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
variable "node_type" { type = string }
variable "num_cache_nodes" { type = number }
variable "kms_key_arn" { type = string }
variable "eks_nodes_sg_id" { type = string }
variable "tags" { type = map(string) }

locals {
  prefix = "insighthub-${var.environment}"
}

provider "aws" { region = var.aws_region }

# Subnet Group
resource "aws_elasticache_subnet_group" "insighthub" {
  name       = "${local.prefix}-redis"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${local.prefix}-redis-subnet" })
}

# Security Group
resource "aws_security_group" "redis" {
  name        = "${local.prefix}-redis-sg"
  description = "Redis 6379 from EKS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_nodes_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${local.prefix}-redis-sg" })
}

# Parameter Group
resource "aws_elasticache_parameter_group" "insighthub" {
  name   = "${local.prefix}-redis-params"
  family = "redis7"
  tags   = merge(var.tags, { Name = "${local.prefix}-redis-params" })
}

# Auth token
resource "random_password" "redis_password" {
  length  = 32
  special = true
}

# Secrets Manager
resource "aws_secretsmanager_secret" "redis_connection" {
  name                    = "insighthub/${var.environment}/redis-connection"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
  tags                    = merge(var.tags, { Name = "${local.prefix}-redis-creds" })
}

# Redis Cluster
resource "aws_elasticache_cluster" "insighthub" {
  cluster_id           = "${local.prefix}-redis"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.insighthub.name
  engine_version       = "7.0"
  port                 = 6379

  az_mode                    = var.enable_multi_az ? "cross-az" : "single-az"
  subnet_group_name          = aws_elasticache_subnet_group.insighthub.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = var.enable_multi_az

  at_rest_encryption_enabled = var.enable_encryption
  transit_encryption_enabled = var.enable_encryption
  auth_token_enabled         = var.enable_encryption
  auth_token                 = var.enable_encryption ? random_password.redis_password.result : null

  snapshot_retention_limit = 5
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  tags = merge(var.tags, { Name = "${local.prefix}-redis" })
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id = aws_secretsmanager_secret.redis_connection.id
  secret_string = jsonencode({
    auth_token = random_password.redis_password.result
    endpoint   = aws_elasticache_cluster.insighthub.cache_nodes[0].address
    port       = 6379
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "insighthub" {
  name              = "/aws/insighthub/${var.environment}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${local.prefix}-logs" })
}

# Outputs
output "endpoint" { value = aws_elasticache_cluster.insighthub.cache_nodes[0].address }
output "port" { value = aws_elasticache_cluster.insighthub.port }
output "connection_secret_arn" { value = aws_secretsmanager_secret.redis_connection.arn }
output "security_group_id" { value = aws_security_group.redis.id }
