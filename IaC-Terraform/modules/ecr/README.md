
# Módulo ECR

Este módulo crea los repositorios de **Amazon Elastic Container Registry (ECR)** utilizados para almacenar las imágenes Docker de los microservicios de la aplicación.

A diferencia de un diseño con un único repositorio y múltiples tags, este módulo crea **un repositorio ECR por microservicio**. Esto permite separar las imágenes por servicio, simplificar la publicación desde los scripts de build/deploy y mantener una organización más clara dentro de AWS.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `aws_ecr_repository.repositories` | Crea múltiples repositorios ECR a partir de la variable `repositories` |

El recurso utiliza `for_each` sobre la lista de repositorios:

```hcl
for_each = toset(var.repositories)
```

El nombre final de cada repositorio se construye con el siguiente formato:

```text
<project_name>-<environment>-<repository>
```

Ejemplo:

```text
obligatorio-iscloud-prod-frontend
```

## Configuración del repositorio

Cada repositorio ECR se crea con la siguiente configuración:

```hcl
image_tag_mutability = "MUTABLE"
```

Esto permite reutilizar tags como `latest`, lo cual simplifica el flujo de despliegue del laboratorio.

También se habilita el escaneo automático de imágenes al momento del push:

```hcl
image_scanning_configuration {
  scan_on_push = true
}
```

De esta forma, ECR analiza las imágenes publicadas para detectar vulnerabilidades conocidas.

## Repositorios esperados

En el ambiente `prod`, la variable `repositories` contiene los nombres de los microservicios que serán publicados en ECR.

Ejemplos de repositorios creados:

| Servicio | Repositorio ECR |
|---|---|
| frontend | `obligatorio-iscloud-prod-frontend` |
| cartservice | `obligatorio-iscloud-prod-cartservice` |
| checkoutservice | `obligatorio-iscloud-prod-checkoutservice` |
| currencyservice | `obligatorio-iscloud-prod-currencyservice` |
| emailservice | `obligatorio-iscloud-prod-emailservice` |
| paymentservice | `obligatorio-iscloud-prod-paymentservice` |
| productcatalogservice | `obligatorio-iscloud-prod-productcatalogservice` |
| recommendationservice | `obligatorio-iscloud-prod-recommendationservice` |
| shippingservice | `obligatorio-iscloud-prod-shippingservice` |
| adservice | `obligatorio-iscloud-prod-adservice` |
| loadgenerator | `obligatorio-iscloud-prod-loadgenerator` |

## Relación con Docker build

Los repositorios creados por este módulo son utilizados por el script:

```bash
./docker/build-and-push.sh
```

El script construye cada microservicio y publica la imagen correspondiente en ECR con el tag `latest`.

El nombre del repositorio utilizado por el script sigue el mismo formato definido por Terraform:

```text
${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE_NAME}
```

Por ejemplo:

```text
466395927784.dkr.ecr.us-east-1.amazonaws.com/obligatorio-iscloud-prod-frontend:latest
```

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar los repositorios ECR |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `repositories` | `list(string)` | Lista de repositorios ECR a crear |

## Outputs

| Output | Descripción |
|---|---|
| `repository_names` | Mapa con los nombres de los repositorios creados |
| `repository_urls` | Mapa con las URLs de los repositorios creados |
| `repository_arns` | Mapa con los ARNs de los repositorios creados |

Ejemplo de output `repository_urls`:

```text
frontend = 466395927784.dkr.ecr.us-east-1.amazonaws.com/obligatorio-iscloud-prod-frontend
cartservice = 466395927784.dkr.ecr.us-east-1.amazonaws.com/obligatorio-iscloud-prod-cartservice
```

## Ejemplo de uso

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  repositories = var.repositories
}
```

## Consideraciones

- Se crea un repositorio ECR por microservicio.
- Los repositorios usan tags mutables para permitir el uso de `latest` durante el flujo de laboratorio.
- El escaneo de imágenes al hacer push queda habilitado con `scan_on_push = true`.
- Las imágenes son construidas y publicadas por `docker/build-and-push.sh`.
- El script de build utiliza `docker buildx` y publica imágenes para `linux/amd64`, compatible con los worker nodes EKS `t3.medium`.
- En un entorno productivo se recomienda utilizar tags inmutables asociados a versión, commit o release, en lugar de depender únicamente de `latest`.
- En un entorno productivo también podría configurarse una política de lifecycle para limpiar imágenes antiguas automáticamente.
