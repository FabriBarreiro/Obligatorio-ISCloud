

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name      = "${var.project_name}-${var.environment}-vpc"
    Component = "networking"
    Module    = "vpc"
  }
}
