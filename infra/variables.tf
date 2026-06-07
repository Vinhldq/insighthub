variable "environment" {
  type        = string
  description = "Environment name (dev/staging/prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for RDS and Redis"
}

variable "enable_encryption" {
  type        = bool
  description = "Enable encryption at rest and in transit"
  default     = true
}

variable "enable_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for RDS and Redis"
  default     = false
}

variable "rds_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type        = number
  description = "RDS allocated storage in GB"
  default     = 20
}

variable "rds_database_name" {
  type        = string
  description = "RDS database name"
  default     = "insighthub"
}

variable "rds_master_username" {
  type        = string
  description = "RDS master username"
  default     = "insighthub"
  sensitive   = true
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type"
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  type        = number
  description = "Number of Redis cache nodes"
  default     = 1
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for encryption (optional)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources"
  default = {
    Project    = "insighthub"
    ManagedBy  = "terraform"
    CostCenter = "engineering"
  }
}
