

# Módulo Internet Gateway

Este módulo crea el Internet Gateway asociado a la VPC principal.

El Internet Gateway permite que los recursos ubicados en subnets públicas puedan tener conectividad con Internet, siempre que exista una tabla de rutas que envíe el tráfico `0.0.0.0/0` hacia este recurso.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_internet_gateway.internet_gateway` | Internet Gateway asociado a la VPC |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar el Internet Gateway |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `vpc_id` | `string` | ID de la VPC donde se asociará el Internet Gateway |

## Outputs

| Output | Descripción |
|---|---|
| `internet_gateway_id` | ID del Internet Gateway creado |

## Ejemplo de uso

```hcl
module "igw" {
  source = "../../modules/igw"

  project_name = "obligatorio-iscloud"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
}
```

## Consideraciones

- Este módulo solo crea y asocia el Internet Gateway a la VPC.
- Las rutas hacia Internet se gestionan en el módulo `route-tables`.
- Las subnets públicas utilizarán este Internet Gateway para permitir conectividad hacia y desde Internet.
- Recursos como el Bastion Host o Load Balancers públicos deberán ubicarse en subnets públicas con una ruta hacia este Internet Gateway.
