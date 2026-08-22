output "sqs_url" {
  value       = aws_sqs_queue.events.url
  description = "URL da fila SQS"
}

output "sqs_arn" {
  value       = aws_sqs_queue.events.arn
  description = "ARN da fila SQS"
}

output "dynamodb_table" {
  value       = aws_dynamodb_table.analytics.name
  description = "Nome da tabela DynamoDB"
}

output "ecr_urls" {
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
  description = "URLs dos repositórios ECR"
}
