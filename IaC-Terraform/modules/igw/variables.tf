

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar el Internet Gateway."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se asociará el Internet Gateway."
  type        = string
}
