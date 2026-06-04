resource "aws_sqs_queue" "events" {
  name                       = "${var.project_name}-events"
  message_retention_seconds  = 86400   # mensagens ficam 1 dia se não consumidas
  visibility_timeout_seconds = 30      # tempo que o consumer tem para processar

  tags = { Name = "${var.project_name}-events" }
}