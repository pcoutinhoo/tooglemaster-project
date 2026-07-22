resource "aws_dynamodb_table" "analytics" {
  name         = "analytics-events"  # deve corresponder à variável AWS_DYNAMODB_TABLE no ConfigMap e docker-compose
  billing_mode = "PAY_PER_REQUEST"   # paga só pelo que usa — ótimo para Academy

  # Chave primária que o analytics-service usa
  hash_key = "event_id"

  attribute {
    name = "event_id"
    type = "S"   # S = String
  }

  tags = { Name = "analytics-events" }
}