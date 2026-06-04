variable "aws_region" {
  description = "Região AWS"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado como prefixo em todos os recursos)"
  default     = "togglemaster"
}

variable "db_password" {
  description = "Senha dos bancos PostgreSQL (use uma senha forte)"
  sensitive   = true 
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy"
}