variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace_name" {
  description = "Kubernetes namespace for InsightHub"
  type        = string
  default     = "insighthub"
}

variable "vpc_id" {
  description = "VPC ID for RDS and ElastiCache"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS and ElastiCache"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "At least one private subnet is required."
  }
}

variable "rds_instance_class" {
  description = "RDS instance class (cost-optimized for lab)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.rds_allocated_storage >= 20
    error_message = "RDS storage must be at least 20 GB."
  }
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = "insighthub"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]*$", var.rds_database_name))
    error_message = "Database name must start with letter, contain only alphanumerics."
  }
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
  default     = "insighthub"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type (cost-optimized for lab)"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
  validation {
    condition     = var.redis_num_cache_nodes >= 1 && var.redis_num_cache_nodes <= 6
    error_message = "Cache nodes must be between 1 and 6."
  }
}

variable "enable_encryption" {
  description = "Enable encryption at rest and in transit"
  type        = bool
  default     = true
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ for HA (false for lab cost optimization)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
