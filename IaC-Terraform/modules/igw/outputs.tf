

output "internet_gateway_id" {
  description = "ID del Internet Gateway creado."
  value       = aws_internet_gateway.internet_gateway.id
}
