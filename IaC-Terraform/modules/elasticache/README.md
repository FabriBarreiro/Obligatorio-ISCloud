
# Módulo ElastiCache

Este módulo crea una capa de datos Redis administrada utilizando Amazon ElastiCache.

El objetivo es proveer Redis para los microservicios desplegados en EKS, evitando ejecutar Redis dentro del cluster Kubernetes y reduciendo la dependencia de volúmenes persistentes mediante EBS CSI Driver.

## Recursos creados

- `aws_elasticache_subnet_group`: grupo de subnets privadas donde se despliega Redis.
- `aws_elasticache_replication_group`: replication group Redis administrado por ElastiCache.

## Diseño

Redis se despliega en subnets privadas de datos, separadas de las subnets públicas y de las subnets privadas utilizadas por los worker nodes de EKS.

El despliegue utiliza un replication group con dos nodos distribuidos en dos zonas de disponibilidad:

- Un nodo primario.
- Una réplica.

La configuración habilita Multi-AZ y failover automático. En caso de falla del nodo primario, ElastiCache puede promover la réplica y mantener disponible el servicio Redis.

La comunicación hacia Redis queda restringida mediante Security Group, permitiendo únicamente tráfico TCP 6379 desde los worker nodes del cluster EKS.

## Variables

| Variable | Descripción | Tipo | Valor por defecto |
| --- | --- | --- | --- |
| `project_name` | Nombre del proyecto utilizado para nombrar los recursos. | `string` | n/a |
| `environment` | Ambiente donde se despliegan los recursos. | `string` | n/a |
| `subnet_ids` | IDs de las subnets privadas de datos donde se despliega ElastiCache. | `list(string)` | n/a |
| `security_group_id` | ID del Security Group asociado a Redis. | `string` | n/a |
| `engine_version` | Versión del motor Redis. | `string` | `7.1` |
| `node_type` | Tipo de nodo utilizado por ElastiCache. | `string` | `cache.t3.micro` |
| `port` | Puerto TCP utilizado por Redis. | `number` | `6379` |
| `num_cache_clusters` | Cantidad de nodos del replication group Redis. | `number` | `2` |
| `automatic_failover_enabled` | Habilita failover automático entre el nodo primario y la réplica. | `bool` | `true` |
| `multi_az_enabled` | Habilita despliegue Multi-AZ para mejorar la disponibilidad de Redis. | `bool` | `true` |

## Outputs

| Output | Descripción |
| --- | --- |
| `redis_replication_group_id` | ID del replication group Redis de ElastiCache. |
| `redis_primary_endpoint` | Endpoint DNS primario del replication group Redis. |
| `redis_reader_endpoint` | Endpoint DNS de lectura del replication group Redis. |
| `redis_port` | Puerto TCP del replication group Redis. |
| `redis_connection_string` | Cadena de conexión al endpoint primario en formato `host:puerto`. |
| `redis_subnet_group_name` | Nombre del subnet group utilizado por Redis. |

## Uso

```hcl
module "elasticache" {
  source = "../../modules/elasticache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.subnets.data_subnet_ids
  security_group_id = module.security_groups.elasticache_security_group_id
}
```

## Integración con Kubernetes

El endpoint primario expuesto por el módulo debe ser utilizado por el microservicio que consume Redis.

Ejemplo:

```yaml
env:
  - name: REDIS_ADDR
    value: "<redis_primary_endpoint>:6379"
```

En este diseño, el microservicio `cartservice` consume Redis administrado por ElastiCache en lugar de consumir un pod Redis dentro de Kubernetes.

## Consideraciones

- Redis no queda expuesto públicamente.
- El acceso se permite únicamente desde los worker nodes de EKS.
- Redis se despliega como servicio administrado fuera del cluster Kubernetes.
- La solución simplifica la persistencia de datos frente a una alternativa basada en Redis dentro de Kubernetes con PVC.
- El uso de replication group con Multi-AZ y failover automático mejora la disponibilidad del servicio.
- Para ambientes productivos reales, también se podría evaluar cifrado en tránsito, cifrado en reposo, backups automáticos y políticas de mantenimiento.
