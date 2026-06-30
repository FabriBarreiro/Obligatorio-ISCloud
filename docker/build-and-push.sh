#!/bin/bash
set -uo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-obligatorio-iscloud}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

APP_DIR="./aplicativo/Obligatorio-Microservicios-main/src"

SERVICES=(
  "frontend:frontend"
  "cartservice:cartservice/src"
  "checkoutservice:checkoutservice"
  "currencyservice:currencyservice"
  "emailservice:emailservice"
  "paymentservice:paymentservice"
  "productcatalogservice:productcatalogservice"
  "recommendationservice:recommendationservice"
  "shippingservice:shippingservice"
  "adservice:adservice"
  "loadgenerator:loadgenerator"
)

FAILED=()

echo "Login en ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

for item in "${SERVICES[@]}"; do
  SERVICE_NAME="${item%%:*}"
  SERVICE_PATH="${item#*:}"

  REPOSITORY_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${SERVICE_NAME}"
  IMAGE_URI="${ECR_REGISTRY}/${REPOSITORY_NAME}:latest"

  echo "======================================"
  echo "Construyendo $SERVICE_NAME"
  echo "Ruta: $APP_DIR/$SERVICE_PATH"
  echo "Imagen: $IMAGE_URI"
  echo "======================================"

  if docker build -t "$IMAGE_URI" "$APP_DIR/$SERVICE_PATH"; then
    if docker push "$IMAGE_URI"; then
      echo "OK: $SERVICE_NAME subido correctamente."
    else
      echo "ERROR: Falló el push de $SERVICE_NAME."
      FAILED+=("$SERVICE_NAME")
    fi
  else
    echo "ERROR: Falló el build de $SERVICE_NAME."
    FAILED+=("$SERVICE_NAME")
  fi
done

echo "======================================"

if [ ${#FAILED[@]} -eq 0 ]; then
  echo "Todas las imágenes fueron subidas a ECR correctamente."
else
  echo "Algunos servicios fallaron:"
  printf ' - %s\n' "${FAILED[@]}"
  exit 1
fi
