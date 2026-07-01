# Módulo Security Groups

Este módulo crea los Security Groups utilizados por la infraestructura del obligatorio para el Bastion Host, el cluster EKS, los worker nodes y ElastiCache Redis.

El diseño separa el acceso administrativo, la comunicación del control plane de EKS, el tráfico de los worker nodes, la publicación del frontend mediante ALB/Ingress y el acceso privado a Redis. Las reglas fueron definidas buscando permitir únicamente el tráfico necesario para el funcionamiento del stack dentro del entorno AWS Academy.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_security_group.bastion_sg` | Security Group del Bastion Host |
| `aws_security_group.eks_cluster_sg` | Security Group adicional asociado al cluster EKS |
| `aws_security_group.eks_nodes_sg` | Security Group de los worker nodes de EKS |
| `aws_security_group.elasticache_sg` | Security Group de ElastiCache Redis |
| `aws_security_group_rule.eks_nodes_to_cluster_https` | Regla HTTPS desde los worker nodes hacia el endpoint privado de EKS |
| `aws_security_group_rule.eks_cluster_to_nodes_https` | Regla HTTPS desde el control plane hacia los worker nodes |
| `aws_security_group_rule.eks_cluster_to_nodes_kubelet` | Regla del control plane hacia kubelet en los worker nodes |
| `aws_security_group_rule.eks_cluster_to_nodes_dns_tcp` | Regla DNS TCP desde el control plane hacia los worker nodes |
| `aws_security_group_rule.eks_cluster_to_nodes_dns_udp` | Regla DNS UDP desde el control plane hacia los worker nodes |

## Reglas de entrada

### Bastion Host

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| TCP 22 | `0.0.0.0/0` | Permite acceso SSH al Bastion Host desde Internet |

El acceso SSH al Bastion queda abierto para simplificar el uso en el laboratorio académico. En un entorno productivo debería restringirse a IPs administrativas específicas.

### EKS Cluster

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| TCP 443 | `bastion_sg` | Permite acceso HTTPS al endpoint privado de EKS desde el Bastion Host |
| TCP 443 | `eks_nodes_sg` | Permite comunicación HTTPS desde los worker nodes hacia el endpoint privado de EKS |

### EKS Worker Nodes

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| Todo el tráfico | `self` | Permite comunicación interna entre worker nodes |
| TCP 22 | `bastion_sg` | Permite administración SSH desde el Bastion Host hacia los worker nodes |
| TCP 443 | `eks_cluster_sg` | Permite comunicación del control plane de EKS hacia los worker nodes |
| TCP 10250 | `eks_cluster_sg` | Permite comunicación del control plane de EKS hacia kubelet en los worker nodes |
| TCP 3000 | `vpc_cidr_block` | Permite tráfico interno hacia Grafana cuando se publica mediante Ingress/ALB |
| TCP 30000-32767 | `vpc_cidr_block` | Permite tráfico NodePort desde dentro de la VPC, utilizado por el ALB con `target-type: instance` |

El rango NodePort no queda expuesto a Internet directamente. El acceso público al frontend se realiza mediante un Application Load Balancer en subnets públicas, administrado por AWS Load Balancer Controller a partir del Ingress de Kubernetes.

### ElastiCache Redis

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| TCP 6379 | `eks_nodes_sg` | Permite que los pods/microservicios ejecutados en EKS consuman Redis |

Redis no recibe tráfico desde toda la VPC ni desde Internet. Solo se permite acceso desde el Security Group de los worker nodes de EKS.

## Reglas de salida

### Bastion Host

| Protocolo / Puerto | Destino | Descripción |
|---|---|---|
| TCP 443 | `0.0.0.0/0` | Permite comunicación HTTPS hacia servicios de AWS e Internet |
| UDP 53 | `0.0.0.0/0` | Permite resolución DNS |
| TCP 53 | `0.0.0.0/0` | Permite resolución DNS cuando se requiere TCP |

### EKS Cluster

| Protocolo / Puerto | Destino | Descripción |
|---|---|---|
| TCP 443 | `eks_nodes_sg` | Permite HTTPS desde el control plane hacia los worker nodes |
| TCP 10250 | `eks_nodes_sg` | Permite comunicación del control plane hacia kubelet |
| TCP 53 | `eks_nodes_sg` | Permite DNS TCP desde el control plane hacia los worker nodes |
| UDP 53 | `eks_nodes_sg` | Permite DNS UDP desde el control plane hacia los worker nodes |

Estas reglas se definen como recursos `aws_security_group_rule` separados para evitar dependencias circulares entre el Security Group del cluster y el Security Group de los worker nodes.

### EKS Worker Nodes

| Protocolo / Puerto | Destino | Descripción |
|---|---|---|
| Todo el tráfico | `0.0.0.0/0` | Permite salida hacia AWS APIs, ECR, STS, DNS, Internet y servicios internos mediante NAT Gateway |

Los worker nodes se encuentran en subnets privadas. Su salida hacia Internet, Amazon ECR y APIs públicas de AWS se realiza a través del NAT Gateway. En un entorno productivo podría evaluarse el uso de VPC Endpoints para reducir la dependencia de salida a Internet.

### ElastiCache Redis

| Protocolo / Puerto | Destino | Descripción |
|---|---|---|
| Todo el tráfico | `0.0.0.0/0` | Permite tráfico saliente requerido por el servicio administrado |

## Tags relevantes

El Security Group de los worker nodes incluye el siguiente tag:

```text
kubernetes.io/cluster/<cluster_name> = owned
```

Este tag es requerido para que AWS Load Balancer Controller pueda identificar correctamente el Security Group backend del cluster y registrar las instancias EC2 del Managed Node Group como targets del Application Load Balancer cuando se utiliza `target-type: instance`.

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar los Security Groups |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `vpc_id` | `string` | ID de la VPC donde se crearán los Security Groups |
| `cluster_name` | `string` | Nombre del cluster EKS utilizado para tags de Kubernetes |
| `vpc_cidr_block` | `string` | CIDR principal de la VPC utilizado para permitir tráfico interno necesario entre ALB, nodos EKS y pods |

## Outputs

| Output | Descripción |
|---|---|
| `bastion_security_group_id` | ID del Security Group del Bastion Host |
| `eks_cluster_security_group_id` | ID del Security Group adicional del cluster EKS |
| `eks_nodes_security_group_id` | ID del Security Group de los worker nodes de EKS |
| `elasticache_security_group_id` | ID del Security Group de ElastiCache Redis |

## Ejemplo de uso

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = var.vpc_cidr_block
  cluster_name   = var.cluster_name
}
```

## Consideraciones

- El Bastion Host es el único recurso con SSH expuesto directamente a Internet.
- El acceso SSH al Bastion se mantiene abierto desde `0.0.0.0/0` para simplificar el laboratorio académico.
- En un entorno productivo, el acceso SSH debería restringirse a IPs administrativas específicas.
- El endpoint privado de EKS permite acceso HTTPS desde el Bastion y desde los worker nodes.
- Los worker nodes permiten tráfico NodePort únicamente desde el CIDR de la VPC, no desde Internet.
- La publicación pública del frontend se realiza mediante Ingress, AWS Load Balancer Controller y Application Load Balancer.
- El Security Group de los worker nodes incluye el tag requerido por AWS Load Balancer Controller para registrar targets.
- ElastiCache Redis solo acepta tráfico TCP `6379` desde los worker nodes de EKS.
- La salida amplia de los worker nodes se mantiene porque los nodos privados deben acceder a ECR, STS, APIs de AWS, DNS y otros servicios mediante NAT Gateway.
- En una arquitectura productiva se podrían incorporar VPC Endpoints para ECR, S3, STS y otros servicios, reduciendo la necesidad de salida a Internet desde los nodos privados.
