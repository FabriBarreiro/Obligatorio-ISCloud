# Módulo EKS

Este módulo crea el cluster Amazon EKS utilizado para ejecutar la aplicación de microservicios sobre Kubernetes.

El diseño utiliza Amazon EKS con Managed Node Group en subnets privadas. El endpoint del cluster queda configurado con acceso privado y público para facilitar la administración durante el laboratorio, mientras que los worker nodes no quedan expuestos directamente a Internet.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_eks_cluster.eks_cluster` | Cluster Amazon EKS |
| `aws_launch_template.eks_nodes_launch_template` | Launch Template utilizado por los worker nodes |
| `aws_eks_addon.vpc_cni` | Add-on administrado VPC CNI, configurado con prefix delegation |
| `aws_eks_node_group.eks_node_group` | Managed Node Group de EKS |
| `aws_eks_addon.eks_addons` | Add-ons administrados restantes del cluster, excluyendo `vpc-cni` |
| `aws_autoscaling_group_tag.cluster_autoscaler_enabled` | Tag requerido por Cluster Autoscaler para detectar el Auto Scaling Group |
| `aws_autoscaling_group_tag.cluster_autoscaler_cluster` | Tag requerido por Cluster Autoscaler asociado al nombre del cluster |

## Diseño del cluster

El cluster se crea utilizando el rol IAM recibido mediante la variable `eks_role_arn`. En el ambiente `prod`, este valor se construye dinámicamente a partir del Account ID actual y del nombre del rol definido en `eks_role_name`. En AWS Academy se utiliza `LabRole`, ya que el laboratorio limita la creación de roles IAM personalizados.

El mismo rol se utiliza tanto para el control plane como para el node group, adaptándose a las restricciones del entorno académico.

Los worker nodes se despliegan en subnets privadas de aplicación, evitando exposición directa a Internet. Para permitir salida hacia Amazon ECR, APIs públicas de AWS, STS, DNS e Internet, las subnets privadas utilizan el NAT Gateway definido en los módulos de red.

El node group se crea mediante un Launch Template que configura las instancias con IMDSv2 requerido y `http_put_response_hop_limit = 2`, necesario para que componentes ejecutados en pods puedan acceder correctamente a metadata cuando corresponda dentro del entorno del laboratorio.

## VPC CNI y prefix delegation

El add-on `vpc-cni` se administra en un recurso separado (`aws_eks_addon.vpc_cni`) y se crea antes del Managed Node Group. Esto permite habilitar **prefix delegation** desde Terraform antes de que se aprovisionen los worker nodes.

La configuración aplicada es:

```hcl
configuration_values = jsonencode({
  env = {
    ENABLE_PREFIX_DELEGATION = "true"
    WARM_PREFIX_TARGET       = "1"
  }
})
```

Con prefix delegation, el VPC CNI puede asignar prefijos IPv4 a las ENI de los nodos, mejorando la disponibilidad de IPs para pods y aumentando la densidad posible de pods por nodo. Esto es especialmente útil en instancias pequeñas como `t3.medium`, donde la cantidad de pods puede verse limitada por la cantidad de IPs disponibles.

El Managed Node Group depende explícitamente del add-on `vpc-cni`, por lo que los nodos se crean luego de que el CNI esté configurado.

## Acceso al endpoint de EKS

El endpoint del cluster queda configurado de la siguiente forma:

```hcl
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]
```

Esto significa que la API de Kubernetes es accesible desde dentro de la VPC y también desde Internet. Esta configuración permite administrar el cluster desde el equipo local usando `aws eks update-kubeconfig`, `kubectl` y `helm`.

Aunque el endpoint público queda accesible desde cualquier origen, la administración del cluster sigue requiriendo credenciales válidas de AWS/IAM. En un entorno productivo, este acceso debería restringirse a IPs administrativas específicas mediante `public_access_cidrs`.

## Add-ons administrados

Este módulo administra los siguientes add-ons de EKS:

| Add-on | Recurso Terraform | Función |
|---|---|---|
| `vpc-cni` | `aws_eks_addon.vpc_cni` | Integra la red de Kubernetes con la VPC de AWS y se configura con prefix delegation |
| `coredns` | `aws_eks_addon.eks_addons` | Provee resolución DNS interna del cluster |
| `kube-proxy` | `aws_eks_addon.eks_addons` | Maneja reglas de red para Services de Kubernetes |

El add-on `vpc-cni` se filtra del recurso genérico `aws_eks_addon.eks_addons` para evitar que Terraform intente crearlo dos veces.

El EBS CSI Driver no se instala desde este módulo. Se instala posteriormente desde el script `eks-setup.sh`, debido a las restricciones de AWS Academy relacionadas con IAM/OIDC/IRSA.

## Cluster Autoscaler

El módulo agrega tags al Auto Scaling Group asociado al Managed Node Group para que Cluster Autoscaler pueda detectarlo:

```text
k8s.io/cluster-autoscaler/enabled = true
k8s.io/cluster-autoscaler/<cluster_name> = owned
```

Cluster Autoscaler no se instala desde este módulo. Su instalación se realiza posteriormente mediante `eks-setup.sh` usando Helm.

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar recursos asociados al cluster |
| `eks_role_arn` | `string` | ARN del rol IAM utilizado por el cluster EKS y los worker nodes |
| `cluster_name` | `string` | Nombre del cluster EKS |
| `kubernetes_version` | `string` | Versión de Kubernetes utilizada por el cluster |
| `private_subnet_ids` | `list(string)` | IDs de las subnets privadas donde se desplegarán los worker nodes |
| `eks_cluster_security_group_id` | `string` | ID del Security Group adicional asociado al control plane de EKS |
| `eks_public_access_cidrs` | `list(string)` | CIDRs permitidos para acceder al endpoint público del cluster EKS |
| `eks_nodes_security_group_id` | `string` | ID del Security Group asociado a los worker nodes |
| `key_name` | `string` | Nombre del Key Pair utilizado para acceso SSH a los nodos |
| `node_instance_types` | `list(string)` | Tipos de instancia EC2 utilizados por los worker nodes |
| `node_desired_size` | `number` | Cantidad deseada de worker nodes |
| `node_min_size` | `number` | Cantidad mínima de worker nodes |
| `node_max_size` | `number` | Cantidad máxima de worker nodes |
| `cluster_addons` | `list(string)` | Lista de add-ons administrados de EKS |
| `enable_vpc_cni_prefix_delegation` | `bool` | Habilita prefix delegation en el add-on VPC CNI |
| `vpc_cni_warm_prefix_target` | `number` | Cantidad de prefijos IPv4 /28 que el VPC CNI mantiene disponibles por nodo |

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

  project_name                  = var.project_name
  eks_role_arn                  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_role_name}"
  cluster_name                  = var.cluster_name
  kubernetes_version            = var.kubernetes_version
  private_subnet_ids            = module.subnets.private_subnet_ids
  eks_cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  eks_public_access_cidrs       = var.eks_public_access_cidrs
  eks_nodes_security_group_id   = module.security_groups.eks_nodes_security_group_id
  key_name                      = var.key_name

  node_instance_types              = var.node_instance_types
  node_desired_size                = var.node_desired_size
  node_min_size                    = var.node_min_size
  node_max_size                    = var.node_max_size
  cluster_addons                   = var.cluster_addons
  enable_vpc_cni_prefix_delegation = var.enable_vpc_cni_prefix_delegation
  vpc_cni_warm_prefix_target       = var.vpc_cni_warm_prefix_target
}
```

## Validaciones útiles

Luego de aplicar Terraform y configurar el cluster, se puede validar que el VPC CNI quedó con prefix delegation:

```bash
kubectl -n kube-system get daemonset aws-node -o yaml | grep -A3 ENABLE_PREFIX_DELEGATION
```

El valor esperado es:

```text
ENABLE_PREFIX_DELEGATION
true
```

También se puede consultar el add-on desde AWS CLI:

```bash
aws eks describe-addon \
  --cluster-name obligatorio-iscloud-prod-eks \
  --addon-name vpc-cni \
  --region us-east-1 \
  --query 'addon.configurationValues' \
  --output text
```

Para validar el node group:

```bash
aws eks describe-nodegroup \
  --cluster-name obligatorio-iscloud-prod-eks \
  --nodegroup-name obligatorio-iscloud-prod-eks-node-group \
  --region us-east-1
```

## Consideraciones

- Se utiliza `LabRole` en el ambiente `prod` porque AWS Academy limita la creación y administración de roles IAM personalizados.
- El módulo recibe el ARN del rol mediante `eks_role_arn`, evitando hardcodear el Account ID dentro del módulo.
- Los worker nodes se ubican en subnets privadas de aplicación para reducir la exposición directa a Internet.
- Los worker nodes utilizan NAT Gateway para descargar imágenes desde ECR y comunicarse con APIs públicas de AWS.
- El acceso administrativo al cluster se puede realizar desde el equipo local porque el endpoint público está habilitado.
- El Key Pair utilizado por defecto es `vockey`, provisto por AWS Academy.
- El VPC CNI se configura con prefix delegation antes de crear el node group.
- `coredns` y `kube-proxy` se instalan como add-ons administrados por EKS.
- El EBS CSI Driver, AWS Load Balancer Controller, Cluster Autoscaler y el stack de monitoreo se instalan luego mediante `eks-setup.sh`.
- Para simplificar el laboratorio, `public_access_cidrs` queda configurado como `["0.0.0.0/0"]`; en producción debería limitarse a IPs administrativas conocidas.
- En un entorno productivo debería utilizarse IRSA para asignar permisos mínimos a cada ServiceAccount. En AWS Academy se omite la creación del OIDC Provider por restricciones del laboratorio.
