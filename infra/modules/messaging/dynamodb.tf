resource "aws_dynamodb_table" "analytics" {
  name         = "ToggleMasterAnalytics" # nome exato esperado pelo analytics-service
  billing_mode = "PAY_PER_REQUEST"       # paga só pelo que usa — ótimo para Academy

  hash_key = "event_id"

  attribute {
    name = "event_id"
    type = "S" # S = String
  }

  tags = { Name = "ToggleMasterAnalytics" }
}