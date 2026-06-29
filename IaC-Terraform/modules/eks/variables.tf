

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar recursos asociados al cluster EKS."
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster EKS."
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes utilizada por el cluster EKS."
  type        = string
  default     = "1.29"
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas donde se desplegarán el cluster EKS y los worker nodes."
  type        = list(string)
}


variable "eks_cluster_security_group_id" {
  description = "ID del Security Group adicional asociado al control plane del cluster EKS."
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "CIDRs permitidos para acceder al endpoint público del cluster EKS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_nodes_security_group_id" {
  description = "ID del Security Group asociado a los worker nodes de EKS."
  type        = string
}

variable "key_name" {
  description = "Nombre del Key Pair utilizado para acceso SSH a las instancias EC2 de los worker nodes."
  type        = string
  default     = "vockey"
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 utilizados por los worker nodes de EKS."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Cantidad deseada de worker nodes en el node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Cantidad mínima de worker nodes en el node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Cantidad máxima de worker nodes en el node group."
  type        = number
  default     = 4
}

variable "cluster_addons" {
  description = "Lista de add-ons administrados de EKS que se instalarán en el cluster."
  type        = list(string)
  default = [
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "aws-ebs-csi-driver"
  ]
}
