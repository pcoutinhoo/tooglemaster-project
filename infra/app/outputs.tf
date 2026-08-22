output "auth_db_endpoint"      { value = module.database.auth_db_endpoint }
output "flag_db_endpoint"      { value = module.database.flag_db_endpoint }
output "targeting_db_endpoint" { value = module.database.targeting_db_endpoint }
output "redis_endpoint"        { value = module.database.redis_endpoint }

output "sqs_url"         { value = module.messaging.sqs_url }
output "sqs_arn"         { value = module.messaging.sqs_arn }
output "dynamodb_table"  { value = module.messaging.dynamodb_table }
output "ecr_urls"        { value = module.messaging.ecr_urls }

output "eks_cluster_name"     { value = module.eks.cluster_name }
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "eks_cluster_status"   { value = module.eks.cluster_status }
