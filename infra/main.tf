# ============================================================
# Kubernetes Namespace for InsightHub
# ============================================================
resource "kubernetes_namespace" "insighthub" {
  metadata {
    name = "${var.namespace_name}-${var.environment}"

    labels = {
      "app.kubernetes.io/name"       = "insighthub"
      "app.kubernetes.io/instance"   = var.environment
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================
# IAM Role for InsightHub Service Account (IRSA)
# ============================================================
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "insighthub" {
  name = "insighthub-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${kubernetes_namespace.insighthub.metadata[0].name}:insighthub"
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "insighthub-role"
  })
}

# RDS access policy
resource "aws_iam_role_policy" "insighthub_rds" {
  name = "insighthub-${var.environment}-rds-policy"
  role = aws_iam_role.insighthub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db/${aws_db_instance.insighthub.identifier}"
        ]
      }
    ]
  })
}

# Secrets Manager access policy
resource "aws_iam_role_policy" "insighthub_secrets" {
  name = "insighthub-${var.environment}-secrets-policy"
  role = aws_iam_role.insighthub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_credentials.arn,
          aws_secretsmanager_secret.redis_connection.arn
        ]
      }
    ]
  })
}

# ServiceAccount with IRSA annotation
resource "kubernetes_service_account" "insighthub" {
  metadata {
    name      = "insighthub"
    namespace = kubernetes_namespace.insighthub.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.insighthub.arn
    }

    labels = {
      "app.kubernetes.io/name"       = "insighthub"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================
# Security Group for RDS (private, no public access)
# ============================================================
resource "aws_security_group" "rds" {
  name        = "insighthub-${var.environment}-rds-sg"
  description = "Security group for InsightHub RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "insighthub-rds-sg"
  })
}

# Security group for EKS nodes (to allow RDS egress)
data "aws_security_group" "eks_nodes" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["NodeSecurityGroup"]
  }
}

# ============================================================
# RDS PostgreSQL 16 with pgvector
# (Encrypted, private, no public access)
# ============================================================
resource "random_password" "rds_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "insighthub/${var.environment}/rds-credentials"
  description             = "RDS master credentials for InsightHub"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "insighthub-rds-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.rds_master_username
    password = random_password.rds_password.result
  })
}

resource "aws_db_subnet_group" "insighthub" {
  name       = "insighthub-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "insighthub-db-subnet-group"
  })
}

resource "aws_db_instance" "insighthub" {
  identifier     = "insighthub-${var.environment}"
  engine         = "postgres"
  engine_version = "16.1"
  instance_class = var.rds_instance_class

  allocated_storage            = var.rds_allocated_storage
  storage_type                 = "gp3"
  storage_encrypted            = var.enable_encryption
  kms_key_id                   = var.enable_encryption ? aws_kms_key.rds.arn : null
  iops                         = 3000
  performance_insights_enabled = false

  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = random_password.rds_password.result

  db_subnet_group_name   = aws_db_subnet_group.insighthub.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az = var.enable_multi_az

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment != "dev" ? "insighthub-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  copy_tags_to_snapshot = true
  deletion_protection   = var.environment == "prod" ? true : false

  enable_cloudwatch_logs_exports = ["postgresql"]

  parameter_group_name = aws_db_parameter_group.insighthub.name

  tags = merge(var.tags, {
    Name = "insighthub-rds"
  })

  depends_on = [aws_secretsmanager_secret_version.rds_credentials]
}

resource "aws_db_parameter_group" "insighthub" {
  family = "postgres16"
  name   = "insighthub-${var.environment}"

  parameter {
    name  = "shared_preload_libraries"
    value = "pgvector"
  }

  tags = merge(var.tags, {
    Name = "insighthub-pg-params"
  })
}

# ============================================================
# KMS Key for RDS Encryption
# ============================================================
resource "aws_kms_key" "rds" {
  description             = "KMS key for InsightHub RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "insighthub-rds-key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/insighthub-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ============================================================
# ElastiCache Redis (Private, no public access)
# ============================================================
resource "aws_security_group" "redis" {
  name        = "insighthub-${var.environment}-redis-sg"
  description = "Security group for InsightHub ElastiCache"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [data.aws_security_group.eks_nodes.id]
    description     = "Redis from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "insighthub-redis-sg"
  })
}

resource "aws_elasticache_subnet_group" "insighthub" {
  name       = "insighthub-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "insighthub-redis-subnet-group"
  })
}

resource "random_password" "redis_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "redis_connection" {
  name                    = "insighthub/${var.environment}/redis-connection"
  description             = "Redis connection string for InsightHub"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "insighthub-redis-connection"
  })
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id = aws_secretsmanager_secret.redis_connection.id
  secret_string = jsonencode({
    auth_token = random_password.redis_password.result
    endpoint   = aws_elasticache_cluster.insighthub.cache_nodes[0].address
    port       = 6379
  })
}

resource "aws_elasticache_parameter_group" "insighthub" {
  name   = "insighthub-${var.environment}-params"
  family = "redis7"

  tags = merge(var.tags, {
    Name = "insighthub-redis-params"
  })
}

resource "aws_elasticache_cluster" "insighthub" {
  cluster_id           = "insighthub-${var.environment}"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.insighthub.name
  engine_version       = "7.0"
  port                 = 6379

  az_mode = var.enable_multi_az ? "cross-az" : "single-az"

  subnet_group_name          = aws_elasticache_subnet_group.insighthub.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = var.enable_multi_az

  at_rest_encryption_enabled = var.enable_encryption
  transit_encryption_enabled = var.enable_encryption
  auth_token_enabled         = var.enable_encryption
  auth_token                 = var.enable_encryption ? random_password.redis_password.result : null

  snapshot_retention_limit = 5
  snapshot_window          = "03:00-05:00"

  maintenance_window = "sun:04:00-sun:05:00"

  tags = merge(var.tags, {
    Name = "insighthub-redis"
  })

  depends_on = [aws_secretsmanager_secret_version.redis_connection]
}

# ============================================================
# CloudWatch Log Group for monitoring
# ============================================================
resource "aws_cloudwatch_log_group" "insighthub" {
  name              = "/aws/insighthub/${var.environment}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "insighthub-logs"
  })
}
