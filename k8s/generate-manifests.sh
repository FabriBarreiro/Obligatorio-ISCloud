#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-obligatorio-iscloud}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

SRC_DIR="aplicativo/Obligatorio-Microservicios-main/src"
OUT_DIR="k8s/generated"
TERRAFORM_DIR="IaC-Terraform/environments/prod"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

REDIS_ADDR=$(terraform -chdir="$TERRAFORM_DIR" output -raw redis_connection_string 2>/dev/null || true)

if [ -z "$REDIS_ADDR" ]; then
  echo "ERROR: No se pudo obtener redis_connection_string desde Terraform."
  echo "Verificá que terraform apply haya finalizado correctamente."
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.yaml

echo "Generando manifiestos Kubernetes..."
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Registry: $REGISTRY"
echo "Redis: $REDIS_ADDR"
echo

find "$SRC_DIR" -mindepth 2 -maxdepth 3 -path "*/deployment/kubernetes-manifests.yaml" | sort | while read -r SRC_FILE; do
  SERVICE="$(basename "$(dirname "$(dirname "$SRC_FILE")")")"

  if [ "$SERVICE" = "redis" ]; then
    continue
  fi

  OUT_FILE="${OUT_DIR}/${SERVICE}.yaml"
  IMAGE="${REGISTRY}/${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}:latest"

  echo "Generando $OUT_FILE"

  sed \
    -e "s|<IMAGE:TAG>|${IMAGE}|g" \
    -e "s|<REDIS_ADDR>|${REDIS_ADDR}|g" \
    "$SRC_FILE" > "$OUT_FILE"

  echo
done

echo "Manifiestos generados correctamente en $OUT_DIR"
echo
echo "Verificar imágenes con:"
echo "grep -R \"image:\\|REDIS_ADDR\" -n $OUT_DIR"
echo
echo "Aplicar en Kubernetes con:"
echo "kubectl apply -f $OUT_DIR/"