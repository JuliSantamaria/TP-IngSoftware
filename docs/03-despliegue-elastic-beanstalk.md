# Despliegue con AWS Elastic Beanstalk

## 3. DESPLIEGUE CON AWS ELASTIC BEANSTALK

### ¿Qué es Elastic Beanstalk?

AWS Elastic Beanstalk es una plataforma como servicio (PaaS) que simplifica el despliegue y gestión de aplicaciones web. Maneja automáticamente la infraestructura, el balanceador de carga, el auto-escalado, y el monitoreo.

### Preparación de la aplicación

#### Paso 1: Modificar server.js para Elastic Beanstalk

Elastic Beanstalk espera que las aplicaciones Node.js usen el puerto 8080 o el puerto especificado en la variable de entorno PORT.

**Verificación del código actual:**
El archivo `server.js` ya está preparado correctamente:
```javascript
const PORT = process.env.PORT || 3001;
```

#### Paso 2: Crear configuración de Elastic Beanstalk

Los archivos de configuración ya se han creado en `.ebextensions/`:

**`.ebextensions/01-nodejs.config`** - Configuración de Node.js
**`.ebextensions/02-proxy.config`** - Configuración del proxy Nginx

### Instalación del EB CLI

#### Windows (PowerShell como administrador):

```powershell
# Opción 1: Instalar con pip (requiere Python)
pip install awsebcli

# Opción 2: Descargar instalador directo
$url = "https://s3.amazonaws.com/aws-cli/eb-cli-bundle.zip"
$output = "$env:TEMP\eb-cli-bundle.zip"
Invoke-WebRequest -Uri $url -OutFile $output
Expand-Archive -Path $output -DestinationPath "$env:TEMP\eb-cli"
# Ejecutar: $env:TEMP\eb-cli\install.py

# Verificar instalación
eb --version
```

### Despliegue paso a paso

#### Paso 1: Inicializar aplicación Elastic Beanstalk

```powershell
# Navegar al directorio del proyecto
cd "c:\Users\JulianMartinSantamar\OneDrive - Fulter Logistics\Escritorio\Tp Ing de software\inventory"

# Inicializar aplicación EB
eb init

# Responder a las preguntas interactivas:
# - Select a default region: us-east-1 (o tu región preferida)
# - Select an application to use: Create new Application
# - Enter Application Name: inventory-app
# - It appears you are using Node.js. Is this correct?: Y
# - Select a platform branch: Node.js 18 running on 64bit Amazon Linux 2023
# - Cannot setup CodeCommit because there is no Source Control setup: Continue with current directory
# - Do you want to set up SSH for your instances?: Y (opcional)
```

#### Paso 2: Crear entorno de desarrollo

```powershell
# Crear entorno de desarrollo
eb create inventory-dev

# El proceso incluirá:
# - Enter Environment Name: inventory-dev (o presiona Enter para usar el default)
# - Enter DNS CNAME prefix: inventory-dev-tu-nombre (debe ser único globalmente)
# - Select a load balancer type: Application Load Balancer

# Esperar a que se complete el despliegue (5-10 minutos)
Write-Host "⏳ Creando entorno... Esto puede tomar varios minutos"
```

#### Paso 3: Verificar el despliegue

```powershell
# Verificar el estado del entorno
eb status

# Abrir la aplicación en el navegador
eb open

# Ver logs en tiempo real
eb logs --all
```

#### Paso 4: Actualizaciones posteriores

```powershell
# Para desplegar cambios posteriores
eb deploy

# Para ver el health del entorno
eb health

# Para escalar la aplicación
eb scale 2  # Escalar a 2 instancias
```

### Configuración avanzada

#### Configurar variables de entorno

```powershell
# Establecer variables de entorno
eb setenv NODE_ENV=production DB_NAME=inventory

# Ver variables actuales
eb printenv
```

#### Configurar autoescalado

Crear archivo `.ebextensions/03-autoscaling.config`:

```yaml
option_settings:
  aws:autoscaling:asg:
    MinSize: 1
    MaxSize: 4
  aws:autoscaling:trigger:
    MeasureName: CPUUtilization
    Unit: Percent
    UpperThreshold: 70
    LowerThreshold: 20
    ScaleUpIncrement: 1
    ScaleDownIncrement: -1
```

#### Configurar HTTPS (SSL)

```powershell
# Obtener certificado SSL gratuito con AWS Certificate Manager
aws acm request-certificate --domain-name tu-dominio.com --validation-method DNS

# Configurar HTTPS en Elastic Beanstalk
eb config
# Buscar la sección ssl y configurar el certificate ARN
```

### Comandos útiles de EB CLI

```powershell
# Ver información general
eb list                    # Listar todas las aplicaciones
eb status                  # Estado del entorno actual
eb health                  # Health check detallado
eb events                  # Ver eventos recientes

# Gestión de entornos
eb create <env-name>       # Crear nuevo entorno
eb clone <env-name>        # Clonar entorno existente
eb swap <env1> <env2>      # Intercambiar URLs entre entornos
eb terminate <env-name>    # Terminar entorno

# Despliegue y configuración
eb deploy                  # Desplegar cambios
eb config                  # Editar configuración del entorno
eb setenv KEY=VALUE        # Establecer variable de entorno
eb printenv               # Ver variables de entorno

# Monitoreo y debugging
eb logs                   # Ver logs
eb ssh                    # Conectar via SSH a instancia
eb open                   # Abrir aplicación en navegador
eb console               # Abrir consola de AWS

# Gestión local
eb init                   # Inicializar proyecto
eb local run             # Ejecutar localmente (requiere Docker)
```

### Estructura de archivos para EB

```
inventory/
├── server.js
├── package.json
├── public/
│   ├── index.html
│   ├── app.js
│   ├── manifest.json
│   └── sw.js
├── .ebextensions/
│   ├── 01-nodejs.config
│   ├── 02-proxy.config
│   └── 03-autoscaling.config (opcional)
├── .elasticbeanstalk/
│   └── config.yml (generado automáticamente)
└── .gitignore
```

### Configuración de base de datos (opcional)

Para una base de datos persistente (recomendado para producción):

```powershell
# Crear RDS MySQL/PostgreSQL separadamente
aws rds create-db-instance --db-instance-identifier inventory-db --db-instance-class db.t3.micro --engine mysql --master-username admin --master-user-password tu-password --allocated-storage 20

# Configurar variables de entorno en EB
eb setenv DB_HOST=inventory-db.xxxxx.us-east-1.rds.amazonaws.com DB_USER=admin DB_PASS=tu-password DB_NAME=inventory
```

### Monitoreo y alertas

```powershell
# Ver métricas en tiempo real
eb health --refresh

# Configurar alertas (vía AWS CLI)
aws cloudwatch put-metric-alarm --alarm-name "inventory-high-cpu" --alarm-description "High CPU on Inventory App" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 80.0 --comparison-operator GreaterThanThreshold
```

### Solución de problemas comunes

#### Error de puerto
```javascript
// Asegurar que server.js usa process.env.PORT
const PORT = process.env.PORT || 8080; // EB usa 8080 por defecto
```

#### Logs detallados
```powershell
# Ver todos los logs
eb logs --all

# Log específico
eb ssh
sudo tail -f /var/log/eb-engine.log
```

#### Problemas de despliegue
```powershell
# Verificar configuración
eb config

# Revisar eventos
eb events --follow
```

### Costos estimados

- **t2.micro (Free Tier)**: $0/mes primeros 12 meses
- **Después de Free Tier**: ~$8-15/mes por instancia t2.micro
- **Application Load Balancer**: ~$16/mes
- **Total estimado**: $25-30/mes (después del free tier)

### Cleanup (eliminar recursos)

```powershell
# Terminar entorno
eb terminate inventory-dev

# Eliminar aplicación completamente
eb terminate --all
aws elasticbeanstalk delete-application --application-name inventory-app
```

---

## Ventajas de Elastic Beanstalk

1. **Gestión automática de infraestructura**
2. **Autoescalado integrado**
3. **Balanceador de carga automático**
4. **Monitoreo y alertas integradas**
5. **Actualizaciones sin tiempo de inactividad**
6. **Integración con otros servicios de AWS**
7. **Configuración simplificada**