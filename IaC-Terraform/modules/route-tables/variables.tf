variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar las tablas de rutas."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crearán las tablas de rutas."
  type        = string
}

variable "internet_gateway_id" {
  description = "ID del Internet Gateway utilizado por la tabla de rutas pública."
  type        = string
}

variable "nat_gateway_id" {
  description = "ID del NAT Gateway utilizado por la tabla de rutas privada."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subnets públicas que se asociarán a la tabla de rutas pública."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas que se asociarán a la tabla de rutas privada."
  type        = list(string)
}
