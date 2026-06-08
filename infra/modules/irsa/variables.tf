# irsa module variables
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "namespace_name" { type = string }
variable "rds_secret_arn" { type = string }
variable "redis_secret_arn" { type = string }
variable "tags" { type = map(string) }
