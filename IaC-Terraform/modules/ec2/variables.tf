variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar el Bastion Host."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliega la infraestructura."
  type        = string
}

variable "public_subnet_id" {
  description = "ID de la subnet pública donde se desplegará el Bastion Host."
  type        = string
}

variable "bastion_security_group_id" {
  description = "ID del Security Group asociado al Bastion Host."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2 utilizado para el Bastion Host."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre del Key Pair utilizado para acceso SSH al Bastion Host."
  type        = string
  default     = "vockey"
}

variable "root_volume_size" {
  description = "Tamaño en GB del disco raíz del Bastion Host."
  type        = number
  default     = 20
}

variable "iam_instance_profile" {

  description = "Nombre del IAM Instance Profile asociado a la instancia bastion."

  type = string

  default = "LabInstanceProfile"

}
