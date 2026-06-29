module "vpc" {
  source = "../../modules/vpc"

  project_name   = var.project_name
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source = "../../modules/subnets"

  project_name               = var.project_name
  environment                = var.environment
  cluster_name               = var.cluster_name
  vpc_id                     = module.vpc.vpc_id
  availability_zones         = var.availability_zones
  public_subnet_cidr_blocks  = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
}

module "igw" {
  source = "../../modules/igw"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "natgw" {
  source = "../../modules/natgw"

  project_name     = var.project_name
  environment      = var.environment
  public_subnet_id = module.subnets.public_subnet_ids[0]

  depends_on = [
    module.igw
  ]
}

module "route_tables" {
  source = "../../modules/route-tables"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.igw.internet_gateway_id
  nat_gateway_id      = module.natgw.nat_gateway_id
  public_subnet_ids   = module.subnets.public_subnet_ids
  private_subnet_ids  = module.subnets.private_subnet_ids
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "ec2" {
  source = "../../modules/ec2"

  project_name              = var.project_name
  environment               = var.environment
  public_subnet_id          = module.subnets.public_subnet_ids[0]
  bastion_security_group_id = module.security_groups.bastion_security_group_id
  instance_type             = var.bastion_instance_type
  key_name                  = var.key_name
  root_volume_size          = var.bastion_root_volume_size

  depends_on = [
    module.route_tables
  ]
}

module "eks" {
  source = "../../modules/eks"

  project_name                  = var.project_name
  cluster_name                  = var.cluster_name
  kubernetes_version            = var.kubernetes_version
  private_subnet_ids            = module.subnets.private_subnet_ids
  eks_cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  eks_public_access_cidrs       = var.eks_public_access_cidrs
  eks_nodes_security_group_id   = module.security_groups.eks_nodes_security_group_id
  key_name                      = var.key_name
  node_instance_types           = var.node_instance_types
  node_desired_size             = var.node_desired_size
  node_min_size                 = var.node_min_size
  node_max_size                 = var.node_max_size
  cluster_addons                = var.cluster_addons

  depends_on = [
    module.route_tables,
    module.ec2
  ]
}
