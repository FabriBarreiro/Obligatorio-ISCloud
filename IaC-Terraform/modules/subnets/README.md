

# Módulo Subnets

Este módulo crea las subnets públicas y privadas de la VPC.

La solución utiliza dos subnets públicas y dos subnets privadas, distribuidas en dos zonas de disponibilidad de `us-east-1`. Esta separación permite ubicar los recursos expuestos a Internet en la capa pública y los nodos de EKS en la capa privada.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_subnet.public_subnets` | Subnets públicas de la VPC |
| `aws_subnet.private_subnets` | Subnets privadas de la VPC |

## Diseño

Las subnets públicas se utilizan para recursos que deben tener conectividad directa desde Internet, como el Load Balancer que expone el frontend de la aplicación.

Las subnets privadas se utilizan para ejecutar los nodos del cluster EKS. De esta forma, los workloads de Kubernetes no quedan expuestos directamente a Internet.

## Tags utilizados

| Tag | Uso |
|---|---|
| `Name` | Nombre visible del recurso en AWS |
| `kubernetes.io/role/elb` | Identifica subnets públicas que pueden ser usadas por Load Balancers públicos |
| `kubernetes.io/role/internal-elb` | Identifica subnets privadas que pueden ser usadas por Load Balancers internos |
| `kubernetes.io/cluster/<cluster_name>` | Asocia las subnets al cluster EKS |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar los recursos |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `cluster_name` | `string` | Nombre del cluster EKS utilizado para etiquetar las subnets |
| `vpc_id` | `string` | ID de la VPC donde se crearán las subnets |
| `availability_zones` | `list(string)` | Lista de zonas de disponibilidad donde se distribuirán las subnets |
| `public_subnet_cidr_blocks` | `list(string)` | Lista de bloques CIDR para las subnets públicas |
| `private_subnet_cidr_blocks` | `list(string)` | Lista de bloques CIDR para las subnets privadas |

## Outputs

| Output | Descripción |
|---|---|
| `public_subnet_ids` | IDs de las subnets públicas creadas |
| `private_subnet_ids` | IDs de las subnets privadas creadas |
| `public_subnet_cidr_blocks` | Bloques CIDR de las subnets públicas creadas |
| `private_subnet_cidr_blocks` | Bloques CIDR de las subnets privadas creadas |

## Ejemplo de uso

```hcl
module "subnets" {
  source = "../../modules/subnets"

  project_name = "obligatorio-iscloud"
  environment  = "prod"
  cluster_name = "obligatorio-eks"

  vpc_id = module.vpc.vpc_id

  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnet_cidr_blocks = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnet_cidr_blocks = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}
```

## Consideraciones

- El módulo solo crea subnets. Las rutas se gestionan en el módulo `route-tables`.
- Las subnets públicas tienen `map_public_ip_on_launch = true`.
- Las subnets privadas tienen `map_public_ip_on_launch = false`.
- Los tags de Kubernetes son necesarios para que EKS pueda identificar qué subnets usar para Load Balancers públicos o internos.
- En este proyecto se mantiene un diseño simple con dos subnets públicas y dos privadas para cubrir alta disponibilidad básica en dos zonas de disponibilidad.
