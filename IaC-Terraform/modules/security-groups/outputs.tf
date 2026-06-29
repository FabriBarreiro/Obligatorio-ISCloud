output "bastion_security_group_id" {
  description = "ID del Security Group del Bastion Host."
  value       = aws_security_group.bastion_sg.id
}

output "eks_cluster_security_group_id" {
  description = "ID del Security Group adicional del cluster EKS."
  value       = aws_security_group.eks_cluster_sg.id
}

output "eks_nodes_security_group_id" {
  description = "ID del Security Group de los worker nodes de EKS."
  value       = aws_security_group.eks_nodes_sg.id
}
