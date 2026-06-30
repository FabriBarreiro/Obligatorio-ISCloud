

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

Si el build se ejecuta desde una Mac con Apple Silicon, se recomienda forzar la arquitectura:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 ./docker/build-and-push.sh
```

Esto evita problemas de compatibilidad al construir imágenes desde una máquina ARM y ejecutarlas luego en nodos x86_64.

## Ejecución del script

Desde la raíz del proyecto ejecutar:

```bash
./docker/build-and-push.sh
```

En Mac con Apple Silicon se recomienda:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 ./docker/build-and-push.sh
```

El script realiza las siguientes acciones:

1. Obtiene la cuenta AWS y región configuradas.
2. Realiza login contra Amazon ECR.
3. Construye cada imagen Docker desde su directorio correspondiente.
4. Etiqueta la imagen con el repositorio ECR correspondiente.
5. Publica la imagen usando `docker push`.
6. Informa qué servicios fueron subidos correctamente y cuáles fallaron.

## Servicios construidos

El proceso contempla los siguientes microservicios:

| Servicio | Repositorio ECR esperado |
|---|---|
| frontend | obligatorio-iscloud-prod-frontend |
| cartservice | obligatorio-iscloud-prod-cartservice |
| checkoutservice | obligatorio-iscloud-prod-checkoutservice |
| currencyservice | obligatorio-iscloud-prod-currencyservice |
| emailservice | obligatorio-iscloud-prod-emailservice |
| paymentservice | obligatorio-iscloud-prod-paymentservice |
| productcatalogservice | obligatorio-iscloud-prod-productcatalogservice |
| recommendationservice | obligatorio-iscloud-prod-recommendationservice |
| shippingservice | obligatorio-iscloud-prod-shippingservice |
| adservice | obligatorio-iscloud-prod-adservice |
| loadgenerator | obligatorio-iscloud-prod-loadgenerator |

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

En Mac con Apple Silicon pueden aparecer warnings similares a:

```text
The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
```

Para construir imágenes compatibles con los nodos EKS `t3.medium`, se debe utilizar una VM Docker con arquitectura `x86_64` o un builder multi-arquitectura.

En Mac con Apple Silicon y Colima, el camino más simple para este proyecto es levantar Colima emulando `x86_64`:

```bash
colima stop
colima delete
colima start --arch x86_64 --cpu 4 --memory 8 --disk 60
```

Validar que Docker esté corriendo como `x86_64`:

```bash
docker info | grep -i architecture
```

El resultado esperado es:

```text
Architecture: x86_64
```

Luego ejecutar el build normalmente, sin forzar `DOCKER_DEFAULT_PLATFORM`:

```bash
./docker/build-and-push.sh
```

#### Fix de Colima x86_64 en Apple Silicon

Si al iniciar Colima con `--arch x86_64` aparece el error:

```text
qemu is required to emulate x86_64: qemu-img not found
```

instalar QEMU:

```bash
brew install qemu
```

Si luego aparece un error similar a:

```text
guest agent binary could not be found for Linux-x86_64
Hint: try installing `lima-additional-guestagents` package
```

instalar los guest agents adicionales de Lima:

```bash
brew install lima-additional-guestagents
```

Después limpiar el intento fallido y volver a iniciar Colima:

```bash
colima delete
colima start --arch x86_64 --cpu 4 --memory 8 --disk 60
```

Finalmente validar la arquitectura:

```bash
docker info | grep -i architecture
```

Si devuelve `Architecture: x86_64`, ya se puede ejecutar:

```bash
./docker/build-and-push.sh
```

### Falla en recommendationservice

Si `recommendationservice` falla durante `pip install`, puede deberse a dependencias antiguas no disponibles para la arquitectura usada en el build.

Ejemplo:

```text
ERROR: Could not find a version that satisfies the requirement google-python-cloud-debugger==2.18
```

Primero probar forzando arquitectura `linux/amd64`:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 ./docker/build-and-push.sh
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

Si algún servicio falla, el script lo informa al final:

```text
Algunos servicios fallaron:
 - recommendationservice
```

En ese caso, se debe revisar el error puntual del build de ese servicio y volver a ejecutar el script luego de corregirlo.
