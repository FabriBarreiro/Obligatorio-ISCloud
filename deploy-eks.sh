#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-obligatorio-iscloud}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
CLUSTER_NAME="${CLUSTER_NAME:-${PROJECT_NAME}-${ENVIRONMENT}-eks}"

echo "=== Validando herramientas ==="

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: AWS CLI no está instalado."
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: Docker no está instalado."
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "ERROR: kubectl no está instalado."
  exit 1
}

docker info >/dev/null 2>&1 || {
  echo "ERROR: Docker no está ejecutándose."
  exit 1
}

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERROR: Credenciales AWS inválidas o vencidas."
  exit 1
}

echo "OK: herramientas disponibles."
echo

echo "=== Configuración ==="
echo "AWS Region: $AWS_REGION"
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Cluster: $CLUSTER_NAME"
echo

echo "=== 1. Build y push de imágenes a ECR ==="
./docker/build-and-push.sh

echo
echo "=== 2. Generando manifiestos Kubernetes ==="
./k8s/generate-manifests.sh

echo
echo "=== 3. Configurando kubeconfig ==="
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo
echo "=== 4. Verificando nodos del clúster ==="
kubectl get nodes

echo
echo "=== Validando Metrics Server ==="

if ! kubectl top nodes >/dev/null 2>&1; then
  echo "ERROR: Metrics Server no está operativo."
  echo "Ejecutá primero: ./eks-setup.sh"
  exit 1
fi

echo "OK: Metrics Server operativo."

echo
echo "=== 5. Aplicando manifiestos en EKS ==="
kubectl apply -f k8s/generated/

echo
echo "=== Aplicando HPA ==="

if [ -d "k8s/hpa" ] && ls k8s/hpa/*.yaml >/dev/null 2>&1; then
  kubectl apply -f k8s/hpa/
else
  echo "ERROR: No se encontraron manifiestos HPA en k8s/hpa/"
  exit 1
fi

echo "Validando HPA..."
kubectl get hpa

echo
echo "=== 6. Esperando deployments ==="
for deployment in $(kubectl get deployments -o jsonpath='{.items[*].metadata.name}'); do
  echo "Esperando deployment/$deployment..."
  kubectl rollout status "deployment/$deployment" --timeout=180s
done

echo
echo "=== 7. Estado de pods ==="
kubectl get pods

echo
echo "=== 8. Servicios ==="
kubectl get svc

echo
echo "=== HPA ==="
kubectl get hpa

echo
echo "=== Métricas ==="
kubectl top nodes
kubectl top pods

echo
echo "=== 9. URL pública del frontend ==="

FRONTEND_URL=""

for i in {1..30}; do
  FRONTEND_URL=$(kubectl get ingress frontend-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  if [ -n "$FRONTEND_URL" ]; then
    echo "URL pública del frontend:"
    echo "http://$FRONTEND_URL"
    exit 0
  fi

  echo "Esperando DNS del ALB... intento $i/30"
  sleep 20
done

echo "El LoadBalancer todavía no tiene DNS asignado."
echo "Verificá con:"
echo "kubectl get ingress frontend-alb"
echo "kubectl describe ingress frontend-alb"
exit 1