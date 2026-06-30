output "redis_replication_group_id" {
  description = "ID del replication group Redis de ElastiCache."
  value       = aws_elasticache_replication_group.redis.id
}

output "redis_primary_endpoint" {
  description = "Endpoint primario DNS del replication group Redis de ElastiCache."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Endpoint de lectura DNS del replication group Redis de ElastiCache."
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Puerto TCP del replication group Redis de ElastiCache."
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_connection_string" {
  description = "Cadena de conexion host:puerto hacia el endpoint primario de Redis."
  value       = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
}

output "redis_subnet_group_name" {
  description = "Nombre del subnet group utilizado por ElastiCache Redis."
  value       = aws_elasticache_subnet_group.redis_subnet_group.name
}
