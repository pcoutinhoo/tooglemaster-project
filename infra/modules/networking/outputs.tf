output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID da VPC criada"
}

output "private_subnet_ids" {
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  description = "IDs das subnets privadas"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  description = "IDs das subnets públicas"
}

output "eks_nodes_sg_id" {
  value       = aws_security_group.eks_nodes.id
  description = "Security Group dos nodes EKS"
}

output "rds_sg_id" {
  value       = aws_security_group.rds.id
  description = "Security Group do RDS"
}

output "redis_sg_id" {
  value       = aws_security_group.redis.id
  description = "Security Group do Redis"
}