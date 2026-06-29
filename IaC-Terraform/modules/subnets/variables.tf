

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar los recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster EKS utilizado para etiquetar las subnets."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crearán las subnets."
  type        = string
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad donde se distribuirán las subnets."
  type        = list(string)
}

variable "public_subnet_cidr_blocks" {
  description = "Lista de bloques CIDR para las subnets públicas."
  type        = list(string)
}

variable "private_subnet_cidr_blocks" {
  description = "Lista de bloques CIDR para las subnets privadas."
  type        = list(string)
}
