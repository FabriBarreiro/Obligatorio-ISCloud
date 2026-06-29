output "bastion_instance_id" {
  description = "ID de la instancia EC2 utilizada como Bastion Host."
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "IP pública del Bastion Host."
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "DNS público del Bastion Host."
  value       = aws_instance.bastion.public_dns
}

output "bastion_private_ip" {
  description = "IP privada del Bastion Host."
  value       = aws_instance.bastion.private_ip
}

output "bastion_private_dns" {
  description = "DNS privado del Bastion Host."
  value       = aws_instance.bastion.private_dns
}
