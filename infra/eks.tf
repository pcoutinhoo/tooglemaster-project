# ─── LAUNCH TEMPLATE (corrige o bug do IMDS hop limit permanentemente) ──────
# Sem isso, os pods não conseguem acessar a LabRole via metadata da instância
# e qualquer chamada AWS SDK (SQS, DynamoDB) dentro de um pod falha com
# "NoCredentialProviders: no valid providers in chain"
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # <-- O FIX. Padrão é 1, que bloqueia pods.
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-node"
    }
  }
}

# ─── EKS CLUSTER ───────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.lab_role_arn
  version  = "1.31" # 1.29 está deprecada, não usar

  vpc_config {
    subnet_ids = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    endpoint_public_access  = true
    endpoint_private_access = true
    security_group_ids      = [aws_security_group.eks_nodes.id]
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ─── EKS NODE GROUP ────────────────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  scaling_config {
    min_size     = 1
    desired_size = 2
    max_size     = 4
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  depends_on = [aws_eks_cluster.main]

  tags = { Name = "${var.project_name}-nodes" }
}