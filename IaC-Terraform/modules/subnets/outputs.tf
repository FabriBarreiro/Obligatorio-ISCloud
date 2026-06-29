

output "public_subnet_ids" {
  description = "IDs de las subnets públicas creadas."
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas creadas."
  value       = aws_subnet.private_subnets[*].id
}

output "public_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subnets públicas creadas."
  value       = aws_subnet.public_subnets[*].cidr_block
}

output "private_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subnets privadas creadas."
  value       = aws_subnet.private_subnets[*].cidr_block
}
