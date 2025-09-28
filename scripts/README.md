# Scripts de Despliegue para Inventory App

Este directorio contiene scripts automatizados para diferentes tipos de despliegue en AWS.

## Archivos incluidos

### PowerShell Scripts (Windows)
- `deploy-ec2-manual.ps1` - Script para despliegue manual guiado en EC2
- `deploy-ec2-cli.ps1` - Script completamente automatizado usando AWS CLI
- `deploy-elastic-beanstalk.ps1` - Script para despliegue en Elastic Beanstalk

### User Data Scripts
- `user-data.sh` - Script de inicialización automática para EC2

## Uso

### Prerequisitos
1. AWS CLI instalado y configurado
2. PowerShell 5.0+ (Windows)
3. Credenciales AWS configuradas (`aws configure`)

### Ejecución
```powershell
# Hacer ejecutable (si es necesario)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Ejecutar script deseado
.\scripts\deploy-ec2-cli.ps1
.\scripts\deploy-elastic-beanstalk.ps1
```

## Notas
- Los scripts están configurados para la región us-east-1 por defecto
- Modifica las variables al inicio de cada script según tus necesidades
- Revisa los costos estimados antes de ejecutar