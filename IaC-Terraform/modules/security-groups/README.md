# Módulo Security Groups

Este módulo crea los Security Groups mínimos para el Bastion Host, el cluster EKS y los worker nodes.

El diseño separa el acceso administrativo, el acceso al endpoint del cluster y el tráfico necesario para la publicación de servicios Kubernetes. El Bastion Host es el punto de entrada por SSH a la red, el cluster EKS permite acceso HTTPS únicamente desde el Security Group del bastion, y los worker nodes permiten el tráfico necesario para la operación del cluster y la publicación de servicios mediante `Service` de tipo `LoadBalancer`.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_security_group.bastion_sg` | Security Group del Bastion Host |
| `aws_security_group.eks_cluster_sg` | Security Group adicional para el cluster EKS |
| `aws_security_group.eks_nodes_sg` | Security Group para los worker nodes de EKS |

## Reglas de entrada

### Bastion Host

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| TCP 22 | `0.0.0.0/0` | Permite acceso SSH al bastion desde Internet |

### EKS Cluster

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| TCP 443 | `bastion_sg` | Permite acceso HTTPS al endpoint privado de EKS desde el bastion |

### EKS Worker Nodes

| Protocolo / Puerto | Origen | Descripción |
|---|---|---|
| Todo el tráfico | `eks_nodes_sg` | Permite comunicación interna entre worker nodes |
| TCP 22 | `bastion_sg` | Permite administración SSH desde el bastion hacia los worker nodes |
| TCP 443 | `eks_cluster_sg` | Permite comunicación del control plane de EKS hacia los worker nodes |
| TCP 30000-32767 | `0.0.0.0/0` | Permite tráfico NodePort utilizado por servicios Kubernetes publicados mediante Load Balancer |

## Reglas de salida

Los Security Groups permiten únicamente el tráfico saliente mínimo necesario para administración, resolución DNS y comunicación HTTPS con servicios de AWS e Internet.

| Protocolo / Puerto | Destino | Descripción |
|---|---|---|
| TCP 443 | `0.0.0.0/0` | Permite comunicación HTTPS hacia servicios de AWS e Internet |
| UDP 53 | `0.0.0.0/0` | Permite resolución DNS |
| TCP 53 | `0.0.0.0/0` | Permite resolución DNS cuando la consulta requiere TCP |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar los Security Groups |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `vpc_id` | `string` | ID de la VPC donde se crearán los Security Groups del bastion, cluster EKS y worker nodes |

## Outputs

| Output | Descripción |
|---|---|
| `bastion_security_group_id` | ID del Security Group del Bastion Host |
| `eks_cluster_security_group_id` | ID del Security Group adicional del cluster EKS |
| `eks_nodes_security_group_id` | ID del Security Group de los worker nodes de EKS |

## Ejemplo de uso

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = "obligatorio-iscloud"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
}
```

## Consideraciones

- El Bastion Host es el único recurso con SSH expuesto directamente a Internet.
- El acceso SSH al bastion se permite desde Internet para simplificar el acceso administrativo durante el laboratorio académico.
- En un entorno productivo, el acceso SSH debería restringirse a IPs administrativas específicas.
- EKS no queda expuesto directamente para administración desde cualquier origen.
- El acceso administrativo al cluster se realiza desde el bastion mediante HTTPS al endpoint privado de EKS.
- Los worker nodes permiten el rango NodePort `30000-32767` para no bloquear la publicación de servicios Kubernetes mediante `Service` de tipo `LoadBalancer`.
- Si posteriormente se implementa un Ingress con ALB Controller, se puede agregar un Security Group específico para ALB y restringir el acceso a los worker nodes desde dicho Security Group.
- Los workloads dentro de Kubernetes se administran con `kubectl`, por ejemplo usando `kubectl logs`, `kubectl exec` o `kubectl port-forward`.
- El tráfico saliente queda limitado a HTTPS y DNS para mantener una postura de seguridad simple y controlada.
