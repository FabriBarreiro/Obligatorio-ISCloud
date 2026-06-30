

# Módulo Route Tables

Este módulo crea las tablas de rutas públicas y privadas de la VPC, junto con sus asociaciones a las subnets correspondientes.

La tabla de rutas pública permite que las subnets públicas tengan salida y entrada desde Internet mediante el Internet Gateway. La tabla de rutas privada permite que las subnets privadas tengan salida a Internet mediante el NAT Gateway, sin exponer directamente los recursos privados.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_route_table.public_route_table` | Tabla de rutas para subnets públicas |
| `aws_route_table.private_route_table` | Tabla de rutas para subnets privadas |
| `aws_route_table_association.public_subnet_associations` | Asociación de subnets públicas a la tabla pública |
| `aws_route_table_association.private_subnet_associations` | Asociación de subnets privadas a la tabla privada |

## Rutas configuradas

### Tabla pública

| Destino | Target | Descripción |
|---|---|---|
| `0.0.0.0/0` | Internet Gateway | Permite conectividad hacia y desde Internet para recursos en subnets públicas |

### Tabla privada

| Destino | Target | Descripción |
|---|---|---|
| `0.0.0.0/0` | NAT Gateway | Permite salida a Internet desde recursos en subnets privadas |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar las tablas de rutas |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `vpc_id` | `string` | ID de la VPC donde se crearán las tablas de rutas |
| `internet_gateway_id` | `string` | ID del Internet Gateway utilizado por la tabla de rutas pública |
| `nat_gateway_id` | `string` | ID del NAT Gateway utilizado por la tabla de rutas privada |
| `public_subnet_ids` | `list(string)` | IDs de las subnets públicas asociadas a la tabla pública |
| `private_subnet_ids` | `list(string)` | IDs de las subnets privadas asociadas a la tabla privada |

## Outputs

| Output | Descripción |
|---|---|
| `public_route_table_id` | ID de la tabla de rutas pública |
| `private_route_table_id` | ID de la tabla de rutas privada |

## Ejemplo de uso

```hcl
module "route_tables" {
  source = "../../modules/route-tables"

  project_name        = "obligatorio-iscloud"
  environment         = "prod"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.igw.internet_gateway_id
  nat_gateway_id      = module.natgw.nat_gateway_id
  public_subnet_ids   = module.subnets.public_subnet_ids
  private_subnet_ids  = module.subnets.private_subnet_ids
}
```

## Consideraciones

- Se crea una única tabla de rutas pública y una única tabla de rutas privada para mantener la arquitectura simple.
- Las subnets públicas utilizan el Internet Gateway para conectividad directa con Internet.
- Las subnets privadas utilizan el NAT Gateway para salida a Internet sin exposición directa.
- Los worker nodes de EKS se ubicarán en subnets privadas y usarán la ruta privada para acceder a servicios como ECR o APIs de AWS.
- El Bastion Host y los Load Balancers públicos deberán ubicarse en subnets públicas.
