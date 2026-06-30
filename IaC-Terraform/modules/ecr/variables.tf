

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar el repositorio ECR."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "repositories" {
  description = "Lista de repositorios ECR a crear."
  type        = list(string)
}