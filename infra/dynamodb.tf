resource "aws_dynamodb_table" "analytics" {
  name         = "ToggleMasterAnalytics"  # nome exato que o código espera
  billing_mode = "PAY_PER_REQUEST"        # paga só pelo que usa — ótimo para Academy

  # Chave primária que o analytics-service usa (definida no README do repo)
  hash_key = "event_id"

  attribute {
    name = "event_id"
    type = "S"   # S = String
  }

  tags = { Name = "ToggleMasterAnalytics" }
}