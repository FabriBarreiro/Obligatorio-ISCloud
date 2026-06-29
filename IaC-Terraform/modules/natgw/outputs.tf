

output "nat_gateway_id" {
  description = "ID del NAT Gateway creado."
  value       = aws_nat_gateway.nat_gateway.id
}

output "nat_gateway_public_ip" {
  description = "IP pública asociada al NAT Gateway."
  value       = aws_eip.nat_gateway_eip.public_ip
}
