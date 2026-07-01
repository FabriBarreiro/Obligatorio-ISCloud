# Environment Prod

Este directorio contiene la definición Terraform del ambiente `prod` para el obligatorio de Implementación de Soluciones Cloud.

Desde este environment se conectan todos los módulos de infraestructura necesarios para desplegar la arquitectura en AWS Academy.

## Módulos utilizados

| Módulo | Descripción |
|---|---|
| `vpc` | Crea la VPC principal del proyecto |
| `subnets` | Crea subnets públicas, privadas de aplicación y privadas de datos en dos zonas de disponibilidad |
| `igw` | Crea el Internet Gateway para la VPC |
| `natgw` | Crea el NAT Gateway para salida a Internet desde subnets privadas |
| `route-tables` | Crea y asocia tablas de rutas públicas y privadas |
| `security-groups` | Crea los Security Groups del Bastion, EKS, worker nodes y ElastiCache |
| `ecr` | Crea un repositorio ECR por microservicio de la aplicación |
| `ec2` | Crea el Bastion Host para administración |
| `eks` | Crea el cluster EKS, node group, launch template y add-ons administrados |
| `elasticache` | Crea el replication group de ElastiCache Redis Multi-AZ |
| `backup` | Crea el plan de AWS Backup para respaldar volúmenes EBS etiquetados |

## Arquitectura desplegada

La infraestructura queda distribuida de la siguiente forma:

```text
VPC 10.0.0.0/16

├── Public Subnet 1  10.0.1.0/24  us-east-1a
│   ├── Bastion Host
│   ├── NAT Gateway
│   └── Application Load Balancer público
│
├── Public Subnet 2  10.0.2.0/24  us-east-1b
│   └── Application Load Balancer público
│
├── Private App Subnet 1 10.0.3.0/24  us-east-1a
│   └── Worker nodes EKS / Pods
│
├── Private App Subnet 2 10.0.4.0/24  us-east-1b
│   └── Worker nodes EKS / Pods
│
├── Private Data Subnet 1 10.0.5.0/24  us-east-1a
│   └── ElastiCache Redis Primary/Replica
│
└── Private Data Subnet 2 10.0.6.0/24  us-east-1b
    └── ElastiCache Redis Primary/Replica
```

## Conectividad

Las subnets públicas tienen salida directa a Internet mediante el Internet Gateway.

Las subnets privadas de aplicación y datos no tienen exposición directa a Internet. La salida desde los worker nodes hacia Internet, Amazon ECR y APIs públicas de AWS se realiza mediante el NAT Gateway ubicado en una subnet pública.

El Bastion Host se ubica en una subnet pública y se utiliza como punto de administración para recursos privados cuando sea necesario.

Los worker nodes y los pods de la aplicación se ejecutan en subnets privadas de aplicación. ElastiCache Redis se despliega en subnets privadas de datos y no queda expuesto públicamente.

## EKS

El cluster EKS utiliza el rol `LabRole`, disponible en AWS Academy. El ARN del rol se construye dinámicamente a partir del Account ID actual y de la variable `eks_role_name`.

Los worker nodes se crean mediante un Managed Node Group en subnets privadas y utilizan el Key Pair `vockey` para acceso SSH en caso de ser necesario.

El módulo EKS instala el add-on `vpc-cni` de forma separada antes de crear el node group, permitiendo habilitar **prefix delegation** desde Terraform. Esto mejora la asignación de direcciones IP para pods y aumenta la densidad posible de pods por nodo.

Add-ons administrados por Terraform:

```text
vpc-cni     con prefix delegation
coredns
kube-proxy
```

El EBS CSI Driver se instala posteriormente desde el script `eks-setup.sh`, debido a las restricciones de permisos del entorno AWS Academy e IRSA.

## Exposición pública de la aplicación

La exposición pública del frontend se realiza mediante Kubernetes Ingress y AWS Load Balancer Controller.

El Ingress `frontend-alb` es procesado por AWS Load Balancer Controller, que crea automáticamente un Application Load Balancer público en AWS. El ALB recibe tráfico HTTP desde Internet y lo dirige hacia el Service `frontend-external`, expuesto como NodePort, que finalmente enruta el tráfico hacia los pods del frontend.

El flujo esperado es:

```text
Usuario en Internet
        ↓
Internet Gateway
        ↓
Application Load Balancer público
        ↓
Ingress frontend-alb
        ↓
Service frontend-external / NodePort
        ↓
Pods del frontend en EKS
```

En este diseño, las subnets públicas se utilizan para ubicar el Application Load Balancer, mientras que los worker nodes y los pods permanecen en subnets privadas.

Las subnets públicas y privadas fueron etiquetadas para que AWS Load Balancer Controller pueda identificar dónde crear Load Balancers públicos o internos:

```text
Subnets públicas  → kubernetes.io/role/elb = 1
Subnets privadas  → kubernetes.io/role/internal-elb = 1
```

Además, el Security Group de los worker nodes se etiqueta con:

```text
kubernetes.io/cluster/obligatorio-iscloud-prod-eks = owned
```

Este tag permite que AWS Load Balancer Controller identifique correctamente el Security Group backend del cluster y registre las instancias del node group como targets del ALB cuando se utiliza `target-type: instance`.

## ECR

Se crea un repositorio ECR por microservicio de la aplicación.

Ejemplos:

```text
obligatorio-iscloud-prod-frontend
obligatorio-iscloud-prod-cartservice
obligatorio-iscloud-prod-checkoutservice
obligatorio-iscloud-prod-productcatalogservice
```

Las imágenes se publican en los repositorios correspondientes mediante los scripts de build/deploy. Para asegurar compatibilidad con los worker nodes EKS `amd64`, el build se realiza con `docker buildx` utilizando la plataforma `linux/amd64`.

## ElastiCache Redis

ElastiCache Redis se utiliza para almacenar el estado del carrito de compras.

El despliegue se realiza como replication group Multi-AZ, con réplica y failover automático. Redis se ubica en subnets privadas de datos y solo permite tráfico TCP `6379` desde el Security Group de los worker nodes EKS.

Se configuran snapshots automáticos con retención de 7 días.

## Variables principales

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `project_name` | `obligatorio-iscloud` | Nombre base del proyecto |
| `environment` | `prod` | Ambiente desplegado |
| `cluster_name` | `obligatorio-iscloud-prod-eks` | Nombre del cluster EKS |
| `eks_role_name` | `LabRole` | Nombre del rol IAM utilizado por EKS y los worker nodes |
| `vpc_cidr_block` | `10.0.0.0/16` | CIDR principal de la VPC |
| `availability_zones` | `us-east-1a`, `us-east-1b` | Zonas de disponibilidad utilizadas |
| `public_subnet_cidr_blocks` | `10.0.1.0/24`, `10.0.2.0/24` | CIDR de subnets públicas |
| `private_subnet_cidr_blocks` | `10.0.3.0/24`, `10.0.4.0/24` | CIDR de subnets privadas de aplicación |
| `data_subnet_cidr_blocks` | `10.0.5.0/24`, `10.0.6.0/24` | CIDR de subnets privadas de datos |
| `key_name` | `vockey` | Key Pair de AWS Academy |
| `bastion_instance_type` | `t3.micro` | Tipo de instancia del Bastion Host |
| `node_instance_types` | `t3.medium` | Tipo de instancia de los worker nodes |
| `node_desired_size` | `2` | Cantidad deseada de worker nodes |
| `node_min_size` | `2` | Cantidad mínima de worker nodes |
| `node_max_size` | `4` | Cantidad máxima de worker nodes |
| `enable_vpc_cni_prefix_delegation` | `true` | Habilita prefix delegation en el VPC CNI |
| `vpc_cni_warm_prefix_target` | `1` | Cantidad de prefijos IPv4 /28 que el VPC CNI mantiene disponibles por nodo |
| `redis_node_type` | `cache.t3.micro` | Tipo de nodo utilizado por ElastiCache Redis |
| `redis_num_cache_clusters` | `2` | Cantidad de nodos del replication group Redis |

## Comandos de uso

Inicializar Terraform:

```bash
terraform init
```

Validar la configuración:

```bash
terraform validate
```

Revisar el plan de cambios:

```bash
terraform plan
```

Aplicar la infraestructura:

```bash
terraform apply
```

Destruir la infraestructura:

```bash
terraform destroy
```

## Outputs esperados

El environment expone información útil como:

```text
VPC ID
Subnets públicas, privadas de aplicación y privadas de datos
IP pública del Bastion Host
Endpoint del cluster EKS
URLs de repositorios ECR
Nombre del node group
Add-ons instalados
Endpoint primario y reader endpoint de Redis
ID del plan de AWS Backup
```

## Consideraciones

- La región se define en `providers.tf` y queda configurada en `us-east-1`.
- Se utiliza `LabRole` porque AWS Academy limita la creación de roles IAM personalizados.
- El Key Pair utilizado es `vockey`, provisto por AWS Academy.
- El Bastion Host se usa para administrar recursos privados dentro de la VPC cuando sea necesario.
- Los worker nodes de EKS quedan en subnets privadas de aplicación.
- ElastiCache Redis queda en subnets privadas de datos y solo acepta tráfico desde los worker nodes EKS.
- El NAT Gateway permite que los recursos privados accedan a ECR, APIs de AWS e Internet sin recibir conexiones entrantes directas.
- La publicación pública del frontend se gestiona con Kubernetes Ingress, AWS Load Balancer Controller y Application Load Balancer.
- El VPC CNI se configura con prefix delegation desde Terraform antes de crear el node group.
- En el entorno AWS Academy no se crea OIDC Provider para IRSA por restricciones de permisos. Los componentes se despliegan utilizando el rol disponible del laboratorio cuando corresponde.
- En un entorno productivo, el acceso SSH al Bastion debería limitarse a IPs administrativas específicas.
- En un entorno productivo, podría evaluarse el uso de VPC Endpoints para ECR, S3, STS y otros servicios de AWS utilizados por los nodos privados.
