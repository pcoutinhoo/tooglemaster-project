output "auth_db_endpoint"      { value = aws_db_instance.auth.endpoint }
output "flag_db_endpoint"      { value = aws_db_instance.flag.endpoint }
output "targeting_db_endpoint" { value = aws_db_instance.targeting.endpoint }
output "redis_endpoint"        { value = aws_elasticache_cluster.redis.cache_nodes[0].address }
