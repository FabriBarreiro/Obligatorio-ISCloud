variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar los Security Groups."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crearán los Security Groups del bastion, cluster EKS y worker nodes."
  type        = string
}
