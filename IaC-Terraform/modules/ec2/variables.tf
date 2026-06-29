variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "instance_name" {
  description = "Nombre de la instancia"
  type        = string
}

variable "ami_id" {
  description = "AMI de la instancia"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet donde se desplegará la instancia"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Groups"
  type        = list(string)
}

variable "key_name" {
  description = "Nombre del Key Pair"
  type        = string
}

variable "associate_public_ip" {
  description = "Asignar IP pública"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Tamaño del disco raíz"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Tipo de volumen"
  type        = string
  default     = "gp3"
}

variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}