

output "repository_name" {
  description = "Nombre del repositorio ECR creado."
  value       = aws_ecr_repository.app_repository.name
}

output "repository_url" {
  description = "URL del repositorio ECR creado."
  value       = aws_ecr_repository.app_repository.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR creado."
  value       = aws_ecr_repository.app_repository.arn
}
