# Guías de Despliegue AWS - Aplicación de Inventario

Este proyecto incluye documentación completa y scripts automatizados para desplegar tu aplicación de inventario en AWS usando tres enfoques diferentes.

## Estructura de Documentación

### Documentos Principales
- **[01-despliegue-ec2-manual.md](docs/01-despliegue-ec2-manual.md)** - Despliegue manual y con User Data en EC2
- **[02-despliegue-aws-cli.md](docs/02-despliegue-aws-cli.md)** - Automatización completa con AWS CLI  
- **[03-despliegue-elastic-beanstalk.md](docs/03-despliegue-elastic-beanstalk.md)** - Despliegue simplificado con Elastic Beanstalk
- **[04-comparacion-alternativas.md](docs/04-comparacion-alternativas.md)** - Análisis comparativo de todas las opciones

### Scripts Automatizados
- **[inventory-deploy-cli.ps1](scripts/inventory-deploy-cli.ps1)** - Script PowerShell para EC2 con AWS CLI
- **[inventory-deploy-eb.ps1](scripts/inventory-deploy-eb.ps1)** - Script PowerShell para Elastic Beanstalk
- **[user-data.sh](scripts/user-data.sh)** - Script de inicialización automática para EC2

### Configuraciones
- **`.ebextensions/`** - Archivos de configuración para Elastic Beanstalk

##  Inicio Rápido

### Opción 1: EC2 Manual (Aprendizaje)
```powershell
# Ver guía completa en docs/01-despliegue-ec2-manual.md
# 1. Crear instancia EC2 en consola AWS
# 2. Instalar Node.js y dependencias
# 3. Subir y ejecutar aplicación
```

### Opción 2: EC2 Automatizado (Recomendado para DevOps)
```powershell
# Ejecutar script automatizado
.\scripts\inventory-deploy-cli.ps1
```

### Opción 3: Elastic Beanstalk (Recomendado para Producción)
```powershell
# Instalar EB CLI: pip install awsebcli
# Ejecutar script automatizado
.\scripts\inventory-deploy-eb.ps1
```

##  Prerequisitos

### Para todos los enfoques:
- Cuenta AWS activa
- AWS CLI instalado y configurado (`aws configure`)
- PowerShell 5.0+ (Windows)

### Adicional para Elastic Beanstalk:
- EB CLI (`pip install awsebcli`)

##  Comparación de Costos

| Opción | Costo Mensual | Características |
|--------|---------------|-----------------|
| **EC2 Manual** | $8-12 | Máximo control, mantenimiento manual |
| **EC2 + CLI** | $8-12 | Automatización, mantenimiento manual |
| **Elastic Beanstalk** | $25-30 | Auto-scaling, load balancer, monitoreo integrado |

*Precios después de Free Tier (primeros 12 meses gratis para t2.micro)*

## Recomendaciones por Caso de Uso

###  **Aprendizaje/Desarrollo**
**→ EC2 Manual**
- Entender cada componente
- Presupuesto limitado
- Flexibilidad máxima

### 🏢 **Empresa/DevOps**
**→ EC2 con AWS CLI**
- Scripts versionables
- Múltiples entornos
- Control total manteniendo automatización

###  **Startup/Producción**
**→ Elastic Beanstalk**
- Time-to-market rápido
- Escalabilidad automática
- Menos mantenimiento

##  Características de la Aplicación

- **Framework**: Node.js + Express
- **Frontend**: React (servido estáticamente)
- **Base de datos**: SQLite (en memoria)
- **Puerto**: 3001 (configurable via PORT env var)
- **PWA**: Service Worker incluido

##  Diferencias Principales

### EC2 vs Elastic Beanstalk

| Aspecto | EC2 | Elastic Beanstalk |
|---------|-----|------------------|
| **Setup** | Manual/Scripted | Automático |
| **Escalado** | Manual | Automático |
| **Load Balancer** | Configurar manualmente | Incluido |
| **Monitoreo** | CloudWatch manual | Integrado |
| **Actualizaciones** | Zero-downtime manual | Rolling deployments |
| **Costo** | Solo instancia | Instancia + ALB |

## 🛠️ Comandos Útiles

### AWS CLI Básico
```powershell
# Verificar configuración
aws sts get-caller-identity

# Listar instancias EC2
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table

# Terminar instancia
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
```

### Elastic Beanstalk CLI
```powershell
# Estado del entorno
eb status

# Ver logs
eb logs --all

# Desplegar cambios
eb deploy

# Escalar aplicación
eb scale 2

# Abrir en navegador
eb open
```

##  Solución de Problemas

### Problemas Comunes
1. **AWS CLI no configurado**: `aws configure`
2. **Permisos insuficientes**: Verificar políticas IAM
3. **Puerto bloqueado**: Revisar Security Groups
4. **Aplicación no inicia**: Verificar logs con `eb logs` o SSH

### Logs Importantes
- **EC2**: `/var/log/user-data.log`, `~/.pm2/logs/`
- **EB**: `eb logs --all`, `/var/log/eb-engine.log`

## 🧹 Limpieza de Recursos

### EC2
```powershell
aws ec2 terminate-instances --instance-ids <instance-id>
aws ec2 delete-security-group --group-id <sg-id>
aws ec2 delete-key-pair --key-name <key-name>
```

### Elastic Beanstalk
```powershell
eb terminate <env-name>
aws elasticbeanstalk delete-application --application-name <app-name>
```

---

