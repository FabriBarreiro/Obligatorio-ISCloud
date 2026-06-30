

output "repository_names" {
  description = "Nombres de los repositorios creados"

  value = {
    for name, repo in aws_ecr_repository.repositories :
    name => repo.name
  }
}

output "repository_urls" {
  description = "URLs de los repositorios creados"

  value = {
    for name, repo in aws_ecr_repository.repositories :
    name => repo.repository_url
  }
}

output "repository_arns" {
  description = "ARNs de los repositorios creados"

  value = {
    for name, repo in aws_ecr_repository.repositories :
    name => repo.arn
  }
}
