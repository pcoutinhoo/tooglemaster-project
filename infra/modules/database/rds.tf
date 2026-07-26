resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "auth" {
  identifier        = "${var.project_name}-auth-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "auth_db"
  username          = "postgres"
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "${var.project_name}-auth-db" }
}

resource "aws_db_instance" "flag" {
  identifier        = "${var.project_name}-flag-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "flag_db"
  username          = "postgres"
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "${var.project_name}-flag-db" }
}

resource "aws_db_instance" "targeting" {
  identifier        = "${var.project_name}-targeting-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "targeting_db"
  username          = "postgres"
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "${var.project_name}-targeting-db" }
}
