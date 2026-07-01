

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name      = "${var.project_name}-${var.environment}-redis-subnet-group"
    Component = "elasticache"
    Module    = "elasticache"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  description                = "Redis Multi-AZ para ${var.project_name} ${var.environment}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_clusters
  parameter_group_name       = "default.redis7"
  port                       = var.port
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [var.security_group_id]
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  tags = {
    Name      = "${var.project_name}-${var.environment}-redis"
    Component = "elasticache"
    Module    = "elasticache"
  }
}
