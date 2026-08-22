variable "project_name"        {}
variable "db_password"         { sensitive = true }
variable "private_subnet_ids"  { type = list(string) }
variable "rds_sg_id"           {}
variable "redis_sg_id"         {}
