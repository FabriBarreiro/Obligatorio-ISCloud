

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name      = "${var.project_name}-${var.environment}-redis-subnet-group"
    Component = "elasticache"
    Module    = "elasticache"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = "default.redis7"
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [var.security_group_id]

  tags = {
    Name      = "${var.project_name}-${var.environment}-redis"
    Component = "elasticache"
    Module    = "elasticache"
  }
}
