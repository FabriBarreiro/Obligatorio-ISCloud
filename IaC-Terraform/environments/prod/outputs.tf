

output "vpc_id" {
  description = "ID de la VPC principal creada."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Bloque CIDR asignado a la VPC principal."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas creadas."
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas creadas."
  value       = module.subnets.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway creado."
  value       = module.igw.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway creado."
  value       = module.natgw.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "IP pública asociada al NAT Gateway."
  value       = module.natgw.nat_gateway_public_ip
}

output "public_route_table_id" {
  description = "ID de la tabla de rutas pública."
  value       = module.route_tables.public_route_table_id
}

output "private_route_table_id" {
  description = "ID de la tabla de rutas privada."
  value       = module.route_tables.private_route_table_id
}

output "bastion_public_ip" {
  description = "IP pública del Bastion Host."
  value       = module.ec2.bastion_public_ip
}

output "bastion_public_dns" {
  description = "DNS público del Bastion Host."
  value       = module.ec2.bastion_public_dns
}

output "bastion_private_ip" {
  description = "IP privada del Bastion Host."
  value       = module.ec2.bastion_private_ip
}

output "ecr_repository_name" {
  description = "Nombre del repositorio ECR creado."
  value       = module.ecr.repository_names
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR creado."
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  description = "Nombre del cluster EKS creado."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint de la API del cluster EKS."
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  description = "Nombre del node group creado para los worker nodes."
  value       = module.eks.node_group_name
}

output "eks_cluster_addons" {
  description = "Add-ons administrados instalados en el cluster EKS."
  value       = module.eks.cluster_addons
}

output "redis_replication_group_id" {
  description = "ID del replication group Redis de ElastiCache."
  value       = module.elasticache.redis_replication_group_id
}

output "redis_primary_endpoint" {
  description = "Endpoint primario DNS del replication group Redis de ElastiCache."
  value       = module.elasticache.redis_primary_endpoint
}

output "redis_reader_endpoint" {
  description = "Endpoint de lectura DNS del replication group Redis de ElastiCache."
  value       = module.elasticache.redis_reader_endpoint
}

output "redis_port" {
  description = "Puerto TCP del replication group Redis de ElastiCache."
  value       = module.elasticache.redis_port
}

output "redis_connection_string" {
  description = "Cadena de conexion host:puerto hacia el endpoint primario de Redis."
  value       = module.elasticache.redis_connection_string
}

output "redis_subnet_group_name" {
  description = "Nombre del subnet group utilizado por ElastiCache Redis."
  value       = module.elasticache.redis_subnet_group_name
}

output "ssh_bastion_command" {
  description = "Comando base para conectarse por SSH al Bastion Host."
  value       = "ssh -i /ruta/a/vockey.pem ec2-user@${module.ec2.bastion_public_ip}"
}

