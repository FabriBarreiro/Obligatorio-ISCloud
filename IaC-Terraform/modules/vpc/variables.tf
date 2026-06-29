

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar los recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR principal de la VPC."
  type        = string
}

variable "enable_dns_support" {
  description = "Habilita soporte DNS dentro de la VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Habilita nombres DNS para recursos dentro de la VPC."
  type        = bool
  default     = true
}
