terraform {
  required_version = ">= 1.0"

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.27" }
  }
}

variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "namespace_name" { type = string }
variable "rds_secret_arn" { type = string }
variable "redis_secret_arn" { type = string }
variable "tags" { type = map(string) }

provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_caller_identity" "current" {}

# IAM Role (IRSA)
resource "aws_iam_role" "insighthub" {
  name = "insighthub-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace_name}:insighthub"
          "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "insighthub-role" })
}

# RDS connect policy
resource "aws_iam_role_policy" "rds" {
  name = "insighthub-${var.environment}-rds-policy"
  role = aws_iam_role.insighthub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = "arn:aws:rds:us-east-1:${data.aws_caller_identity.current.account_id}:db:insighthub-${var.environment}"
    }]
  })
}

# Secrets Manager access
resource "aws_iam_role_policy" "secrets" {
  name = "insighthub-${var.environment}-secrets-policy"
  role = aws_iam_role.insighthub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = [var.rds_secret_arn, var.redis_secret_arn]
    }]
  })
}

# CloudWatch Logs
resource "aws_iam_role_policy" "logs" {
  name = "insighthub-${var.environment}-logs-policy"
  role = aws_iam_role.insighthub.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/insighthub/${var.environment}:*"
    }]
  })
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# Namespace
resource "kubernetes_namespace" "insighthub" {
  metadata {
    name = var.namespace_name
    labels = {
      "app.kubernetes.io/name"       = "insighthub"
      "app.kubernetes.io/instance"   = var.environment
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ServiceAccount with IRSA
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

# Outputs
output "namespace_name" { value = kubernetes_namespace.insighthub.metadata[0].name }
output "service_account_name" { value = kubernetes_service_account.insighthub.metadata[0].name }
output "role_arn" { value = aws_iam_role.insighthub.arn }
