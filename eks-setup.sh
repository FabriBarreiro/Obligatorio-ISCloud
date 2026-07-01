#!/bin/bash
set -euo pipefail

# Ejecutar desde la raiz del proyecto o ajustar TF_DIR.
# Este script se ejecuta localmente, pero envia el setup de EKS al bastion usando SSM.
# El bastion debe tener asociado el Instance Profile del LabRole para poder ejecutar los pasos IAM/EKS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-${SCRIPT_DIR}}"
TF_DIR="${TF_DIR:-${REPO_ROOT}/IaC-Terraform/environments/prod}"
MONITORING_VALUES_FILE="${MONITORING_VALUES_FILE:-${REPO_ROOT}/k8s/monitoring/kube-prometheus-stack-values.yaml}"
METRICS_SERVER_DIR="${METRICS_SERVER_DIR:-${REPO_ROOT}/k8s/metrics-server}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: falta instalar '$1' localmente."
    exit 1
  fi
}

tf_output() {
  terraform -chdir="${TF_DIR}" output -raw "$1" 2>/dev/null || true
}

tf_output_first() {
  local value=""

  for output_name in "$@"; do
    value="$(tf_output "${output_name}")"

    if [[ -n "${value}" && "${value}" != "null" ]]; then
      echo "${value}"
      return 0
    fi
  done

  return 1
}

require_cmd aws
require_cmd terraform
require_cmd kubectl
require_cmd helm

if [[ ! -d "${TF_DIR}" ]]; then
  echo "ERROR: no existe el directorio Terraform: ${TF_DIR}"
  exit 1
fi

if [[ ! -f "${MONITORING_VALUES_FILE}" ]]; then
  echo "ERROR: no existe el archivo de values de monitoreo: ${MONITORING_VALUES_FILE}"
  exit 1
fi

if [[ ! -f "${METRICS_SERVER_DIR}/components.yaml" ]]; then
  echo "ERROR: No existe ${METRICS_SERVER_DIR}/components.yaml"
  exit 1
fi

CLUSTER_NAME="${CLUSTER_NAME:-$(tf_output_first eks_cluster_name cluster_name)}"
BASTION_INSTANCE_ID="${BASTION_INSTANCE_ID:-$(tf_output_first bastion_instance_id)}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --no-cli-pager --query Account --output text)"
LAB_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/LabRole"
LOCAL_CALLER_ARN="$(aws sts get-caller-identity --no-cli-pager --query Arn --output text)"

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "ERROR: no se pudo obtener el nombre del cluster desde Terraform."
  echo "Validar que exista alguno de estos outputs: eks_cluster_name o cluster_name."
  exit 1
fi

if [[ -z "${BASTION_INSTANCE_ID}" ]]; then
  echo "ERROR: no se pudo obtener bastion_instance_id desde Terraform."
  echo "Validar que el modulo EC2 exporte el ID del bastion."
  exit 1
fi

echo "======================================"
echo "Setup EKS por SSM desde Bastion"
echo "======================================"
echo "Terraform dir: ${TF_DIR}"
echo "Monitoring values: ${MONITORING_VALUES_FILE}"
echo "Cluster EKS: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
echo "Account ID local: ${AWS_ACCOUNT_ID}"
echo "LabRole ARN esperado: ${LAB_ROLE_ARN}"
echo "Caller local: ${LOCAL_CALLER_ARN}"
echo "Bastion Instance ID: ${BASTION_INSTANCE_ID}"
echo "======================================"

REMOTE_SCRIPT_FILE="$(mktemp)"
trap 'rm -f "${REMOTE_SCRIPT_FILE}"' EXIT

cat > "${REMOTE_SCRIPT_FILE}" <<REMOTE_SCRIPT
#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME}"
REGION="${REGION}"
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

wait_for_deployment() {
  local namespace="\$1"
  local deployment="\$2"
  local timeout="\${3:-300s}"

  echo "Esperando deployment \${namespace}/\${deployment}..."
  kubectl rollout status deployment "\${deployment}" -n "\${namespace}" --timeout="\${timeout}"
}

install_tools() {
  echo "======================================"
  echo "Validando herramientas en bastion"
  echo "======================================"

  install_packages() {
    if [[ "\$#" -eq 0 ]]; then
      return 0
    fi

    if command -v dnf >/dev/null 2>&1; then
      dnf install -y "\$@"
    elif command -v yum >/dev/null 2>&1; then
      yum install -y "\$@"
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y "\$@"
    else
      echo "ERROR: no se encontro dnf, yum ni apt-get para instalar paquetes base."
      exit 1
    fi
  }

  missing_packages=()

  command -v curl >/dev/null 2>&1 || missing_packages+=(curl)
  command -v tar >/dev/null 2>&1 || missing_packages+=(tar)
  command -v gzip >/dev/null 2>&1 || missing_packages+=(gzip)
  command -v unzip >/dev/null 2>&1 || missing_packages+=(unzip)
  command -v git >/dev/null 2>&1 || missing_packages+=(git)
  command -v jq >/dev/null 2>&1 || missing_packages+=(jq)

  if ! command -v aws >/dev/null 2>&1; then
    missing_packages+=(awscli)
  else
    echo "AWS CLI ya instalado: \$(aws --version 2>&1)"
  fi

  if [[ "\${#missing_packages[@]}" -gt 0 ]]; then
    echo "Instalando paquetes faltantes: \${missing_packages[*]}"
    install_packages "\${missing_packages[@]}"
  else
    echo "Paquetes base ya disponibles en el bastion."
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "Instalando kubectl..."
    curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
  else
    echo "kubectl ya instalado."
  fi

  if ! command -v eksctl >/dev/null 2>&1; then
    echo "Instalando eksctl..."
    curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin/eksctl
    chmod +x /usr/local/bin/eksctl
  else
    echo "eksctl ya instalado."
  fi

  if ! command -v helm >/dev/null 2>&1; then
    echo "Instalando Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  else
    echo "Helm ya instalado."
  fi

  echo "Versiones disponibles:"
  aws --version
  kubectl version --client=true
  eksctl version
  helm version --short
}

install_tools

echo "======================================"
echo "Validando identidad AWS en bastion"
echo "======================================"
aws sts get-caller-identity

AWS_ACCOUNT_ID="\$(aws sts get-caller-identity --no-cli-pager --query Account --output text)"
LAB_ROLE_ARN="arn:aws:iam::\${AWS_ACCOUNT_ID}:role/LabRole"

echo "Cluster EKS: \${CLUSTER_NAME}"
echo "Region: \${REGION}"
echo "LabRole ARN: \${LAB_ROLE_ARN}"
BASTION_CALLER_ARN="\$(aws sts get-caller-identity --no-cli-pager --query Arn --output text)"
BASTION_USER_ID="\$(aws sts get-caller-identity --no-cli-pager --query UserId --output text)"
echo "Caller ARN bastion: \${BASTION_CALLER_ARN}"
echo "Caller UserId bastion: \${BASTION_USER_ID}"

echo "======================================"
echo "Configurando kubeconfig"
echo "======================================"
aws eks update-kubeconfig \
  --region "\${REGION}" \
  --name "\${CLUSTER_NAME}"

echo "Validando acceso Kubernetes desde bastion..."
if kubectl auth can-i list nodes >/dev/null 2>&1; then
  echo "El bastion tiene permisos para listar nodos."
  kubectl get nodes
else
  echo "El bastion no tiene permisos administrativos sobre Kubernetes."
  echo "Se continuara solo con los pasos IAM/EKS que requieren LabRole."
  echo "Los pasos Kubernetes/Helm se ejecutaran localmente desde la Mac."
fi

# ==========================================================
# OIDC / IRSA
# ==========================================================
echo "======================================"
echo "OIDC / IRSA"
echo "======================================"
echo "Se omite la creacion del IAM OIDC Provider porque el laboratorio no permite iam:CreateOpenIDConnectProvider."
echo "Los componentes se instalaran sin service-account-role-arn, usando el rol disponible en los nodos cuando aplique."

# ==========================================================
# EBS CSI Driver - Add-on de EKS sin IRSA
# ==========================================================
echo "======================================"
echo "Instalando EBS CSI Driver desde AWS EKS Add-on"
echo "======================================"

if aws eks describe-addon \
  --cluster-name "\${CLUSTER_NAME}" \
  --addon-name aws-ebs-csi-driver \
  --region "\${REGION}" >/dev/null 2>&1; then

  CURRENT_ADDON_STATUS="\$(aws eks describe-addon \
    --cluster-name "\${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --region "\${REGION}" \
    --query "addon.status" \
    --output text)"

  CURRENT_ADDON_ROLE="\$(aws eks describe-addon \
    --cluster-name "\${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --region "\${REGION}" \
    --query "addon.serviceAccountRoleArn" \
    --output text 2>/dev/null || true)"

  echo "EBS CSI Driver ya existe con estado: \${CURRENT_ADDON_STATUS}"
  echo "EBS CSI Driver serviceAccountRoleArn actual: \${CURRENT_ADDON_ROLE}"

  if [[ "\${CURRENT_ADDON_ROLE}" != "None" && -n "\${CURRENT_ADDON_ROLE}" ]]; then
    echo "EBS CSI Driver quedo asociado a IRSA, pero el laboratorio no permite crear el IAM OIDC Provider."
    echo "Se elimina el add-on para recrearlo sin service-account-role-arn."
    aws eks delete-addon \
      --cluster-name "\${CLUSTER_NAME}" \
      --addon-name aws-ebs-csi-driver \
      --region "\${REGION}" || true

    echo "Esperando eliminacion del add-on EBS CSI Driver..."
    for i in {1..60}; do
      if ! aws eks describe-addon \
        --cluster-name "\${CLUSTER_NAME}" \
        --addon-name aws-ebs-csi-driver \
        --region "\${REGION}" >/dev/null 2>&1; then
        echo "EBS CSI Driver eliminado correctamente."
        break
      fi
      echo "EBS CSI Driver aun existe, esperando... intento \${i}/60"
      sleep 10
    done
  elif [[ "\${CURRENT_ADDON_STATUS}" == "CREATING" || "\${CURRENT_ADDON_STATUS}" == "UPDATING" || "\${CURRENT_ADDON_STATUS}" == "DELETING" ]]; then
    echo "EBS CSI Driver esta en estado \${CURRENT_ADDON_STATUS}; no se intenta update-addon ahora."
  else
    echo "Actualizando EBS CSI Driver sin service-account-role-arn..."
    aws eks update-addon \
      --cluster-name "\${CLUSTER_NAME}" \
      --addon-name aws-ebs-csi-driver \
      --region "\${REGION}" \
      --resolve-conflicts OVERWRITE || true
  fi
fi

if ! aws eks describe-addon \
  --cluster-name "\${CLUSTER_NAME}" \
  --addon-name aws-ebs-csi-driver \
  --region "\${REGION}" >/dev/null 2>&1; then
  echo "Creando EBS CSI Driver sin service-account-role-arn..."
  aws eks create-addon \
    --cluster-name "\${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --region "\${REGION}" \
    --resolve-conflicts OVERWRITE || true
fi

if aws eks describe-addon \
  --cluster-name "\${CLUSTER_NAME}" \
  --addon-name aws-ebs-csi-driver \
  --region "\${REGION}" >/dev/null 2>&1; then
  echo "Estado actual del EBS CSI Driver:"
  aws eks describe-addon \
    --cluster-name "\${CLUSTER_NAME}" \
    --addon-name aws-ebs-csi-driver \
    --region "\${REGION}" \
    --query "addon.{addonName:addonName,status:status,health:health}" \
    --output table || true
else
  echo "WARN: EBS CSI Driver no quedo creado como add-on. Los PVCs de Prometheus/Grafana pueden quedar Pending."
fi

echo "======================================"
echo "Setup remoto IAM/EKS finalizado correctamente desde bastion por SSM"
echo "======================================"
REMOTE_SCRIPT

REMOTE_SCRIPT_B64="$(base64 < "${REMOTE_SCRIPT_FILE}" | tr -d '\n')"
REMOTE_B64_FILE="/tmp/eks-setup-remote.sh.b64"
REMOTE_SCRIPT_PATH="/tmp/eks-setup-remote.sh"
CHUNK_SIZE=12000

echo "Preparando envio del setup EKS al bastion por SSM..."
echo "El script remoto se envia en chunks para evitar limites de longitud de comandos de SSM."

send_ssm_command() {
  local comment="$1"
  local commands_json="$2"
  local command_id=""
  local status="Pending"
  local max_attempts="${SSM_MAX_ATTEMPTS:-120}"
  local attempt=1

  command_id="$(aws ssm send-command \
    --no-cli-pager \
    --instance-ids "${BASTION_INSTANCE_ID}" \
    --document-name "AWS-RunShellScript" \
    --comment "${comment}" \
    --parameters "commands=${commands_json}" \
    --query "Command.CommandId" \
    --output text)"

  echo "Command ID (${comment}): ${command_id}"

  while [[ "${attempt}" -le "${max_attempts}" ]]; do
    status="$(aws ssm get-command-invocation \
      --no-cli-pager \
      --command-id "${command_id}" \
      --instance-id "${BASTION_INSTANCE_ID}" \
      --query "Status" \
      --output text 2>/dev/null || echo Pending)"

    echo "Estado SSM (${comment}) intento ${attempt}/${max_attempts}: ${status}"

    case "${status}" in
      Success|Cancelled|TimedOut|Failed|Cancelling)
        break
        ;;
      *)
        sleep 10
        ;;
    esac

    attempt=$((attempt + 1))
  done

  echo "STDOUT (${comment}):"
  aws ssm get-command-invocation \
    --no-cli-pager \
    --command-id "${command_id}" \
    --instance-id "${BASTION_INSTANCE_ID}" \
    --query "StandardOutputContent" \
    --output text || true

  echo "STDERR (${comment}):"
  aws ssm get-command-invocation \
    --no-cli-pager \
    --command-id "${command_id}" \
    --instance-id "${BASTION_INSTANCE_ID}" \
    --query "StandardErrorContent" \
    --output text || true

  if [[ "${status}" != "Success" ]]; then
    echo "ERROR: fallo o no finalizo el comando SSM: ${comment}"
    echo "Command ID: ${command_id}"
    echo "Estado final observado: ${status}"
    echo "Para revisar luego:"
    echo "aws ssm get-command-invocation --command-id ${command_id} --instance-id ${BASTION_INSTANCE_ID} --no-cli-pager"
    exit 1
  fi
}

echo "Validando conectividad SSM contra el bastion..."
send_ssm_command "eks-setup-preflight" '["set -e","echo SSM_OK","uname -a","id","command -v aws || true","aws sts get-caller-identity","aws eks describe-cluster --region '${REGION}' --name '${CLUSTER_NAME}' --query cluster.name --output text"]'

echo "Limpiando archivos temporales remotos..."
send_ssm_command "eks-setup-clean" "[\"rm -f ${REMOTE_B64_FILE} ${REMOTE_SCRIPT_PATH}\",\"touch ${REMOTE_B64_FILE}\"]"

echo "Enviando script remoto en chunks..."
TOTAL_LENGTH="${#REMOTE_SCRIPT_B64}"
OFFSET=0
CHUNK_NUMBER=1

while [[ "${OFFSET}" -lt "${TOTAL_LENGTH}" ]]; do
  CHUNK="${REMOTE_SCRIPT_B64:${OFFSET}:${CHUNK_SIZE}}"
  echo "Enviando chunk ${CHUNK_NUMBER}..."
  send_ssm_command "eks-setup-upload-${CHUNK_NUMBER}" "[\"printf '%s' '${CHUNK}' >> ${REMOTE_B64_FILE}\"]"
  OFFSET=$((OFFSET + CHUNK_SIZE))
  CHUNK_NUMBER=$((CHUNK_NUMBER + 1))
done

echo "Decodificando y ejecutando script remoto..."
send_ssm_command "eks-setup-verify-remote-script" "[\"set -e\",\"wc -c ${REMOTE_B64_FILE}\",\"base64 -d ${REMOTE_B64_FILE} > ${REMOTE_SCRIPT_PATH}\",\"chmod +x ${REMOTE_SCRIPT_PATH}\",\"head -n 20 ${REMOTE_SCRIPT_PATH}\"]"
send_ssm_command "eks-setup-run" "[\"sudo ${REMOTE_SCRIPT_PATH}\"]"

wait_for_deployment_local() {
  local namespace="$1"
  local deployment="$2"
  local timeout="${3:-300s}"

  echo "Esperando deployment ${namespace}/${deployment}..."
  kubectl rollout status deployment "${deployment}" -n "${namespace}" --timeout="${timeout}"
}

# Debug function for deployment in a namespace
debug_deployment_local() {
  local namespace="$1"
  local deployment="$2"
  local selector=""

  echo "======================================"
  echo "Debug deployment ${namespace}/${deployment}"
  echo "======================================"
  kubectl get deployment -n "${namespace}" "${deployment}" -o wide || true
  kubectl describe deployment -n "${namespace}" "${deployment}" || true

  selector="$(kubectl get deployment -n "${namespace}" "${deployment}" -o jsonpath='{.spec.selector.matchLabels}' 2>/dev/null || true)"
  echo "Selector deployment: ${selector}"

  echo "Pods del namespace ${namespace}:"
  kubectl get pods -n "${namespace}" -o wide || true

  echo "Eventos recientes en ${namespace}:"
  kubectl get events -n "${namespace}" --sort-by=.lastTimestamp | tail -80 || true

  echo "Logs recientes del deployment ${deployment}:"
  kubectl logs -n "${namespace}" deployment/"${deployment}" --all-containers=true --tail=120 || true
}

echo "======================================"
echo "Ejecutando setup Kubernetes/Helm local"
echo "======================================"

aws eks update-kubeconfig \
  --no-cli-pager \
  --region "${REGION}" \
  --name "${CLUSTER_NAME}"

echo "Validando acceso local al cluster..."
kubectl get nodes

echo "======================================"
echo "Validando EBS CSI Driver para persistencia"
echo "======================================"
if kubectl get deployment -n kube-system ebs-csi-controller >/dev/null 2>&1; then
  if wait_for_deployment_local "kube-system" "ebs-csi-controller" "600s"; then
    echo "EBS CSI Driver disponible."
  else
    echo "ERROR: EBS CSI Driver no quedo disponible."
    echo "Estado del add-on en EKS:"
    aws eks describe-addon \
      --no-cli-pager \
      --cluster-name "${CLUSTER_NAME}" \
      --addon-name aws-ebs-csi-driver \
      --region "${REGION}" \
      --query "addon.{addonName:addonName,status:status,health:health}" \
      --output table || true

    echo "ServiceAccount EBS CSI:"
    kubectl get serviceaccount -n kube-system ebs-csi-controller-sa -o yaml || true

    echo "Pods EBS CSI:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver -o wide || true
    kubectl get pods -n kube-system | grep ebs-csi || true

    echo "Eventos relacionados a EBS CSI:"
    kubectl get events -n kube-system --sort-by=.lastTimestamp | grep -i ebs || true

    echo "Descripcion del deployment ebs-csi-controller:"
    kubectl describe deployment -n kube-system ebs-csi-controller || true

    echo "Logs del contenedor ebs-plugin:"
    kubectl logs -n kube-system deployment/ebs-csi-controller -c ebs-plugin --tail=80 || true

    echo "No se continua con Prometheus/Grafana persistente porque sus PVCs quedarian Pending."
    echo "Revisar el estado anterior del EBS CSI Driver y volver a ejecutar el script."
    exit 1
  fi
else
  echo "ERROR: no se encontro deployment ebs-csi-controller en kube-system."
  echo "El add-on EBS CSI Driver no esta listo o no pudo crearse."
  echo "No se continua con Prometheus/Grafana persistente porque sus PVCs quedarian Pending."
  exit 1
fi

kubectl apply -f - <<'YAML'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  tagSpecification_1: "Backup=true"
  tagSpecification_2: "Project=obligatorio-iscloud"
  tagSpecification_3: "Environment=prod"
  tagSpecification_4: "Component=monitoring"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
YAML

echo "======================================"
echo "Instalando Metrics Server para HPA"
echo "======================================"
kubectl apply -f "${METRICS_SERVER_DIR}/"
wait_for_deployment_local "kube-system" "metrics-server" "300s"

echo "Validando Metrics API..."
for i in {1..30}; do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "Metrics Server operativo."
    break
  fi

  echo "Esperando Metrics API... intento ${i}/30"
  sleep 5
done

if ! kubectl top nodes >/dev/null 2>&1; then
  echo "ERROR: Metrics Server no quedó operativo."
  exit 1
fi

echo "======================================"
echo "Instalando AWS Load Balancer Controller"
echo "======================================"
VPC_ID="$(aws eks describe-cluster \
  --no-cli-pager \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)"
echo "VPC ID: ${VPC_ID}"

VPC_CIDR="$(aws ec2 describe-vpcs \
  --no-cli-pager \
  --vpc-ids "${VPC_ID}" \
  --region "${REGION}" \
  --query "Vpcs[0].CidrBlock" \
  --output text)"
echo "VPC CIDR: ${VPC_CIDR}"


helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}" \
  --set enableServiceMutatorWebhook=false

wait_for_deployment_local "kube-system" "aws-load-balancer-controller" "300s"
# En AWS Academy el API Server no siempre logra llegar al webhook del controller.
# Se eliminan los webhooks de admision para evitar timeouts al crear Services/Ingress.
kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true

echo "======================================"
echo "Instalando Cluster Autoscaler"
echo "======================================"

helm repo add autoscaler https://kubernetes.github.io/autoscaler || true
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName="${CLUSTER_NAME}" \
  --set awsRegion="${REGION}" \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.skip-nodes-with-system-pods=false \
  --set extraArgs.skip-nodes-with-local-storage=false

wait_for_deployment_local "kube-system" "cluster-autoscaler-aws-cluster-autoscaler" "300s" || \
wait_for_deployment_local "kube-system" "cluster-autoscaler" "300s"

echo "======================================"
echo "Instalando monitoreo: Prometheus + Grafana"
echo "======================================"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found=true

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --timeout 15m \
  -f "${MONITORING_VALUES_FILE}"

# Los values deshabilitan admissionWebhooks y TLS del Prometheus Operator.
# Por lo tanto, no se crea manualmente monitoring-kube-prometheus-admission.
# Se eliminan webhooks admission residuales de ejecuciones anteriores para evitar timeouts.
kubectl delete validatingwebhookconfiguration monitoring-kube-prometheus-admission --ignore-not-found=true
kubectl delete mutatingwebhookconfiguration monitoring-kube-prometheus-admission --ignore-not-found=true

if ! wait_for_deployment_local "monitoring" "monitoring-grafana" "600s"; then
  debug_deployment_local "monitoring" "monitoring-grafana"
  exit 1
fi

if ! wait_for_deployment_local "monitoring" "monitoring-kube-prometheus-operator" "600s"; then
  debug_deployment_local "monitoring" "monitoring-kube-prometheus-operator"
  echo "ERROR: Prometheus Operator no quedo disponible. Revisar los eventos/logs anteriores."
  exit 1
fi

EKS_NODE_SG_ID="$(aws eks describe-cluster \
  --no-cli-pager \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --query "cluster.resourcesVpcConfig.securityGroupIds[0]" \
  --output text 2>/dev/null || true)"

if [[ -z "${EKS_NODE_SG_ID}" || "${EKS_NODE_SG_ID}" == "None" ]]; then
  EKS_NODE_SG_ID="$(aws ec2 describe-security-groups \
    --no-cli-pager \
    --region "${REGION}" \
    --filters "Name=tag:Name,Values=${CLUSTER_NAME}-nodes-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || true)"
fi

if [[ -n "${EKS_NODE_SG_ID}" && "${EKS_NODE_SG_ID}" != "None" ]]; then
  echo "Validando regla para que el ALB llegue a Grafana en los Pods/Nodos: ${EKS_NODE_SG_ID}"
  aws ec2 authorize-security-group-ingress \
    --no-cli-pager \
    --region "${REGION}" \
    --group-id "${EKS_NODE_SG_ID}" \
    --ip-permissions "IpProtocol=tcp,FromPort=3000,ToPort=3000,IpRanges=[{CidrIp=${VPC_CIDR},Description='Permite health checks y trafico ALB hacia Grafana'}]" >/dev/null 2>&1 || true
else
  echo "WARN: no se pudo resolver el Security Group de nodos para permitir trafico del ALB hacia Grafana."
fi

echo "======================================"
echo "Validaciones finales"
echo "======================================"
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
kubectl get storageclass
kubectl get pvc -n monitoring
kubectl get svc -n monitoring monitoring-grafana
kubectl get ingress -n monitoring
GRAFANA_HOSTNAME=""
GRAFANA_URL="PENDING"
for i in {1..90}; do
  GRAFANA_HOSTNAME="$(kubectl get ingress -n monitoring monitoring-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"

  if [[ -n "${GRAFANA_HOSTNAME}" ]]; then
    GRAFANA_URL="http://${GRAFANA_HOSTNAME}"
    HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${GRAFANA_URL}/api/health" || true)"

    if [[ "${HTTP_CODE}" == "200" ]]; then
      echo "ALB de Grafana disponible y health check OK."
      break
    fi

    echo "ALB de Grafana creado pero aun no responde OK. HTTP ${HTTP_CODE}. Intento ${i}/90"
  else
    echo "Esperando hostname del ALB de Grafana... intento ${i}/90"
  fi

  sleep 10
done

GRAFANA_USER="admin"
GRAFANA_PASSWORD="$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 --decode || true)"

if [[ -z "${GRAFANA_PASSWORD}" ]]; then
  GRAFANA_PASSWORD="PENDING"
fi
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get deployment -n monitoring monitoring-grafana
kubectl get deployment -n monitoring monitoring-kube-prometheus-operator

echo "======================================"
echo "Acceso a Grafana"
echo "======================================"
echo "Grafana queda expuesto mediante Ingress ALB para facilitar el acceso en el laboratorio."
if [[ "${GRAFANA_URL}" != "PENDING" ]]; then
  echo "URL Grafana: ${GRAFANA_URL}"
else
  echo "URL Grafana: PENDING"
  echo "Obtener URL externa luego con: kubectl get ingress -n monitoring monitoring-grafana"
fi
echo "Usuario Grafana: ${GRAFANA_USER}"
echo "Password Grafana: ${GRAFANA_PASSWORD}"

echo "Setup EKS finalizado correctamente."
