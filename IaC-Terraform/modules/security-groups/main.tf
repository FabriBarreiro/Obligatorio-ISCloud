resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security Group para el Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    description = "Permite SSH hacia el bastion desde Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permite salida HTTPS hacia servicios de AWS e Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permite consultas DNS por UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permite consultas DNS por TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security Group adicional para el cluster EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Permite acceso HTTPS al endpoint privado de EKS desde el bastion"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_nodes_sg" {
  name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
  description = "Security Group para los worker nodes de EKS"
  vpc_id      = var.vpc_id

  ingress {
    description = "Permite comunicacion interna entre worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description     = "Permite administracion SSH desde el bastion hacia los worker nodes"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "Permite comunicacion del control plane de EKS hacia los worker nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  ingress {
    description     = "Permite comunicacion del control plane de EKS hacia kubelet en los worker nodes"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  ingress {
    description = "Permite trafico NodePort para publicacion de servicios Kubernetes"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  ingress {
    description = "Permite trafico desde ALB hacia pods de grafana publicados por Ingress"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Permite salida desde los worker nodes hacia AWS APIs, ECR, STS, DNS, Internet y servicios internos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.project_name}-${var.environment}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group" "elasticache_sg" {
  name        = "${var.project_name}-${var.environment}-elasticache-sg"
  description = "Security Group para ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Permite acceso Redis desde los worker nodes de EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes_sg.id]
  }

  egress {
    description = "Permite trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-elasticache-sg"
  }
}

resource "aws_security_group_rule" "eks_nodes_to_cluster_https" {
  description              = "Permite comunicacion HTTPS desde los worker nodes hacia el endpoint privado de EKS"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

resource "aws_security_group_rule" "eks_cluster_to_nodes_https" {
  description              = "Permite HTTPS desde el control plane hacia los worker nodes"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

resource "aws_security_group_rule" "eks_cluster_to_nodes_kubelet" {
  description              = "Permite comunicacion del control plane hacia kubelet en los worker nodes"
  type                     = "egress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

resource "aws_security_group_rule" "eks_cluster_to_nodes_dns_tcp" {
  description              = "Permite DNS TCP desde el control plane hacia los worker nodes"
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

resource "aws_security_group_rule" "eks_cluster_to_nodes_dns_udp" {
  description              = "Permite DNS UDP desde el control plane hacia los worker nodes"
  type                     = "egress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}
