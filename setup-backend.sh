#!/bin/bash
# setup-backend.sh
# Roda o bootstrap (cria bucket S3) e gera backend.tf, providers.tf e

set -e

echo ">>> Aplicando bootstrap (cria bucket S3)..."
cd infra/bootstrap
terraform init -input=false
terraform apply -auto-approve
BUCKET=$(terraform output -raw state_bucket_name)
cd ../..

echo ">>> Bucket: $BUCKET"

cat > infra/app/backend.tf << EOF
terraform {
  backend "s3" {
    bucket       = "${BUCKET}"
    key          = "togglemaster/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
EOF

cat > infra/app/versions.tf << EOF
terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF

cat > infra/app/providers.tf << EOF
provider "aws" {
  region = var.aws_region
}
EOF

echo ">>> infra/app/backend.tf, versions.tf e providers.tf gerados."
echo ">>> Próximo passo: cd infra/app && terraform init"
