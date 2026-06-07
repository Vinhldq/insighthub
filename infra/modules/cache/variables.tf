# cache module variables
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "enable_encryption" { type = bool }
variable "enable_multi_az" { type = bool }
variable "node_type" { type = string }
variable "num_cache_nodes" { type = number }
variable "kms_key_arn" { type = string }
variable "eks_nodes_sg_id" { type = string }
variable "tags" { type = map(string) }
