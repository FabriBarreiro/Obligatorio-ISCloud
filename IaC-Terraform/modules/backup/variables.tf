variable "project_name" {
  type        = string
  description = "Nombre del proyecto."
}

variable "environment" {
  type        = string
  description = "Ambiente."
}

variable "backup_schedule" {
  type        = string
  description = "Expresión cron para ejecutar backups."
  default     = "cron(0 3 * * ? *)"
}

variable "backup_retention_days" {
  type        = number
  description = "Cantidad de días de retención de backups."
  default     = 7
}

variable "resource_tag_key" {
  type        = string
  description = "Tag usado para seleccionar recursos a respaldar."
  default     = "Backup"
}

variable "resource_tag_value" {
  type        = string
  description = "Valor del tag usado para seleccionar recursos."
  default     = "true"
}