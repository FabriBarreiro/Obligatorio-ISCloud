

# Módulo ECR

Este módulo crea un repositorio Amazon ECR para almacenar las imágenes Docker de los microservicios de la aplicación.

Para mantener la arquitectura simple, se utiliza un único repositorio ECR. Cada microservicio se identifica mediante un tag diferente dentro del mismo repositorio.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_ecr_repository.app_repository` | Repositorio ECR para las imágenes Docker de la aplicación |

## Estrategia de imágenes

El repositorio se crea con el siguiente formato de nombre:

```text
<project_name>-<environment>-app
```

Ejemplo:

```text
obligatorio-iscloud-prod-app
```

Cada microservicio se sube al mismo repositorio utilizando un tag distinto:

```text
frontend
cartservice
checkoutservice
productcatalogservice
currencyservice
paymentservice
shippingservice
emailservice
recommendationservice
adservice
```

Ejemplo de imagen publicada:

```text
<account_id>.dkr.ecr.us-east-1.amazonaws.com/obligatorio-iscloud-prod-app:frontend
```

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar el repositorio ECR |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |

## Outputs

| Output | Descripción |
|---|---|
| `repository_name` | Nombre del repositorio ECR creado |
| `repository_url` | URL del repositorio ECR creado |
| `repository_arn` | ARN del repositorio ECR creado |

## Ejemplo de uso

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project_name = "obligatorio-iscloud"
  environment  = "prod"
}
```

## Consideraciones

- Se utiliza un único repositorio ECR para simplificar la administración en el entorno AWS Academy.
- Las imágenes de los microservicios se diferencian mediante tags.
- Se habilita escaneo de imágenes al hacer push mediante `scan_on_push = true`.
- Los tags son mutables para facilitar el ciclo de desarrollo y despliegue durante el laboratorio.
- En un entorno productivo, podría evaluarse el uso de tags inmutables o un repositorio separado por microservicio.
