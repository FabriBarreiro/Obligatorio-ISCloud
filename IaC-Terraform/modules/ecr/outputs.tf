

output "repository_names" {
  description = "Repositorios creados"

  value = {
    for repo in aws_ecr_repository.repositories :
    repo.name => repo.repository_url
  }
}

output "repository_url" {
  description = "URL del repositorio ECR creado."
  value       = aws_ecr_repository.app_repository.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR creado."
  value       = aws_ecr_repository.app_repository.arn
}
