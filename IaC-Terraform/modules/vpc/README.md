

# Módulo VPC

Este módulo crea la VPC principal utilizada por la solución en AWS.

La VPC es la red base sobre la cual se despliegan los demás componentes de infraestructura, como subredes públicas, subredes privadas, Internet Gateway, NAT Gateway, tablas de rutas, Security Groups, ECR y EKS.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_vpc.main_vpc` | VPC principal del proyecto |

## Variables

| Variable | Tipo | Default | Descripción |
|---|---|---|---|
| `project_name` | `string` | n/a | Nombre del proyecto utilizado para nombrar los recursos |
| `environment` | `string` | n/a | Ambiente donde se despliega la infraestructura |
| `vpc_cidr_block` | `string` | n/a | Bloque CIDR principal de la VPC |
| `enable_dns_support` | `bool` | `true` | Habilita soporte DNS dentro de la VPC |
| `enable_dns_hostnames` | `bool` | `true` | Habilita nombres DNS para recursos dentro de la VPC |

## Outputs

| Output | Descripción |
|---|---|
| `vpc_id` | ID de la VPC principal creada |
| `vpc_arn` | ARN de la VPC principal creada |
| `vpc_cidr_block` | Bloque CIDR asignado a la VPC principal |

## Ejemplo de uso

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name   = "obligatorio-iscloud"
  environment    = "prod"
  vpc_cidr_block = "10.0.0.0/16"
}
```

## Consideraciones

- Se habilita DNS support para permitir resolución DNS dentro de la VPC.
- Se habilitan DNS hostnames para facilitar la integración con servicios administrados como Amazon EKS.
- Este módulo solamente crea la VPC. Las subredes, rutas, gateways y reglas de firewall se gestionan en módulos separados para mantener una estructura simple y segmentada.
