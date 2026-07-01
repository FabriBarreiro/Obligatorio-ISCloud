#!/bin/bash
set -euo pipefail

NS="${NS:-default}"
INGRESS_NAME="${INGRESS_NAME:-frontend}"
URL="${URL:-}"
POD_NAME="${POD_NAME:-frontend-request-test}"
CONNECTIONS="${CONNECTIONS:-200}"
DURATION="${DURATION:-5m}"
QPS="${QPS:-0}"
TIMEOUT="${TIMEOUT:-10s}"
ALLOW_INITIAL_ERRORS="${ALLOW_INITIAL_ERRORS:-true}"

print_section() {
  echo ""
  echo "======================================"
  echo "$1"
  echo "======================================"
}

resolve_frontend_url() {
  local ingress_host=""

  if [[ -n "${URL}" ]]; then
    echo "${URL}"
    return 0
  fi

  ingress_host="$(kubectl get ingress "${INGRESS_NAME}" -n "${NS}" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"

  if [[ -z "${ingress_host}" ]]; then
    ingress_host="$(kubectl get ingress "${INGRESS_NAME}" -n "${NS}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  fi

  if [[ -z "${ingress_host}" ]]; then
    ingress_host="$(kubectl get ingress -n "${NS}" -o jsonpath='{range .items[?(@.metadata.name=="frontend")]}{.status.loadBalancer.ingress[0].hostname}{end}' 2>/dev/null || true)"
  fi

  if [[ -z "${ingress_host}" ]]; then
    ingress_host="$(kubectl get ingress -n "${NS}" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}' 2>/dev/null | awk '/frontend/ {print $2; exit}' || true)"
  fi

  if [[ -z "${ingress_host}" ]]; then
    echo "ERROR: no se pudo resolver la URL del frontend desde el Ingress ${NS}/${INGRESS_NAME}." >&2
    echo "Validar con: kubectl get ingress -n ${NS}" >&2
    echo "Tambien podes pasarla manualmente con: URL=http://<alb-dns> ./frontend-request-test.sh" >&2
    exit 1
  fi

  echo "http://${ingress_host}"
}

print_state() {
  local title="$1"

  print_section "${title}"

  echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  echo "----- HPA -----"
  kubectl get hpa -n "${NS}" || true
  echo ""

  echo "----- Frontend pods -----"
  kubectl get pods -n "${NS}" -o wide | grep -E "frontend|${POD_NAME}" || true
  echo ""

  echo "----- Consumo pods relevantes -----"
  kubectl top pods -n "${NS}" 2>/dev/null | grep -E "frontend|cartservice|checkoutservice|recommendationservice|adservice|paymentservice" || true
  echo ""

  echo "----- Consumo nodos -----"
  kubectl top nodes 2>/dev/null || true
  echo ""

  echo "----- Pods Pending -----"
  kubectl get pods -A --field-selector=status.phase=Pending -o wide || true
}

URL="$(resolve_frontend_url)"

print_section "Frontend Request Test"
echo "Namespace: ${NS}"
echo "Ingress: ${INGRESS_NAME}"
echo "URL resuelta: ${URL}"
echo "Pod: ${POD_NAME}"
echo "Conexiones concurrentes: ${CONNECTIONS}"
echo "Duración: ${DURATION}"
echo "QPS: ${QPS} (0 = sin límite)"
echo "Timeout por request: ${TIMEOUT}"
echo "Permitir errores iniciales: ${ALLOW_INITIAL_ERRORS}"

echo ""
echo "Limpiando pod anterior si existe..."
kubectl delete pod "${POD_NAME}" \
  -n "${NS}" \
  --ignore-not-found=true \
  --force \
  --grace-period=0 >/dev/null 2>&1 || true

print_state "Estado inicial"

print_section "Ejecutando prueba"
echo "Iniciando Fortio contra el frontend..."
echo ""

FORTIO_ARGS=(load -t "${DURATION}" -c "${CONNECTIONS}" -qps "${QPS}" -timeout "${TIMEOUT}")

if [[ "${ALLOW_INITIAL_ERRORS}" == "true" ]]; then
  FORTIO_ARGS+=( -allow-initial-errors )
fi

FORTIO_ARGS+=( "${URL}" )

kubectl run "${POD_NAME}" \
  -n "${NS}" \
  --rm -i --tty \
  --image=fortio/fortio \
  --restart=Never \
  -- "${FORTIO_ARGS[@]}"

print_state "Estado final"

print_section "Prueba finalizada"
