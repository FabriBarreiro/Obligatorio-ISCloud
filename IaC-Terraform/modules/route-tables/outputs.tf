output "public_route_table_id" {
  description = "ID de la tabla de rutas pública."
  value       = aws_route_table.public_route_table.id
}

output "private_route_table_id" {
  description = "ID de la tabla de rutas privada."
  value       = aws_route_table.private_route_table.id
}

output "data_subnet_route_table_association_ids" {
  description = "IDs de las asociaciones entre las subnets privadas de datos y la tabla de rutas privada."
  value       = aws_route_table_association.data_subnet_associations[*].id
}
