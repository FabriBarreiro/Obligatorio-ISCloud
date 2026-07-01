

# Horizontal Pod Autoscaler

Este directorio contiene los manifiestos de **Horizontal Pod Autoscaler (HPA)** utilizados para escalar automáticamente algunos microservicios de la aplicación desplegada en Amazon EKS.

El HPA permite ajustar dinámicamente la cantidad de réplicas de un Deployment según métricas de consumo, principalmente CPU. Para funcionar correctamente, requiere que **Metrics Server** esté instalado y operativo en el clúster.

## Objetivo

El objetivo de estos manifiestos es mejorar la capacidad de respuesta de los servicios principales ante aumentos de carga, permitiendo que Kubernetes incremente o reduzca automáticamente la cantidad de pods según el consumo observado.

El escalado automático ayuda a:

- Responder ante picos de tráfico.
- Evitar sobredimensionar permanentemente todos los servicios.
- Mantener una cantidad mínima de réplicas disponibles.
- Mejorar la disponibilidad de servicios críticos de la aplicación.

## Manifiestos incluidos

| Archivo | Deployment asociado | Mínimo | Máximo | Métrica | Target |
|---|---|---:|---:|---|---:|
| `frontend-hpa.yaml` | `frontend` | 2 | 4 | CPU | 80% |
| `cartservice-hpa.yaml` | `cartservice` | 2 | 4 | CPU | 80% |
| `checkoutservice-hpa.yaml` | `checkoutservice` | 2 | 4 | CPU | 80% |
| `productcatalogservice-hpa.yaml` | `productcatalogservice` | 2 | 4 | CPU | 80% |
| `recommendationservice-hpa.yaml` | `recommendationservice` | 2 | 4 | CPU | 80% |

Todos los manifiestos utilizan `autoscaling/v2`, apuntan a recursos `Deployment` y escalan según utilización promedio de CPU:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

## Funcionamiento

El flujo general de autoscaling es:

```text
Aumenta el tráfico o consumo de CPU
        ↓
Los pods consumen más recursos
        ↓
Metrics Server expone métricas actuales
        ↓
HPA evalúa el consumo contra el target configurado
        ↓
Kubernetes incrementa o reduce réplicas del Deployment
```

El HPA actúa sobre Deployments existentes. No crea la aplicación desde cero, sino que modifica el número de réplicas de los Deployments definidos en los manifiestos principales. En esta implementación, cada HPA mantiene al menos `2` réplicas y puede escalar hasta `4` réplicas cuando la utilización promedio de CPU supera el target configurado del `80%`.

## Relación con Metrics Server

Los HPAs dependen de Metrics Server para obtener métricas actuales de CPU/memoria.

Antes de validar los HPAs, debe estar operativo:

```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods
```

Si Metrics Server no funciona, los HPAs pueden quedar mostrando valores como:

```text
unknown
```

o no podrán calcular correctamente el escalado.

## Relación con Cluster Autoscaler

El HPA escala **pods**, no nodos.

Si al aumentar las réplicas no hay capacidad suficiente en los worker nodes, algunos pods pueden quedar en estado `Pending`. En ese caso, **Cluster Autoscaler** puede incrementar la cantidad de nodos del Managed Node Group, siempre que no se haya alcanzado el máximo configurado en Terraform.

Flujo completo:

```text
HPA escala réplicas de pods
        ↓
No hay recursos suficientes en los nodos
        ↓
Pods quedan Pending
        ↓
Cluster Autoscaler agrega worker nodes
```

## Instalación

Los HPAs se aplican automáticamente desde el script de despliegue:

```bash
./deploy-eks.sh
```

También pueden aplicarse manualmente:

```bash
kubectl apply -f k8s/hpa/
```

## Validaciones

Verificar HPAs creados:

```bash
kubectl get hpa
```

También se puede ver el target de CPU, mínimos y máximos:

```bash
kubectl get hpa frontend-hpa cartservice-hpa checkoutservice-hpa productcatalogservice-hpa recommendationservice-hpa
```

Ver detalles de un HPA:

```bash
kubectl describe hpa frontend-hpa
```

Ejemplo de valores esperados:

```text
MINPODS: 2
MAXPODS: 4
TARGETS: <cpu actual>%/80%
```

Ver Deployments y réplicas actuales:

```bash
kubectl get deployments
```

Ver pods generados por el escalado:

```bash
kubectl get pods -o wide
```

Ver métricas disponibles para pods:

```bash
kubectl top pods
```

## Prueba de escalado

Para probar el comportamiento del HPA se puede generar carga contra el frontend publicado por el Application Load Balancer.

Obtener la URL del frontend:

```bash
FRONTEND_URL="http://$(kubectl get ingress frontend-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "$FRONTEND_URL"
```

Durante la prueba, observar los HPAs:

```bash
kubectl get hpa -w
```

Observar pods:

```bash
kubectl get pods -w
```

Observar nodos si se quiere validar interacción con Cluster Autoscaler:

```bash
kubectl get nodes -w
```

## Troubleshooting

### HPA muestra unknown

Validar Metrics Server:

```bash
kubectl get pods -n kube-system | grep metrics-server
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods
```

Revisar logs de Metrics Server:

```bash
kubectl logs -n kube-system deployment/metrics-server --tail=100
```

### El HPA no escala

Validar que el Deployment tenga requests de CPU/memoria definidos. HPA necesita requests para calcular correctamente la utilización porcentual.

```bash
kubectl describe deployment frontend
kubectl describe hpa frontend-hpa
```

También revisar que exista consumo suficiente para superar el target definido. En estos manifiestos el target es `80%` de CPU promedio, por lo que el HPA no aumentará réplicas si el consumo se mantiene por debajo de ese umbral.

### Hay pods Pending después de escalar

Validar capacidad del clúster:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl get nodes
```

Si el motivo es falta de CPU o memoria, revisar Cluster Autoscaler:

```bash
kubectl -n kube-system logs deployment/cluster-autoscaler-aws-cluster-autoscaler --tail=100
```

## Consideraciones

- HPA escala pods, no nodos.
- Metrics Server debe estar instalado y operativo para que los HPAs funcionen.
- Cluster Autoscaler complementa al HPA agregando nodos cuando no hay capacidad suficiente.
- Los servicios incluidos en este directorio son los que se consideran más relevantes para absorber carga en la aplicación.
- Durante las pruebas de estrés se observó que `currencyservice` también puede verse afectado por el aumento de requests, por lo que podría evaluarse agregar un HPA específico para ese servicio.
- Todos los HPAs definidos utilizan `minReplicas: 2`, `maxReplicas: 4` y `averageUtilization: 80` para CPU.
- La configuración de mínimos, máximos y target de CPU puede ajustarse según resultados de pruebas de carga.
- En producción se recomienda definir requests y limits consistentes para todos los microservicios antes de habilitar autoscaling.
