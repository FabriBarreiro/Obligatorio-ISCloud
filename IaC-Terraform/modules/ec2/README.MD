

# Módulo EC2 - Bastion Host

Este módulo crea una instancia EC2 utilizada como Bastion Host para administrar recursos privados dentro de la VPC.

El Bastion Host se despliega en una subnet pública, con IP pública asociada y utilizando el Security Group definido para administración por SSH. Desde este servidor se podrá acceder a recursos internos, como el endpoint privado del cluster EKS.

## Recursos creados

| Recurso | Descripción |
|---|---|
| `data.aws_ssm_parameter.amazon_linux_2023_ami` | Obtiene la AMI más reciente de Amazon Linux 2023 desde SSM Parameter Store |
| `aws_instance.bastion` | Instancia EC2 utilizada como Bastion Host |

## Diseño

El Bastion Host se ubica en una subnet pública para permitir acceso administrativo desde Internet mediante SSH.

La instancia utiliza:

```text
Amazon Linux 2023
Key Pair vockey
Security Group del Bastion
IP pública asociada
Disco raíz gp3 cifrado
```

El acceso SSH queda controlado por el Security Group creado en el módulo `security-groups`.

## User data

Durante el arranque de la instancia se ejecuta un `user_data` básico que actualiza el sistema e instala herramientas necesarias para administración:

```text
awscli
git
unzip
tar
gzip
```

Estas herramientas permiten trabajar desde el Bastion Host con AWS CLI, repositorios Git y archivos comprimidos.

## Variables

| Variable | Tipo | Descripción |
|---|---|---|
| `project_name` | `string` | Nombre del proyecto utilizado para nombrar el Bastion Host |
| `environment` | `string` | Ambiente donde se despliega la infraestructura |
| `public_subnet_id` | `string` | ID de la subnet pública donde se desplegará el Bastion Host |
| `bastion_security_group_id` | `string` | ID del Security Group asociado al Bastion Host |
| `instance_type` | `string` | Tipo de instancia EC2 utilizado para el Bastion Host |
| `key_name` | `string` | Nombre del Key Pair utilizado para acceso SSH |
| `root_volume_size` | `number` | Tamaño en GB del disco raíz |

## Outputs

| Output | Descripción |
|---|---|
| `bastion_instance_id` | ID de la instancia EC2 utilizada como Bastion Host |
| `bastion_public_ip` | IP pública del Bastion Host |
| `bastion_public_dns` | DNS público del Bastion Host |
| `bastion_private_ip` | IP privada del Bastion Host |
| `bastion_private_dns` | DNS privado del Bastion Host |

## Ejemplo de uso

```hcl
module "ec2" {
  source = "../../modules/ec2"

  project_name              = "obligatorio-iscloud"
  environment               = "prod"
  public_subnet_id          = module.subnets.public_subnet_ids[0]
  bastion_security_group_id = module.security_groups.bastion_security_group_id
  instance_type             = "t3.micro"
  key_name                  = "vockey"
  root_volume_size          = 20
}
```

## Consideraciones

- El Bastion Host se ubica en una subnet pública porque necesita ser accesible por SSH.
- El acceso SSH se controla mediante el Security Group del Bastion.
- En este laboratorio se utiliza el Key Pair `vockey`, provisto por AWS Academy.
- La AMI se obtiene dinámicamente desde SSM Parameter Store, evitando hardcodear un AMI ID.
- El disco raíz se crea cifrado y con tipo `gp3`.
- En un entorno productivo, el acceso SSH debería limitarse únicamente a IPs administrativas conocidas.
- Si el endpoint de EKS queda privado, el Bastion Host será el punto de administración para ejecutar herramientas como `awscli` y `kubectl`.
