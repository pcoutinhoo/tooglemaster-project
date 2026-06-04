# Subnet group — diz em quais subnets o RDS pode ser criado
# Precisa de pelo menos 2 zonas de disponibilidade
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

# Banco do auth-service
resource "aws_db_instance" "auth" {
  identifier        = "${var.project_name}-auth-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"   # menor instância — barata
  allocated_storage = 20              # 20GB de armazenamento

  db_name  = "auth_db"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true   # IMPORTANTE: permite destruir sem criar snapshot
  publicly_accessible = false  # não expõe na internet

  tags = { Name = "${var.project_name}-auth-db" }
}

# Banco do flag-service
resource "aws_db_instance" "flag" {
  identifier        = "${var.project_name}-flag-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "flag_db"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = { Name = "${var.project_name}-flag-db" }
}

# Banco do targeting-service
resource "aws_db_instance" "targeting" {
  identifier        = "${var.project_name}-targeting-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "targeting_db"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = { Name = "${var.project_name}-targeting-db" }
}