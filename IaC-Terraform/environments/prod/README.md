# Environment Prod

Este directorio contiene la definición Terraform del ambiente `prod` para el obligatorio de Implementación de Soluciones Cloud.

Desde este environment se conectan todos los módulos de infraestructura necesarios para desplegar la arquitectura en AWS Academy.

## Módulos utilizados

| Módulo | Descripción |
|---|---|
| `vpc` | Crea la VPC principal del proyecto |
| `subnets` | Crea subnets públicas y privadas en dos zonas de disponibilidad |
| `igw` | Crea el Internet Gateway para la VPC |
| `natgw` | Crea el NAT Gateway para salida a Internet desde subnets privadas |
| `route-tables` | Crea y asocia tablas de rutas públicas y privadas |
| `security-groups` | Crea los Security Groups del Bastion, EKS y worker nodes |
| `ecr` | Crea el repositorio ECR para las imágenes Docker de la aplicación |
| `ec2` | Crea el Bastion Host para administración |
| `eks` | Crea el cluster EKS, node group y add-ons administrados |

## Arquitectura desplegada

La infraestructura queda distribuida de la siguiente forma:

```text
VPC 10.0.0.0/16

├── Public Subnet 1  10.0.1.0/24  us-east-1a
│   ├── Bastion Host
│   └── NAT Gateway
│
├── Public Subnet 2  10.0.2.0/24  us-east-1b
│
├── Private Subnet 1 10.0.3.0/24  us-east-1a
│   └── Worker nodes EKS
│
└── Private Subnet 2 10.0.4.0/24  us-east-1b
    └── Worker nodes EKS
```

## Conectividad

Las subnets públicas tienen salida directa a Internet mediante el Internet Gateway.

Las subnets privadas no tienen exposición directa a Internet. Su salida se realiza mediante el NAT Gateway ubicado en una subnet pública.

El Bastion Host se ubica en una subnet pública y se utiliza como punto de administración para recursos privados, especialmente el cluster EKS cuando el endpoint está configurado como privado.

## EKS

El cluster EKS se crea en subnets privadas y utiliza el rol `LabRole`, disponible en AWS Academy.

Los worker nodes se crean mediante un node group administrado y utilizan el Key Pair `vockey` para acceso SSH en caso de ser necesario.

Add-ons instalados por defecto:

```text
vpc-cni
coredns
kube-proxy
aws-ebs-csi-driver
```

## Exposición pública de la aplicación

La exposición pública de la aplicación se realizará desde Kubernetes mediante un `Service` de tipo `LoadBalancer`.

Con este enfoque, EKS solicita automáticamente a AWS la creación de un Load Balancer para publicar el servicio correspondiente, por ejemplo el frontend de la aplicación.

El flujo esperado es:

```text
Usuario en Internet
        ↓
Load Balancer creado por Kubernetes en AWS
        ↓
Service type LoadBalancer
        ↓
Pods del frontend en EKS
```

En este diseño, las subnets públicas se utilizan para ubicar el Load Balancer, mientras que los worker nodes y los pods de la aplicación permanecen en subnets privadas.

Las subnets públicas y privadas fueron etiquetadas para que Kubernetes pueda identificar dónde crear Load Balancers públicos o internos:

```text
Subnets públicas  → kubernetes.io/role/elb = 1
Subnets privadas  → kubernetes.io/role/internal-elb = 1
```

Para este obligatorio se utiliza `Service type LoadBalancer` por simplicidad y compatibilidad con AWS Academy. En un entorno productivo, podría evaluarse el uso de Ingress junto con AWS Load Balancer Controller.

## ECR

Se crea un único repositorio ECR para almacenar las imágenes Docker de los microservicios de la aplicación.

Las imágenes se diferencian mediante tags, por ejemplo:

```text
obligatorio-iscloud-prod-app:frontend
obligatorio-iscloud-prod-app:cartservice
obligatorio-iscloud-prod-app:checkoutservice
```

## Variables principales

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `project_name` | `obligatorio-iscloud` | Nombre base del proyecto |
| `environment` | `prod` | Ambiente desplegado |
| `cluster_name` | `obligatorio-iscloud-prod-eks` | Nombre del cluster EKS |
| `vpc_cidr_block` | `10.0.0.0/16` | CIDR principal de la VPC |
| `availability_zones` | `us-east-1a`, `us-east-1b` | Zonas de disponibilidad utilizadas |
| `public_subnet_cidr_blocks` | `10.0.1.0/24`, `10.0.2.0/24` | CIDR de subnets públicas |
| `private_subnet_cidr_blocks` | `10.0.3.0/24`, `10.0.4.0/24` | CIDR de subnets privadas |
| `key_name` | `vockey` | Key Pair de AWS Academy |
| `bastion_instance_type` | `t3.micro` | Tipo de instancia del Bastion Host |
| `node_instance_types` | `t3.medium` | Tipo de instancia de los worker nodes |
| `node_desired_size` | `2` | Cantidad deseada de worker nodes |
| `node_min_size` | `2` | Cantidad mínima de worker nodes |
| `node_max_size` | `4` | Cantidad máxima de worker nodes |

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
Subnets públicas y privadas
IP pública del Bastion Host
Endpoint del cluster EKS
URL del repositorio ECR
Nombre del node group
Add-ons instalados
```

## Consideraciones

- La región se define en `providers.tf` y queda configurada en `us-east-1`.
- Se utiliza `LabRole` porque AWS Academy limita la creación de roles IAM personalizados.
- El Key Pair utilizado es `vockey`, provisto por AWS Academy.
- El Bastion Host se usa para administrar recursos privados dentro de la VPC.
- Los worker nodes de EKS quedan en subnets privadas.
- El NAT Gateway permite que los recursos privados accedan a ECR, APIs de AWS e Internet sin recibir conexiones entrantes directas.
- La publicación pública de la aplicación se gestiona desde Kubernetes con un `Service` de tipo `LoadBalancer`.
- En un entorno productivo, el acceso SSH al Bastion debería limitarse a IPs administrativas específicas.
