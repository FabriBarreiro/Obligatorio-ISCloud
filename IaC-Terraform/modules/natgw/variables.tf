variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar el NAT Gateway."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "public_subnet_id" {
  description = "ID de la subnet pública donde se creará el NAT Gateway."
  type        = string
}
