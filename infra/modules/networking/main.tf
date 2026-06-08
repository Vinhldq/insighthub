terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "cluster_name" { type = string }


provider "aws" {}

# Discover EKS node SG
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

# Output
output "eks_nodes_sg_id" {
  value = data.aws_security_group.eks_nodes.id
}
