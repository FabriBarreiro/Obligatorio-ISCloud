# Docker - Build y Push de Microservicios

Esta sección contiene el script utilizado para construir las imágenes Docker de los microservicios de la aplicación y publicarlas en Amazon ECR.

El objetivo es dejar todas las imágenes disponibles en los repositorios ECR creados por Terraform, para luego ser consumidas desde los manifiestos de Kubernetes desplegados en EKS.

## Prerrequisitos

Antes de ejecutar el build y push se requiere tener instalado y configurado:

- AWS CLI con credenciales válidas del laboratorio.
- Docker o Colima/Docker Desktop en ejecución.
- Terraform aplicado, con los repositorios ECR ya creados.
- Permisos para autenticarse contra Amazon ECR.
- Acceso al directorio raíz del proyecto.

En Mac con Colima, validar que el daemon esté iniciado:

```bash
colima start
```

Luego comprobar que Docker responda correctamente:

```bash
docker ps
docker info
```

Si Docker no está iniciado, el script fallará con un error similar a:

```text
failed to connect to the docker API at unix:///var/run/docker.sock
```

## Arquitectura de las imágenes

Como los nodos de EKS utilizan instancias `t3.medium`, la arquitectura esperada es `linux/amd64`.

El script utiliza `docker buildx build` con la variable `TARGET_PLATFORM`, cuyo valor por defecto es:

```bash
TARGET_PLATFORM=linux/amd64
```

Esto permite construir y publicar imágenes compatibles con los worker nodes de EKS aunque el build se ejecute desde una Mac con Apple Silicon.

El script no realiza un `docker build` local tradicional seguido de `docker push`, sino que utiliza:

```bash
docker buildx build \
  --platform "$TARGET_PLATFORM" \
  --push \
  -t "$IMAGE_URI" \
  "$APP_DIR/$SERVICE_PATH"
```

De esta forma, cada imagen se construye para la plataforma definida y se publica directamente en Amazon ECR.

## Ejecución del script

Desde la raíz del proyecto ejecutar:

```bash
./docker/build-and-push.sh
```

Por defecto el script construye para `linux/amd64`. Si fuera necesario cambiar la plataforma destino, se puede sobrescribir la variable `TARGET_PLATFORM`:

```bash
TARGET_PLATFORM=linux/amd64 ./docker/build-and-push.sh
```

El script realiza las siguientes acciones:

1. Define valores por defecto para `AWS_REGION`, `PROJECT_NAME`, `ENVIRONMENT` y `TARGET_PLATFORM`.
2. Obtiene el Account ID de AWS mediante `aws sts get-caller-identity`.
3. Construye la URL del registry ECR.
4. Valida que `docker buildx` esté disponible.
5. Crea o reutiliza el builder `obligatorio-iscloud-builder`.
6. Realiza login contra Amazon ECR.
7. Recorre la lista de microservicios definidos en el script.
8. Construye cada imagen con `docker buildx build --platform "$TARGET_PLATFORM" --push`.
9. Publica cada imagen directamente en el repositorio ECR correspondiente con el tag `latest`.
10. Informa qué servicios fueron subidos correctamente y cuáles fallaron.

### Variables utilizadas por el script

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Región AWS donde se encuentran los repositorios ECR |
| `PROJECT_NAME` | `obligatorio-iscloud` | Nombre base del proyecto utilizado para formar el nombre de los repositorios |
| `ENVIRONMENT` | `prod` | Ambiente utilizado para formar el nombre de los repositorios |
| `TARGET_PLATFORM` | `linux/amd64` | Plataforma destino utilizada por Docker Buildx |

El nombre final de cada repositorio se construye con el formato:

```text
<PROJECT_NAME>-<ENVIRONMENT>-<SERVICE_NAME>
```

Ejemplo:

```text
obligatorio-iscloud-prod-frontend
```

## Servicios construidos

El proceso contempla los siguientes microservicios:

| Servicio | Ruta relativa dentro de `src` | Repositorio ECR esperado |
|---|---|---|
| frontend | `frontend` | obligatorio-iscloud-prod-frontend |
| cartservice | `cartservice/src` | obligatorio-iscloud-prod-cartservice |
| checkoutservice | `checkoutservice` | obligatorio-iscloud-prod-checkoutservice |
| currencyservice | `currencyservice` | obligatorio-iscloud-prod-currencyservice |
| emailservice | `emailservice` | obligatorio-iscloud-prod-emailservice |
| paymentservice | `paymentservice` | obligatorio-iscloud-prod-paymentservice |
| productcatalogservice | `productcatalogservice` | obligatorio-iscloud-prod-productcatalogservice |
| recommendationservice | `recommendationservice` | obligatorio-iscloud-prod-recommendationservice |
| shippingservice | `shippingservice` | obligatorio-iscloud-prod-shippingservice |
| adservice | `adservice` | obligatorio-iscloud-prod-adservice |
| loadgenerator | `loadgenerator` | obligatorio-iscloud-prod-loadgenerator |

Cada imagen se publica con el tag:

```text
latest
```

Ejemplo de imagen final:

```text
466395927784.dkr.ecr.us-east-1.amazonaws.com/obligatorio-iscloud-prod-frontend:latest
```

## Login en Amazon ECR

El script realiza el login usando AWS CLI y Docker:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

Si el login fue correcto, se muestra:

```text
Login Succeeded
```

El warning de Docker sobre credenciales sin cifrar en `~/.docker/config.json` no impide el funcionamiento del script.

## Errores comunes

### Docker daemon no iniciado

Error:

```text
failed to connect to the docker API at unix:///var/run/docker.sock
```

Solución:

```bash
colima start
```

Validar:

```bash
docker ps
```

### Problemas por arquitectura ARM/AMD64

En Mac con Apple Silicon, construir imágenes sin especificar plataforma puede generar imágenes ARM que luego no ejecutan correctamente en los nodos EKS `t3.medium`, ya que estos utilizan arquitectura `amd64`.

El script evita este problema utilizando Docker Buildx con:

```bash
TARGET_PLATFORM=linux/amd64
```

y ejecutando:

```bash
docker buildx build --platform "$TARGET_PLATFORM" --push
```

Para validar que Buildx esté disponible:

```bash
docker buildx version
```

El script crea o reutiliza automáticamente el builder:

```text
obligatorio-iscloud-builder
```

Si se desea recrear el builder manualmente:

```bash
docker buildx rm obligatorio-iscloud-builder
./docker/build-and-push.sh
```

### Falla en recommendationservice

Si `recommendationservice` falla durante `pip install`, puede deberse a dependencias antiguas no disponibles para la arquitectura usada en el build.

Ejemplo:

```text
ERROR: Could not find a version that satisfies the requirement google-python-cloud-debugger==2.18
```

Primero validar que el script esté construyendo para `linux/amd64`:

```bash
TARGET_PLATFORM=linux/amd64 ./docker/build-and-push.sh
```

Si el error persiste, revisar el archivo:

```text
aplicativo/Obligatorio-Microservicios-main/src/recommendationservice/requirements.txt
```

La dependencia `google-python-cloud-debugger` corresponde a herramientas de debug/profiling de Google Cloud y no es necesaria para el funcionamiento base de la aplicación en AWS.

## Validación en ECR

Para verificar que las imágenes fueron publicadas correctamente:

```bash
aws ecr describe-repositories --region us-east-1
```

Para listar imágenes de un repositorio específico:

```bash
aws ecr list-images \
  --repository-name obligatorio-iscloud-prod-frontend \
  --region us-east-1
```

También puede validarse desde la consola AWS:

```text
Amazon ECR → Repositories → seleccionar repositorio → Images
```

## Resultado esperado

Al finalizar correctamente, cada servicio debería mostrar un mensaje similar a:

```text
OK: frontend subido correctamente.
```

Si algún servicio falla, el script lo guarda en el arreglo `FAILED`, lo informa al final y termina con código de error:
