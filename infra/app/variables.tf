variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "togglemaster"
}

variable "db_password" {
  description = "Senha dos bancos PostgreSQL"
  type        = string
  sensitive   = true
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy"
  type        = string
}