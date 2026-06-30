variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar los recursos."
  type        = string
  default     = "obligatorio-iscloud"
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Nombre del cluster EKS."
  type        = string
  default     = "obligatorio-iscloud-prod-eks"
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR principal de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad utilizadas por las subnets públicas y privadas."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subnets públicas."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subnets privadas."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "data_subnet_cidr_blocks" {
  description = "Bloques CIDR de las subnets privadas de datos."
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "key_name" {
  description = "Nombre del Key Pair utilizado para acceso SSH a las instancias EC2."
  type        = string
  default     = "vockey"
}

variable "bastion_instance_type" {
  description = "Tipo de instancia EC2 utilizado para el Bastion Host."
  type        = string
  default     = "t3.micro"
}

variable "bastion_root_volume_size" {
  description = "Tamaño en GB del disco raíz del Bastion Host."
  type        = number
  default     = 20
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes utilizada por el cluster EKS."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 utilizados por los worker nodes de EKS."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Cantidad deseada de worker nodes en el node group de EKS."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Cantidad mínima de worker nodes en el node group de EKS."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Cantidad máxima de worker nodes en el node group de EKS."
  type        = number
  default     = 4
}

variable "cluster_addons" {
  description = "Lista de add-ons administrados que se instalarán en el cluster EKS."
  type        = list(string)
  default = [
    "vpc-cni",
    "coredns",
    "kube-proxy",
  ]
}

variable "eks_public_access_cidrs" {
  description = "CIDRs permitidos para acceder al endpoint público del cluster EKS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
