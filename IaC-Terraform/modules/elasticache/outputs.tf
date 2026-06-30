

output "redis_cluster_id" {
  description = "ID del cluster Redis de ElastiCache."
  value       = aws_elasticache_cluster.redis.id
}

output "redis_endpoint" {
  description = "Endpoint DNS del cluster Redis de ElastiCache."
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Puerto TCP del cluster Redis de ElastiCache."
  value       = aws_elasticache_cluster.redis.port
}

output "redis_connection_string" {
  description = "Cadena de conexion host:puerto para Redis."
  value       = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.port}"
}

output "redis_subnet_group_name" {
  description = "Nombre del subnet group utilizado por ElastiCache Redis."
  value       = aws_elasticache_subnet_group.redis_subnet_group.name
}
