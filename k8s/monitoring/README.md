

# Monitoreo en EKS

Este directorio contiene la configuración utilizada para desplegar la capa de monitoreo del clúster Amazon EKS.

El monitoreo se implementa mediante `kube-prometheus-stack`, instalado con Helm desde el script `eks-setup.sh`. Este stack permite recolectar métricas del clúster Kubernetes, visualizar dashboards en Grafana y disponer de componentes base para alertas.

## Componentes desplegados

| Componente | Descripción |
|---|---|
| Prometheus | Recolecta y almacena métricas del clúster mediante scraping HTTP |
| Grafana | Permite visualizar métricas mediante dashboards |
| Alertmanager | Componente utilizado para la gestión de alertas |
| kube-state-metrics | Expone métricas sobre el estado de objetos Kubernetes |
| node-exporter | Expone métricas de sistema operativo de cada worker node |
| Prometheus Operator | Administra recursos de monitoreo dentro del clúster |
| Grafana Loki | Almacena y permite consultar logs centralizados del clúster |
| Promtail | Recolecta logs de los pods/nodos y los envía a Loki |

## Archivo principal

| Archivo | Descripción |
|---|---|
| `kube-prometheus-stack-values.yaml` | Valores personalizados utilizados para instalar `kube-prometheus-stack` con Helm |
| `loki-values.yaml` | Valores personalizados utilizados para instalar Loki y Promtail con Helm |

## Instalación

La instalación se realiza automáticamente desde el script:

```bash
./eks-setup.sh
```

Durante la ejecución, el script instala el chart de Helm `kube-prometheus-stack` en el namespace `monitoring`.

Además, se instala Grafana Loki como backend de logs y Promtail como agente recolector, utilizando el archivo `loki-values.yaml`.

El comando utilizado por el script es equivalente a:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f k8s/monitoring/kube-prometheus-stack-values.yaml
```

## Funcionamiento

Prometheus recolecta métricas mediante scraping HTTP a endpoints internos del clúster.

Los principales orígenes de métricas son:

```text
Prometheus
├── kube-state-metrics
├── node-exporter
├── kubelet / cAdvisor
└── endpoints /metrics de aplicaciones, cuando existan
```

Para logs, el flujo es:

```text
Pods / Nodes
        ↓
Promtail
        ↓
Grafana Loki
        ↓
Grafana
```

Promtail recolecta logs generados por los pods del clúster y los envía a Loki. Grafana utiliza Loki como datasource para consultar logs desde la misma interfaz donde se visualizan las métricas de Prometheus.

### kube-state-metrics

Expone métricas sobre el estado de objetos Kubernetes, por ejemplo:

```text
Deployments
Pods
Nodes
DaemonSets
StatefulSets
PersistentVolumeClaims
HorizontalPodAutoscalers
```

Estas métricas permiten conocer el estado deseado y real de los recursos del clúster.

### node-exporter

Se despliega como DaemonSet, ejecutando un pod en cada worker node.

Permite obtener métricas del sistema operativo de los nodos, como:

```text
CPU
Memoria
Disco
Filesystem
Red
Load average
```

### kubelet / cAdvisor

Permite obtener métricas de contenedores y pods, como consumo de CPU, memoria, red y filesystem por contenedor.

### Grafana

Grafana utiliza Prometheus como datasource para visualizar la información recolectada mediante dashboards.

El acceso a Grafana se publica mediante Ingress y AWS Load Balancer Controller, generando un Application Load Balancer público para acceder a la interfaz web.

### Loki y Promtail

Loki se utiliza como backend de almacenamiento y consulta de logs. A diferencia de Prometheus, que trabaja con métricas, Loki almacena logs etiquetados para permitir búsquedas desde Grafana.

Promtail se despliega como agente recolector y se encarga de leer logs de los pods/nodos del clúster, agregar etiquetas relevantes y enviarlos a Loki.

Con esta integración, Grafana permite consultar métricas y logs desde una misma interfaz.

## Persistencia

El stack utiliza PersistentVolumeClaims para conservar datos de componentes que requieren persistencia, como Grafana, Prometheus y Loki.

Estos PVC se respaldan mediante Amazon EBS a través del EBS CSI Driver y la StorageClass `ebs-gp3`.

La persistencia permite conservar dashboards, configuración y datos de métricas aunque los pods sean recreados.

## Acceso a Grafana

Para obtener la contraseña inicial del usuario `admin`:

```bash
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Para obtener la URL pública creada por el Ingress de Grafana:

```bash
kubectl get ingress -n monitoring
```

También se puede consultar directamente el hostname del ALB:

```bash
kubectl get ingress -n monitoring \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' ; echo
```

## Validaciones

Verificar pods del namespace `monitoring`:

```bash
kubectl get pods -n monitoring -o wide
```

Verificar servicios:

```bash
kubectl get svc -n monitoring
```

Verificar Ingress:

```bash
kubectl get ingress -n monitoring
```

Verificar PersistentVolumeClaims:

```bash
kubectl get pvc -n monitoring
```

Verificar componentes de logs:

```bash
kubectl get pods -n monitoring | grep -iE 'loki|promtail'
```

Verificar TargetGroupBindings creados por AWS Load Balancer Controller:

```bash
kubectl get targetgroupbindings -A
```

Verificar eventos del namespace:

```bash
kubectl get events -n monitoring --sort-by=.lastTimestamp | tail -40
```

## Troubleshooting

### Loki o Promtail no levantan

Validar el estado de los pods asociados:

```bash
kubectl get pods -n monitoring | grep -iE 'loki|promtail'
```

Revisar logs:

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=100
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=100
```

Si el problema está asociado a volúmenes persistentes, revisar los PVC:

```bash
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring
```

### Pod del Prometheus Operator en ContainerCreating

Si el pod `monitoring-kube-prometheus-operator` queda en `ContainerCreating`, revisar eventos:

```bash
kubectl get events -n monitoring --sort-by=.lastTimestamp | tail -40
```

Un error posible es que falte el Secret de admission webhook:

```text
MountVolume.SetUp failed for volume "tls-secret" : secret "monitoring-kube-prometheus-admission" not found
```

En ese caso, se puede reinstalar el release de monitoreo:

```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --timeout 15m \
  -f k8s/monitoring/kube-prometheus-stack-values.yaml
```

### Grafana no queda accesible desde el ALB

Validar primero el Ingress y los TargetGroupBindings:

```bash
kubectl describe ingress -n monitoring
kubectl get targetgroupbindings -A
```

Luego revisar logs del AWS Load Balancer Controller:

```bash
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller \
  --since=10m --all-containers=true
```

Si el error indica que no se encuentra un Security Group del clúster, validar que el Security Group de los worker nodes tenga el tag:

```text
kubernetes.io/cluster/<cluster_name> = owned
```

Este tag se configura desde Terraform en el módulo `security-groups`.

## Consideraciones

- El stack de monitoreo se instala luego de crear el clúster EKS y los add-ons base.
- Prometheus recolecta métricas desde endpoints internos del clúster mediante scraping.
- Grafana no recolecta métricas directamente; consulta Prometheus como datasource.
- Loki almacena y permite consultar logs centralizados del clúster.
- Promtail recolecta logs de pods/nodos y los envía a Loki.
- node-exporter se ejecuta en cada worker node como DaemonSet.
- kube-state-metrics obtiene información del estado de objetos Kubernetes desde la API del clúster.
- La publicación de Grafana mediante ALB se realiza con AWS Load Balancer Controller.
- En el entorno AWS Academy no se utiliza IRSA por restricciones para crear el OIDC Provider.
- En producción se recomienda restringir el acceso al ALB de Grafana mediante CIDRs administrativos, autenticación adicional o VPN.
- Las alertas pueden ampliarse configurando rutas y receivers en Alertmanager.
