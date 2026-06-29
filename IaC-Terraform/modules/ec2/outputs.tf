output "instance_id" {
  value = aws_instance.bastion.id
}

output "public_ip" {
  value = aws_instance.bastion.public_ip
}

output "public_dns" {
  value = aws_instance.bastion.public_dns
}

output "private_ip" {
  value = aws_instance.bastion.private_ip
}

output "private_dns" {
  value = aws_instance.bastion.private_dns
}