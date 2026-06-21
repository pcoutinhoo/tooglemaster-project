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
  description = <<-EOT
    ARN da LabRole do AWS Academy.

    *** ATENÇÃO: ISSO MUDA TODA VEZ QUE VC ABRE UMA NOVA SESSÃO DO ACADEMY ***
    O account ID é diferente a cada sessão. ANTES de rodar terraform apply, sempre rode:

      aws sts get-caller-identity
      aws iam get-role --role-name LabRole --query 'Role.Arn' --output text

    E atualize o valor no terraform.tfvars com o ARN retornado.
  EOT
}
