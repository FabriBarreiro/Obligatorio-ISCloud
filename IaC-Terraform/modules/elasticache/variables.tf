

variable "project_name" {
  description = "Nombre del proyecto utilizado para nombrar los recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente donde se despliegan los recursos."
  type        = string
}

variable "subnet_ids" {
  description = "IDs de las subnets privadas de datos donde se desplegara ElastiCache."
  type        = list(string)
}

variable "security_group_id" {
  description = "ID del Security Group asociado al cluster de ElastiCache Redis."
  type        = string
}

variable "engine_version" {
  description = "Version del motor Redis utilizada por ElastiCache."
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Tipo de nodo utilizado por ElastiCache Redis."
  type        = string
  default     = "cache.t3.micro"
}

variable "port" {
  description = "Puerto TCP utilizado por Redis."
  type        = number
  default     = 6379
}

variable "num_cache_nodes" {
  description = "Cantidad de nodos del cluster Redis."
  type        = number
  default     = 1
}
