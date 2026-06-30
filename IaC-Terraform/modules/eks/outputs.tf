

output "cluster_name" {
  description = "Nombre del cluster EKS creado."
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_arn" {
  description = "ARN del cluster EKS creado."
  value       = aws_eks_cluster.eks_cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint de la API del cluster EKS."
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA del cluster EKS codificado en base64."
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "node_group_name" {
  description = "Nombre del node group creado para los worker nodes."
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

output "node_group_arn" {
  description = "ARN del node group creado para los worker nodes."
  value       = aws_eks_node_group.eks_node_group.arn
}

output "cluster_addons" {
  description = "Add-ons administrados instalados en el cluster EKS."
  value       = keys(aws_eks_addon.eks_addons)
}

output "oidc_provider_arn" {
  description = "ARN del IAM OIDC Provider asociado al cluster EKS."
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  description = "URL del IAM OIDC Provider asociado al cluster EKS."
  value       = aws_iam_openid_connect_provider.eks_oidc.url
}
