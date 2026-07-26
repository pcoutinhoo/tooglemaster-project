resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-node" }
  }
}

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.lab_role_arn
  version  = "1.31"

  vpc_config {
    subnet_ids = concat(
      var.public_subnet_ids,
      var.private_subnet_ids
    )
    endpoint_public_access  = true
    endpoint_private_access = true
    security_group_ids      = [var.eks_nodes_sg_id]
  }

  tags = { Name = "${var.project_name}-cluster" }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = var.private_subnet_ids

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
  depends_on    = [aws_eks_cluster.main]

  tags = { Name = "${var.project_name}-nodes" }
}
