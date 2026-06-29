output "vpc_id" {
  description = "ID de la VPC principal creada."
  value       = aws_vpc.main_vpc.id
}

output "vpc_arn" {
  description = "ARN de la VPC principal creada."
  value       = aws_vpc.main_vpc.arn
}

output "vpc_cidr_block" {
  description = "Bloque CIDR asignado a la VPC principal."
  value       = aws_vpc.main_vpc.cidr_block
}
