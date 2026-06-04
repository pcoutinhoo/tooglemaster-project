# Após o terraform apply, esses valores aparecem no terminal
# São as "strings de conexão" que você vai usar nos Secrets do Kubernetes

output "auth_db_endpoint" {
  value       = aws_db_instance.auth.endpoint
  description = "Endpoint do banco do auth-service"
}

output "flag_db_endpoint" {
  value       = aws_db_instance.flag.endpoint
  description = "Endpoint do banco do flag-service"
}

output "targeting_db_endpoint" {
  value       = aws_db_instance.targeting.endpoint
  description = "Endpoint do banco do targeting-service"
}

output "redis_endpoint" {
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
  description = "Endpoint do Redis (ElastiCache)"
}

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