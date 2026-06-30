data "aws_iam_role" "cluster_service_role" {
  name = "LabRole"
}

data "aws_iam_role" "node_group_role" {
  name = "LabRole"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.cluster_service_role.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.eks_cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_public_access_cidrs
  }

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_launch_template" "eks_nodes_launch_template" {
  name_prefix = "${var.cluster_name}-nodes-"

  key_name = var.key_name
  vpc_security_group_ids = [
    var.eks_nodes_security_group_id,
    var.eks_cluster_security_group_id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster_name}-node"
    }
  }

  tags = {
    Name = "${var.cluster_name}-nodes-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = data.aws_iam_role.node_group_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodes_launch_template.id
    version = aws_launch_template.eks_nodes_launch_template.latest_version
  }

  tags = {
    Name = "${var.cluster_name}-node-group"

    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_launch_template.eks_nodes_launch_template
  ]
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_enabled" {
  autoscaling_group_name = aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_cluster" {
  autoscaling_group_name = aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

resource "aws_eks_addon" "eks_addons" {
  for_each = toset(var.cluster_addons)

  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.eks_node_group
  ]
}
