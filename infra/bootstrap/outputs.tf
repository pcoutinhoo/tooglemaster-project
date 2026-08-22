output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Nome do bucket S3"
}

output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "Account ID atual"
}
