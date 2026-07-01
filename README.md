# Obligatorio – Implementación de Soluciones Cloud

## Descripción

Este repositorio contiene el desarrollo del obligatorio de la materia **Implementación de Soluciones Cloud**.

El proyecto consiste en la automatización del despliegue de una aplicación basada en **microservicios** sobre **Amazon Web Services (AWS)** utilizando **Terraform** como herramienta de Infraestructura como Código (IaC) y **Amazon Elastic Kubernetes Service (EKS)** como plataforma de orquestación de contenedores.

Toda la infraestructura se encuentra completamente automatizada, permitiendo desplegar el ambiente desde cero mediante Terraform y posteriormente publicar la aplicación utilizando Docker, Amazon ECR y Kubernetes.

---

# Objetivos

Los principales objetivos del proyecto son:

- Automatizar completamente la creación de la infraestructura.
- Implementar una arquitectura basada en microservicios.
- Utilizar Kubernetes como plataforma de orquestación.
- Implementar alta disponibilidad mediante múltiples Availability Zones.
- Permitir el escalado automático de los servicios mediante Horizontal Pod Autoscaler (HPA).
- Publicar la aplicación mediante un Application Load Balancer utilizando AWS Load Balancer Controller.
- Mantener toda la infraestructura versionada mediante Terraform.

---

# Arquitectura General

La solución implementada está compuesta por los siguientes componentes:

- Amazon VPC
- Subnets públicas y privadas
- Internet Gateway
- NAT Gateway
- Amazon EKS
- Amazon ECR
- Amazon ElastiCache Redis
- AWS Load Balancer Controller
- Metrics Server
- Horizontal Pod Autoscaler (HPA)
- Docker
- Terraform

La aplicación se ejecuta dentro de un clúster de Kubernetes compuesto por varios microservicios independientes, los cuales son publicados mediante un Ingress que crea automáticamente un Application Load Balancer en AWS.

---

# Tecnologías utilizadas

| Tecnología | Uso |
|------------|-----|
| Terraform | Infraestructura como Código |
| AWS | Plataforma Cloud |
| Amazon EKS | Kubernetes administrado |
| Kubernetes | Orquestación de contenedores |
| Docker | Contenedores |
| Amazon ECR | Registro de imágenes Docker |
| Amazon RDS | Base de datos PostgreSQL |
| Amazon ElastiCache | Cache Redis |
| AWS Load Balancer Controller | Publicación mediante Ingress |
| Metrics Server | Obtención de métricas del clúster |
| Horizontal Pod Autoscaler | Escalado automático |

---

# Estructura del repositorio

# Estructura del repositorio

```text
Obligatorio-ISCloud/
│
├── aplicativo/
│   └── Obligatorio-Microservicios-main/
│       ├── src/                        # Código fuente de la aplicación
│       └── pb/                         # Definiciones Protocol Buffers (gRPC)
│
├── IaC-Terraform/
│   ├── environments/
│   │   └── prod/                       # Configuración del entorno de producción
│   │
│   └── modules/
│       ├── ec2/                        # Instancia Bastion Host
│       ├── ecr/                        # Repositorios Amazon ECR
│       ├── eks/                        # Clúster Amazon EKS y Node Groups
│       ├── elasticache/                # Redis (Amazon ElastiCache)
│       ├── igw/                        # Internet Gateway
│       ├── natgw/                      # NAT Gateway
│       ├── route-tables/               # Tablas de ruteo públicas y privadas
│       ├── security-groups/            # Reglas de firewall
│       ├── subnets/                    # Subredes públicas y privadas
│       └── vpc/                        # Virtual Private Cloud
│
├── docker/                             # Scripts para construir y publicar imágenes en Amazon ECR
│
├── k8s/
│   ├── generated/                      # Manifiestos Kubernetes generados automáticamente
│   ├── hpa/                            # Horizontal Pod Autoscaler
│   ├── metrics-server/                 # Instalación de Metrics Server
│   └── monitoring/                     # Recursos de monitoreo
│
├── docs/                               #Documentación del proyecto
│   
│   
│   
│
├── deploy-eks.sh                       # Automatiza el despliegue de la aplicación sobre Amazon EKS
├── eks-setup.sh                        # Configuración inicial del clúster (ALB Controller, Metrics Server, etc.)
│
└── README.md                           # Documentación principal del proyecto
```


# Autores

Fabricio Barreiro

Santiago Hoaguy
