# networking module outputs
output "eks_nodes_sg_id" {
  value       = data.aws_security_group.eks_nodes.id
  description = "EKS node SG ID"
}
