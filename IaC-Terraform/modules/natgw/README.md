# Módulo NAT Gateway

Este módulo crea un NAT Gateway en una subnet pública.

El NAT Gateway permite que los recursos ubicados en subnets privadas puedan iniciar conexiones hacia Internet sin quedar expuestos directamente desde Internet. En esta arquitectura será utilizado principalmente por los worker nodes de EKS ubicados en subnets privadas.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_eip.nat_gateway_eip` | Elastic IP pública asociada al NAT Gateway |
| `aws_nat_gateway.nat_gateway` | NAT Gateway desplegado en una subnet pública |

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar el NAT Gateway |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `public_subnet_id` | `string` | ID de la subnet pública donde se creará el NAT Gateway |

## Outputs

| Output | Descripción |
|---|---|
| `nat_gateway_id` | ID del NAT Gateway creado |
| `nat_gateway_public_ip` | IP pública asociada al NAT Gateway |

## Ejemplo de uso

```hcl
module "natgw" {
  source = "../../modules/natgw"

  project_name     = "obligatorio-iscloud"
  environment      = "prod"
  public_subnet_id = module.subnets.public_subnet_ids[0]
}
```

## Consideraciones

- El módulo crea un único NAT Gateway para mantener la arquitectura simple y reducir costos en el entorno AWS Academy.
- El NAT Gateway se despliega en una subnet pública.
- El NAT Gateway requiere una Elastic IP pública para funcionar.
- Las subnets privadas utilizarán este NAT Gateway mediante una ruta `0.0.0.0/0` configurada en el módulo `route-tables`.
- Los recursos privados no reciben tráfico entrante desde Internet a través del NAT Gateway; solo pueden iniciar conexiones salientes.
- En un entorno productivo, podría evaluarse un NAT Gateway por zona de disponibilidad para mejorar la tolerancia a fallas.
