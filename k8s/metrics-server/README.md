

# Metrics Server

Este directorio contiene los manifiestos utilizados para instalar **Metrics Server** en el clúster Amazon EKS.

Metrics Server es un componente de Kubernetes que recolecta métricas básicas de uso de recursos, principalmente CPU y memoria, desde los kubelets de los worker nodes. Estas métricas son expuestas mediante la Metrics API de Kubernetes y son utilizadas por componentes como el Horizontal Pod Autoscaler.

## Objetivo

El objetivo de Metrics Server en este proyecto es habilitar el uso de HPA para escalar automáticamente los microservicios según el consumo de recursos.

Sin Metrics Server, los HPAs no pueden obtener métricas actuales de CPU/memoria y quedan sin información para calcular el escalado.

## Funcionamiento

El flujo general es:

```text
Kubelet / cAdvisor
        ↓
Metrics Server
        ↓
Kubernetes Metrics API
        ↓
Horizontal Pod Autoscaler
        ↓
Escalado de réplicas de pods
```


Metrics Server no reemplaza a Prometheus. Su función es proveer métricas rápidas y livianas para autoscaling. Prometheus se utiliza para observabilidad, dashboards, consultas históricas y alertas.

## Manifiesto utilizado

La instalación se realiza a partir del manifiesto:

```text
components.yaml
```

Este manifiesto instala Metrics Server en el namespace `kube-system` utilizando la imagen:

```text
registry.k8s.io/metrics-server/metrics-server:v0.8.1
```

El deployment queda configurado para ejecutarse sobre nodos Linux mediante:

```yaml
nodeSelector:
  kubernetes.io/os: linux
```

## Componentes creados

El manifiesto `components.yaml` crea los siguientes recursos:

| Recurso | Descripción |
|---|---|
| ServiceAccount | Identidad utilizada por Metrics Server dentro del clúster |
| ClusterRole | Permisos necesarios para leer métricas desde nodos y pods |
| ClusterRoleBinding | Asociación entre permisos y ServiceAccount |
| RoleBinding | Permisos necesarios para autenticación delegada |
| Service | Expone Metrics Server dentro del clúster en el puerto `443` |
| Deployment | Ejecuta el pod de Metrics Server con la imagen `metrics-server:v0.8.1` |
| APIService | Registra la Metrics API `v1beta1.metrics.k8s.io` |

## Configuración relevante

El contenedor de Metrics Server escucha en el puerto seguro `10250`:

```yaml
--secure-port=10250
```

El Service expone Metrics Server internamente por el puerto `443` y redirige hacia el puerto HTTPS del contenedor:

```yaml
port: 443
targetPort: https
```

Las flags principales configuradas en el manifiesto son:

```yaml
--cert-dir=/tmp
--secure-port=10250
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--kubelet-use-node-status-port
--metric-resolution=15s
```

La resolución de métricas queda configurada cada `15s`, lo cual permite que HPA disponga de información actualizada para calcular el escalado.

El contenedor también define requests mínimos de recursos:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 200Mi
```

Además, el manifiesto incluye endurecimiento básico de seguridad del contenedor:

```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: 1000
seccompProfile:
  type: RuntimeDefault
capabilities:
  drop:
    - ALL
```

## Instalación

La instalación se realiza automáticamente desde el script:

```bash
./eks-setup.sh
```

Durante la ejecución del script se aplica el manifiesto `components.yaml` y se espera a que el deployment `metrics-server` quede disponible.

También puede instalarse manualmente aplicando el manifiesto:

```bash
kubectl apply -f k8s/metrics-server/components.yaml
```

## Validaciones

Verificar que el deployment esté disponible:

```bash
kubectl get deployment metrics-server -n kube-system
```

Verificar el pod:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

Validar que la Metrics API esté registrada:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```

Validar métricas de nodos:

```bash
kubectl top nodes
```

Validar métricas de pods:

```bash
kubectl top pods
```

Validar HPAs:

```bash
kubectl get hpa
```

Si Metrics Server está funcionando correctamente, los HPAs deberían mostrar valores actuales de CPU/memoria en lugar de `unknown`.

## Uso con HPA

Los manifiestos de HPA de la aplicación dependen de Metrics Server para obtener métricas de consumo.

Ejemplo de comportamiento esperado:

```text
Aumenta el uso de CPU de un deployment
        ↓
Metrics Server expone métricas actuales
        ↓
HPA detecta el aumento
        ↓
HPA incrementa la cantidad de réplicas
```

Metrics Server escala pods mediante HPA, no nodos. Si luego de escalar pods no hay capacidad suficiente en el cluster y quedan pods en estado `Pending`, Cluster Autoscaler puede agregar nuevos worker nodes dentro de los límites configurados en el node group.

## Troubleshooting

### HPA muestra métricas como unknown

Validar primero Metrics Server:

```bash
kubectl get pods -n kube-system | grep metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

Si `kubectl top nodes` falla, revisar logs:

```bash
kubectl logs -n kube-system deployment/metrics-server --tail=100
```

### Pod de Metrics Server no levanta

Revisar eventos del namespace `kube-system`:

```bash
kubectl get events -n kube-system --sort-by=.lastTimestamp | tail -40
```

Describir el deployment:

```bash
kubectl describe deployment metrics-server -n kube-system
```

### Error de conexión con kubelet

Si Metrics Server no puede comunicarse con kubelet, revisar que los nodos estén en estado `Ready`, que kubelet esté respondiendo y que Metrics Server pueda resolver la dirección interna de los nodos. El manifiesto prioriza `InternalIP`, luego `ExternalIP` y finalmente `Hostname` mediante `--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname`.

También validar:

```bash
kubectl get nodes
kubectl describe node <node-name>
```

## Consideraciones

- Metrics Server se instala en el namespace `kube-system`.
- La versión utilizada por el manifiesto es `metrics-server:v0.8.1`.
- El Service expone Metrics Server por `443` y el contenedor escucha en `10250`.
- La resolución de métricas está configurada cada `15s`.
- Se prioriza el uso de `InternalIP` para comunicarse con kubelet.
- Es requerido para que HPA pueda escalar pods según métricas de CPU/memoria.
- No almacena métricas históricas.
- No se utiliza para dashboards ni análisis histórico; para eso se usa Prometheus y Grafana.
- No reemplaza a Prometheus ni a CloudWatch.
- Debe estar operativo antes de validar HPAs.
- Si los HPAs muestran `unknown`, el primer componente a revisar es Metrics Server.
