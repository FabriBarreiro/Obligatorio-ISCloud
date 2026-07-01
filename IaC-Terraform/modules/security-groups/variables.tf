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

variable "cluster_name" {
  description = "Nombre del cluster EKS utilizado para tags de Kubernetes."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR principal de la VPC utilizado para permitir trafico interno necesario entre ALB, nodos EKS y pods."
  type        = string
}
