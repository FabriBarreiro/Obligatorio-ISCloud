# Módulo EKS

Este módulo crea el cluster Amazon EKS utilizado para ejecutar la aplicación en Kubernetes.

El diseño despliega el control plane de EKS y los worker nodes dentro de subnets privadas. El endpoint del cluster queda configurado con acceso privado y público para facilitar la administración desde el equipo local durante el laboratorio.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `data.aws_iam_role.cluster_service_role` | Obtiene el rol `LabRole` existente para el control plane de EKS |
| `data.aws_iam_role.node_group_role` | Obtiene el rol `LabRole` existente para los worker nodes |
| `aws_eks_cluster.eks_cluster` | Cluster EKS |
| `aws_launch_template.eks_nodes_launch_template` | Launch Template para los worker nodes |
| `aws_eks_node_group.eks_node_group` | Node group administrado de EKS |
| `aws_eks_addon.eks_addons` | Add-ons administrados del cluster |

## Diseño del cluster

El cluster se crea utilizando el rol `LabRole`, disponible en AWS Academy. Este rol se reutiliza tanto para el control plane como para el node group, evitando crear roles IAM adicionales.

Los worker nodes se despliegan en subnets privadas, lo que evita su exposición directa a Internet. Para permitir salida hacia servicios como ECR o APIs de AWS, las subnets privadas utilizan el NAT Gateway definido en los módulos de red.

## Acceso al endpoint de EKS

El endpoint del cluster queda configurado de la siguiente forma:

```hcl
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]
```

Esto significa que la API de Kubernetes es accesible desde dentro de la VPC y también desde Internet. Esta configuración permite administrar el cluster directamente desde el equipo local usando `aws eks update-kubeconfig` y `kubectl`.

Aunque el endpoint público queda accesible desde cualquier origen, la administración del cluster sigue requiriendo credenciales válidas de AWS/IAM. En un entorno productivo, este acceso debería restringirse a IPs administrativas específicas mediante `public_access_cidrs`.

## Add-ons instalados

Por defecto se instalan los siguientes add-ons administrados de EKS:

| Add-on | Función |
|---|---|
| `vpc-cni` | Integra la red de Kubernetes con la VPC de AWS |
| `coredns` | Provee resolución DNS interna del cluster |
| `kube-proxy` | Maneja reglas de red para Services de Kubernetes |
| `aws-ebs-csi-driver` | Permite utilizar volúmenes EBS mediante PersistentVolumeClaims |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar recursos asociados al cluster |
| `cluster_name` | `string` | Nombre del cluster EKS |
| `kubernetes_version` | `string` | Versión de Kubernetes utilizada por el cluster |
| `private_subnet_ids` | `list(string)` | IDs de las subnets privadas donde se desplegarán el cluster y los nodos |
| `eks_cluster_security_group_id` | `string` | ID del Security Group asociado al control plane de EKS |
| `eks_public_access_cidrs` | `list(string)` | CIDRs permitidos para acceder al endpoint público del cluster EKS |
| `eks_nodes_security_group_id` | `string` | ID del Security Group asociado a los worker nodes |
| `key_name` | `string` | Nombre del Key Pair utilizado para acceso SSH a los nodos |
| `node_instance_types` | `list(string)` | Tipos de instancia EC2 utilizados por los worker nodes |
| `node_desired_size` | `number` | Cantidad deseada de worker nodes |
| `node_min_size` | `number` | Cantidad mínima de worker nodes |
| `node_max_size` | `number` | Cantidad máxima de worker nodes |
| `cluster_addons` | `list(string)` | Lista de add-ons administrados de EKS |

## Outputs

| Output | Descripción |
|---|---|
| `cluster_name` | Nombre del cluster EKS creado |
| `cluster_arn` | ARN del cluster EKS creado |
| `cluster_endpoint` | Endpoint de la API del cluster EKS |
| `cluster_certificate_authority_data` | Certificado CA del cluster codificado en base64 |
| `node_group_name` | Nombre del node group creado |
| `node_group_arn` | ARN del node group creado |
| `cluster_addons` | Add-ons instalados en el cluster |

## Ejemplo de uso

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name                  = "obligatorio-iscloud"
  cluster_name                  = "obligatorio-iscloud-prod-eks"
  kubernetes_version            = "1.29"
  private_subnet_ids            = module.subnets.private_subnet_ids
  eks_cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  eks_public_access_cidrs       = ["0.0.0.0/0"]
  eks_nodes_security_group_id   = module.security_groups.eks_nodes_security_group_id
  key_name                      = "vockey"

  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 2
  node_max_size       = 4
}
```

## Consideraciones

- Se utiliza `LabRole` porque el entorno AWS Academy limita la creación y administración de roles IAM personalizados.
- Los worker nodes se ubican en subnets privadas para reducir la exposición directa a Internet.
- El acceso administrativo al cluster se puede realizar directamente desde el equipo local porque el endpoint público está habilitado.
- El Key Pair utilizado por defecto es `vockey`, provisto por AWS Academy.
- El add-on `aws-ebs-csi-driver` permite utilizar almacenamiento persistente con EBS en caso de que la aplicación o servicios auxiliares lo requieran.
- Para simplificar el laboratorio, `public_access_cidrs` queda configurado como `["0.0.0.0/0"]`; en producción debería limitarse a IPs administrativas conocidas.
