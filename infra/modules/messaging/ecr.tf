locals {
  services = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true  # escaneia vulnerabilidades automaticamente
  }

  tags = { Name = each.key }
}