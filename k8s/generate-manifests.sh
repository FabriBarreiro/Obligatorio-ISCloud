#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-obligatorio-iscloud}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

SRC_DIR="aplicativo/Obligatorio-Microservicios-main/src"
OUT_DIR="k8s/generated"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

mkdir -p "$OUT_DIR"

echo "Generando manifiestos Kubernetes..."
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Registry: $REGISTRY"
echo

find "$SRC_DIR" -mindepth 2 -maxdepth 3 -path "*/deployment/kubernetes-manifests.yaml" | sort | while read -r SRC_FILE; do
  SERVICE="$(basename "$(dirname "$(dirname "$SRC_FILE")")")"
  OUT_FILE="${OUT_DIR}/${SERVICE}.yaml"
  IMAGE="${REGISTRY}/${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE}:latest"

  echo "Generando $OUT_FILE"

  if grep -q "<IMAGE:TAG>" "$SRC_FILE"; then
    echo "Imagen ECR: $IMAGE"
    sed "s|<IMAGE:TAG>|${IMAGE}|g" "$SRC_FILE" > "$OUT_FILE"
  else
    echo "Sin placeholder <IMAGE:TAG>. Se copia sin cambios."
    cp "$SRC_FILE" "$OUT_FILE"
  fi

  echo
done

echo "Manifiestos generados correctamente en $OUT_DIR"
echo
echo "Verificar imágenes con:"
echo "grep -R \"image:\" -n $OUT_DIR"
echo
echo "Aplicar en Kubernetes con:"
echo "kubectl apply -f $OUT_DIR/"