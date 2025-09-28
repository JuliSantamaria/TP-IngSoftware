# Script de Despliegue Elastic Beanstalk
# inventory-deploy-eb.ps1

param(
    [string]$AppName = "inventory-app",
    [string]$EnvName = "inventory-dev", 
    [string]$Region = "us-east-1",
    [string]$Platform = "64bit Amazon Linux 2023 v6.1.0 running Node.js 18"
)

Write-Host "🚀 Iniciando despliegue en AWS Elastic Beanstalk" -ForegroundColor Green
Write-Host "Parámetros:" -ForegroundColor Yellow
Write-Host "  - App Name: $AppName"
Write-Host "  - Environment: $EnvName"
Write-Host "  - Region: $Region"

try {
    # Verificar prerequisitos
    Write-Host "`n🔍 Verificando prerequisitos..." -ForegroundColor Blue
    
    # Verificar AWS CLI
    $awsVersion = aws --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI no está instalado. Instala desde: https://aws.amazon.com/cli/"
    }
    Write-Host "✅ AWS CLI disponible" -ForegroundColor Green
    
    # Verificar EB CLI
    $ebVersion = eb --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ EB CLI no está instalado" -ForegroundColor Red
        Write-Host "Instalar con: pip install awsebcli" -ForegroundColor Yellow
        throw "EB CLI requerido"
    }
    Write-Host "✅ EB CLI disponible: $ebVersion" -ForegroundColor Green
    
    # Verificar configuración AWS
    $awsIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if (-not $awsIdentity) {
        throw "AWS CLI no está configurado. Ejecuta 'aws configure'"
    }
    Write-Host "✅ AWS configurado para: $($awsIdentity.Arn)" -ForegroundColor Green
    
    # Verificar archivos necesarios
    $requiredFiles = @("server.js", "package.json")
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Archivo requerido no encontrado: $file"
        }
    }
    Write-Host "✅ Archivos de aplicación presentes" -ForegroundColor Green
    
    # 1. Crear configuraciones de EB si no existen
    Write-Host "`n📝 Preparando configuración Elastic Beanstalk..." -ForegroundColor Blue
    
    if (-not (Test-Path ".ebextensions")) {
        New-Item -ItemType Directory -Path ".ebextensions" -Force | Out-Null
        Write-Host "✅ Directorio .ebextensions creado" -ForegroundColor Green
    }
    
    # Crear configuración Node.js
    $nodeConfig = @"
option_settings:
  aws:elasticbeanstalk:container:nodejs:
    NodeCommand: "npm start"
  aws:elasticbeanstalk:application:environment:
    PORT: 8080
    NODE_ENV: production
  aws:autoscaling:launchconfiguration:
    InstanceType: t2.micro
  aws:ec2:instances:
    InstanceTypes: t2.micro
"@
    
    $nodeConfig | Out-File -FilePath ".ebextensions\01-nodejs.config" -Encoding utf8
    Write-Host "✅ Configuración Node.js creada" -ForegroundColor Green
    
    # Crear configuración de proxy
    $proxyConfig = @"
option_settings:
  aws:elasticbeanstalk:environment:proxy:staticfiles:
    /public: public
  aws:elasticbeanstalk:container:nodejs:
    ProxyServer: nginx
"@
    
    $proxyConfig | Out-File -FilePath ".ebextensions\02-proxy.config" -Encoding utf8
    Write-Host "✅ Configuración de proxy creada" -ForegroundColor Green
    
    # 2. Inicializar aplicación EB (si no existe)
    Write-Host "`n🏗️ Inicializando aplicación Elastic Beanstalk..." -ForegroundColor Blue
    
    if (-not (Test-Path ".elasticbeanstalk")) {
        # Crear configuración inicial
        $ebConfig = @"
branch-defaults:
  main:
    environment: $EnvName
global:
  application_name: $AppName
  default_region: $Region
  default_platform: $Platform
  profile: default
  sc: git
"@
        
        New-Item -ItemType Directory -Path ".elasticbeanstalk" -Force | Out-Null
        $ebConfig | Out-File -FilePath ".elasticbeanstalk\config.yml" -Encoding utf8
        
        Write-Host "✅ Configuración EB inicializada" -ForegroundColor Green
    } else {
        Write-Host "✅ Configuración EB ya existe" -ForegroundColor Green
    }
    
    # 3. Crear aplicación en AWS (si no existe)
    Write-Host "`n🌟 Creando aplicación en AWS..." -ForegroundColor Blue
    
    $existingApp = aws elasticbeanstalk describe-applications --application-names $AppName --query 'Applications[0].ApplicationName' --output text 2>$null
    
    if ($existingApp -eq "None" -or $LASTEXITCODE -ne 0) {
        aws elasticbeanstalk create-application --application-name $AppName --description "Inventory PWA Demo Application"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error creando aplicación en Elastic Beanstalk"
        }
        Write-Host "✅ Aplicación '$AppName' creada en AWS" -ForegroundColor Green
    } else {
        Write-Host "✅ Aplicación '$AppName' ya existe" -ForegroundColor Green
    }
    
    # 4. Crear entorno
    Write-Host "`n🌍 Creando entorno de aplicación..." -ForegroundColor Blue
    Write-Host "   Esto puede tomar 5-10 minutos..." -ForegroundColor Yellow
    
    $existingEnv = aws elasticbeanstalk describe-environments --environment-names $EnvName --query 'Environments[0].EnvironmentName' --output text 2>$null
    
    if ($existingEnv -eq "None" -or $LASTEXITCODE -ne 0) {
        # Crear entorno nuevo
        eb create $EnvName --platform "$Platform" --instance-type t2.micro --cname $EnvName-$([System.Guid]::NewGuid().ToString().Substring(0,8))
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error creando entorno en Elastic Beanstalk"
        }
        Write-Host "✅ Entorno '$EnvName' creado y desplegado" -ForegroundColor Green
    } else {
        Write-Host "✅ Entorno '$EnvName' ya existe, desplegando cambios..." -ForegroundColor Green
        eb deploy $EnvName
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error desplegando a entorno existente"
        }
    }
    
    # 5. Obtener información del despliegue
    Write-Host "`n📊 Obteniendo información del despliegue..." -ForegroundColor Blue
    
    $envInfo = eb status --verbose 2>$null
    $envUrl = ($envInfo | Select-String "CNAME:" | ForEach-Object { $_.ToString().Split(":")[1].Trim() })
    
    if (-not $envUrl) {
        # Intentar obtener URL de otra manera
        $envUrl = aws elasticbeanstalk describe-environments --environment-names $EnvName --query 'Environments[0].CNAME' --output text
    }
    
    # 6. Verificar el despliegue
    Write-Host "`n🔍 Verificando despliegue..." -ForegroundColor Blue
    Start-Sleep -Seconds 30  # Esperar a que la aplicación esté lista
    
    try {
        $response = Invoke-WebRequest -Uri "http://$envUrl" -UseBasicParsing -TimeoutSec 10
        Write-Host "✅ Aplicación respondiendo correctamente" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Aplicación puede estar iniciando aún..." -ForegroundColor Yellow
        Write-Host "   Verifica manualmente en unos minutos" -ForegroundColor Yellow
    }
    
    # 7. Mostrar información final
    Write-Host "`n🎉 Despliegue completado exitosamente!" -ForegroundColor Green
    
    Write-Host "`n📋 Información del despliegue:" -ForegroundColor Cyan
    Write-Host "   Aplicación: $AppName"
    Write-Host "   Entorno: $EnvName"
    Write-Host "   URL: http://$envUrl"
    Write-Host "   Región: $Region"
    
    Write-Host "`n🔗 Enlaces útiles:" -ForegroundColor Cyan
    Write-Host "   Aplicación: http://$envUrl"
    Write-Host "   Consola EB: https://console.aws.amazon.com/elasticbeanstalk/"
    Write-Host "   Logs: eb logs --all"
    
    Write-Host "`n⚡ Comandos útiles:" -ForegroundColor Yellow
    Write-Host "   Ver estado: eb status"
    Write-Host "   Ver logs: eb logs"
    Write-Host "   Desplegar cambios: eb deploy"
    Write-Host "   Abrir en navegador: eb open"
    Write-Host "   Escalar: eb scale 2"
    Write-Host "   SSH a instancia: eb ssh"
    
    Write-Host "`n💰 Costos estimados mensuales:" -ForegroundColor Magenta
    Write-Host "   - Instancia t2.micro: `$0 (Free Tier) o `$8.50"
    Write-Host "   - Application Load Balancer: `$16"
    Write-Host "   - Total estimado: `$16-25/mes"
    
    Write-Host "`n🧹 Para eliminar recursos:" -ForegroundColor Red
    Write-Host "   eb terminate $EnvName"
    Write-Host "   aws elasticbeanstalk delete-application --application-name $AppName"
    
} catch {
    Write-Host "`n❌ Error durante el despliegue:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    Write-Host "`n🔧 Solución de problemas:" -ForegroundColor Yellow
    Write-Host "1. Verificar que AWS CLI esté configurado: aws sts get-caller-identity"
    Write-Host "2. Verificar que EB CLI esté instalado: eb --version"
    Write-Host "3. Ver logs detallados: eb logs --all"
    Write-Host "4. Verificar permisos IAM para Elastic Beanstalk"
    
    exit 1
}

Write-Host "`n🎯 ¡Aplicación desplegada en Elastic Beanstalk!" -ForegroundColor Green
Write-Host "🌐 Accede a tu aplicación en: http://$envUrl" -ForegroundColor Cyan