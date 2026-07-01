# Despliegue de la solución

## Descripción

El despliegue de la solución se encuentra completamente automatizado mediante Terraform y dos scripts principales:

- `eks-setup.sh`: prepara el clúster Amazon EKS instalando todos los componentes necesarios para su funcionamiento.
- `deploy-eks.sh`: despliega la aplicación de microservicios sobre el clúster previamente configurado.

El proceso completo permite crear la infraestructura, configurar Kubernetes y publicar la aplicación con una mínima intervención manual.

---

# Requisitos

Antes de comenzar es necesario contar con las siguientes herramientas instaladas:

- AWS CLI v2
- Terraform
- Docker
- kubectl
- Helm
- Git
- Bash

Además, el usuario debe tener configuradas sus credenciales de AWS con permisos suficientes para crear los recursos de la infraestructura.

---

# Paso 1 - Crear la infraestructura

La infraestructura se crea utilizando Terraform.

```bash
cd IaC-Terraform/environments/prod

terraform init

terraform plan

terraform apply
```

Al finalizar este paso estarán disponibles los recursos principales de AWS, incluyendo la VPC, el clúster Amazon EKS, Amazon ECR, Amazon ElastiCache y el resto de la infraestructura necesaria.

Dentro de este paso también queda configurado el add-on de Amazon VPC CNI con **prefix delegation**, lo que permite mejorar la asignación de direcciones IP para los pods desde el momento en que se crea el clúster y antes de aprovisionar el node group.

---

# Paso 2 - Configurar el clúster EKS

Una vez creada la infraestructura se debe ejecutar el script:

```bash
./eks-setup.sh
```

Este script automatiza la configuración inicial del clúster Kubernetes.

Entre las principales tareas realizadas se encuentran:

- Configuración del acceso al clúster mediante `kubeconfig`.
- Validación de herramientas y credenciales de AWS.
- Instalación del Amazon EBS CSI Driver.
- Validación de la disponibilidad del VPC CNI previamente configurado por Terraform.
- Creación de la StorageClass utilizada por los volúmenes persistentes.
- Instalación de Metrics Server.
- Instalación del AWS Load Balancer Controller.
- Instalación del Cluster Autoscaler.
- Instalación del stack de monitoreo mediante Prometheus, Grafana, Alertmanager, kube-state-metrics y node-exporter utilizando Helm.
- Verificación del estado de todos los componentes instalados.
- Obtención de la URL y credenciales iniciales de Grafana.

Este procedimiento debe ejecutarse una única vez luego de crear el clúster.

---

# Paso 3 - Desplegar la aplicación

Una vez configurado el clúster se ejecuta:

```bash
./deploy-eks.sh
```

Este script automatiza completamente el despliegue de la aplicación.

Las tareas realizadas son:

1. Validar las herramientas necesarias.
2. Construir las imágenes Docker de los microservicios.
3. Publicar las imágenes en Amazon ECR.
4. Generar los manifiestos Kubernetes.
5. Configurar el acceso al clúster.
6. Verificar el estado del clúster.
7. Aplicar los manifiestos Kubernetes.
8. Desplegar los Horizontal Pod Autoscaler (HPA).
9. Esperar a que todos los Deployments estén disponibles.
10. Verificar el estado de los pods y servicios.
11. Esperar la creación del Application Load Balancer.
12. Mostrar la URL pública del frontend.

El frontend se publica mediante un Ingress de Kubernetes procesado por AWS Load Balancer Controller. Este componente crea un Application Load Balancer público en AWS y lo asocia al Service `frontend-external`, expuesto como NodePort, para dirigir el tráfico hacia los pods del frontend.

---

# Acceso a la aplicación

Al finalizar el despliegue, el script `deploy-eks.sh` espera a que el **Application Load Balancer** sea creado por AWS y muestra automáticamente la URL pública desde la cual es posible acceder al frontend de la aplicación.

Asimismo, durante la ejecución de `eks-setup.sh` se informa la URL de acceso a **Grafana**, junto con las credenciales iniciales para acceder al panel de monitoreo.

---

# Validaciones posteriores al despliegue

Luego de ejecutar el despliegue completo se recomienda validar el estado general de la solución con los siguientes comandos:

```bash
kubectl get nodes
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get hpa
kubectl get targetgroupbindings -A
```

Para verificar que el frontend quedó publicado correctamente por el Application Load Balancer:

```bash
FRONTEND_URL="http://$(kubectl get ingress frontend-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "$FRONTEND_URL"
curl -I "$FRONTEND_URL"
```

Para validar que el VPC CNI quedó configurado con prefix delegation:

```bash
kubectl -n kube-system get daemonset aws-node -o yaml | grep -A3 ENABLE_PREFIX_DELEGATION
```

El valor esperado es `true`.

También se puede validar el estado del add-on desde AWS CLI:

```bash
aws eks describe-addon \
  --cluster-name obligatorio-iscloud-prod-eks \
  --addon-name vpc-cni \
  --region us-east-1 \
  --query 'addon.configurationValues' \
  --output text
```

---

# Automatización

Gracias a la utilización de Terraform, Kubernetes y scripts Bash, el despliegue completo de la solución puede realizarse siguiendo únicamente estos pasos:

```bash
terraform apply

./eks-setup.sh

./deploy-eks.sh
```

De esta forma, toda la infraestructura, la configuración del clúster y el despliegue de la aplicación quedan completamente automatizados y pueden reproducirse de manera consistente en un nuevo entorno.
