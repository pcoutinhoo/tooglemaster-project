module "networking" {
  source       = "../modules/networking"
  project_name = var.project_name
  aws_region   = var.aws_region
}

module "eks" {
  source              = "../modules/eks"
  project_name        = var.project_name
  lab_role_arn        = var.lab_role_arn
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  eks_nodes_sg_id     = module.networking.eks_nodes_sg_id
}

module "database" {
  source             = "../modules/database"
  project_name       = var.project_name
  db_password        = var.db_password
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
  redis_sg_id        = module.networking.redis_sg_id
}

module "messaging" {
  source       = "../modules/messaging"
  project_name = var.project_name
}
