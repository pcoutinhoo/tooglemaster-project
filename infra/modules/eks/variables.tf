variable "project_name"       {}
variable "lab_role_arn"       {}
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "eks_nodes_sg_id"    {}
