

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

variable "num_cache_clusters" {
  description = "Cantidad de nodos del replication group Redis. Para alta disponibilidad se utilizan 2 nodos: un primario y una replica."
  type        = number
  default     = 2
}

variable "automatic_failover_enabled" {
  description = "Habilita failover automatico entre el nodo primario y la replica de Redis."
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Habilita despliegue Multi-AZ para mejorar la disponibilidad del servicio Redis."
  type        = bool
  default     = true
}

variable "snapshot_retention_limit" {
  description = "Cantidad de snapshots automáticos de Redis a conservar."
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "Ventana diaria UTC para la creación de snapshots automáticos de Redis."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Ventana semanal UTC de mantenimiento para ElastiCache Redis."
  type        = string
  default     = "sun:04:00-sun:05:00"
}