# Script de Despliegue Automatizado EC2 con AWS CLI
# inventory-deploy-cli.ps1

param(
    [string]$KeyName = "inventory-app-key",
    [string]$SecurityGroupName = "inventory-app-sg",
    [string]$InstanceName = "inventory-app-server",
    [string]$Region = "us-east-1",
    [string]$InstanceType = "t2.micro"
)

Write-Host "🚀 Iniciando despliegue automático de Inventory App en EC2" -ForegroundColor Green
Write-Host "Parámetros:" -ForegroundColor Yellow
Write-Host "  - Key Name: $KeyName"
Write-Host "  - Security Group: $SecurityGroupName"
Write-Host "  - Instance Name: $InstanceName"
Write-Host "  - Region: $Region"
Write-Host "  - Instance Type: $InstanceType"

try {
    # Verificar que AWS CLI está configurado
    Write-Host "`n🔍 Verificando configuración AWS CLI..." -ForegroundColor Blue
    $awsIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
    if (-not $awsIdentity) {
        throw "AWS CLI no está configurado. Ejecuta 'aws configure' primero."
    }
    Write-Host "✅ AWS CLI configurado para usuario: $($awsIdentity.Arn)" -ForegroundColor Green

    # 1. Crear Security Group
    Write-Host "`n🛡️ Creando Security Group..." -ForegroundColor Blue
    $sg_id = aws ec2 create-security-group `
        --group-name $SecurityGroupName `
        --description "Security group for inventory app" `
        --query 'GroupId' --output text 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        # El security group puede existir, obtener su ID
        $sg_id = aws ec2 describe-security-groups `
            --group-names $SecurityGroupName `
            --query 'SecurityGroups[0].GroupId' --output text 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "⚠️ Security Group ya existe, usando existente: $sg_id" -ForegroundColor Yellow
        } else {
            throw "Error creando o encontrando Security Group"
        }
    } else {
        Write-Host "✅ Security Group creado: $sg_id" -ForegroundColor Green
    }
    
    # 2. Configurar reglas de seguridad (ignorar errores si ya existen)
    Write-Host "`n🔧 Configurando reglas de Security Group..." -ForegroundColor Blue
    
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 2>$null
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 80 --cidr 0.0.0.0/0 2>$null
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 3001 --cidr 0.0.0.0/0 2>$null
    
    Write-Host "✅ Reglas de Security Group configuradas" -ForegroundColor Green
    
    # 3. Crear Key Pair
    Write-Host "`n🔑 Creando Key Pair..." -ForegroundColor Blue
    
    if (Test-Path "${KeyName}.pem") {
        Write-Host "⚠️ Key pair file ya existe localmente: ${KeyName}.pem" -ForegroundColor Yellow
    } else {
        aws ec2 create-key-pair --key-name $KeyName --query 'KeyMaterial' --output text | Out-File -FilePath "${KeyName}.pem" -Encoding ascii
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Key pair creada: ${KeyName}.pem" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Key pair puede ya existir en AWS, continuando..." -ForegroundColor Yellow
        }
    }
    
    # 4. Obtener AMI más reciente de Amazon Linux 2023
    Write-Host "`n🖥️ Obteniendo AMI más reciente..." -ForegroundColor Blue
    $amiId = aws ec2 describe-images `
        --owners amazon `
        --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" `
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' `
        --output text
    
    Write-Host "✅ AMI seleccionada: $amiId" -ForegroundColor Green
    
    # 5. Crear script User Data (base64)
    Write-Host "`n📝 Preparando script User Data..." -ForegroundColor Blue
    $userData = Get-Content -Path "scripts\user-data.sh" -Raw -ErrorAction SilentlyContinue
    if (-not $userData) {
        Write-Host "⚠️ No se encontró user-data.sh, creando básico..." -ForegroundColor Yellow
        $userData = @"
#!/bin/bash
dnf update -y
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs git
npm install -g pm2
mkdir -p /home/ec2-user/inventory-app
chown ec2-user:ec2-user /home/ec2-user/inventory-app
"@
    }
    
    $userDataBytes = [System.Text.Encoding]::UTF8.GetBytes($userData)
    $userDataBase64 = [System.Convert]::ToBase64String($userDataBytes)
    
    Write-Host "✅ Script User Data preparado" -ForegroundColor Green
    
    # 6. Lanzar instancia
    Write-Host "`n🚀 Lanzando instancia EC2..." -ForegroundColor Blue
    $instanceId = aws ec2 run-instances `
        --image-id $amiId `
        --count 1 `
        --instance-type $InstanceType `
        --key-name $KeyName `
        --security-group-ids $sg_id `
        --user-data $userDataBase64 `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName}]" `
        --query 'Instances[0].InstanceId' `
        --output text
    
    if ($LASTEXITCODE -ne 0 -or -not $instanceId) {
        throw "Error lanzando instancia EC2"
    }
    
    Write-Host "✅ Instancia lanzada: $instanceId" -ForegroundColor Green
    
    # 7. Esperar a que la instancia esté corriendo
    Write-Host "`n⏳ Esperando que la instancia esté en estado 'running'..." -ForegroundColor Blue
    aws ec2 wait instance-running --instance-ids $instanceId
    
    if ($LASTEXITCODE -ne 0) {
        throw "Timeout esperando que la instancia esté corriendo"
    }
    
    # 8. Obtener IP pública
    $publicIp = aws ec2 describe-instances `
        --instance-ids $instanceId `
        --query 'Reservations[0].Instances[0].PublicIpAddress' `
        --output text
    
    Write-Host "✅ Instancia corriendo con IP: $publicIp" -ForegroundColor Green
    
    # 9. Esperar a que la configuración inicial termine
    Write-Host "`n⏳ Esperando configuración inicial (User Data)..." -ForegroundColor Blue
    Write-Host "   Esto puede tomar 3-5 minutos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 180
    
    # 10. Crear archivo ZIP con la aplicación
    Write-Host "`n📦 Creando paquete de aplicación..." -ForegroundColor Blue
    if (Test-Path "inventory-app.zip") {
        Remove-Item "inventory-app.zip" -Force
    }
    
    $filesToInclude = @("server.js", "package.json")
    if (Test-Path "public") {
        $filesToInclude += "public"
    }
    
    Compress-Archive -Path $filesToInclude -DestinationPath "inventory-app.zip" -Force
    Write-Host "✅ Paquete creado: inventory-app.zip" -ForegroundColor Green
    
    # 11. Mostrar instrucciones de despliegue manual
    Write-Host "`n🎉 Infraestructura creada exitosamente!" -ForegroundColor Green
    Write-Host "`n📋 Información de la instancia:" -ForegroundColor Cyan
    Write-Host "   Instance ID: $instanceId"
    Write-Host "   IP Pública: $publicIp"
    Write-Host "   Security Group: $sg_id"
    Write-Host "   Key Pair: ${KeyName}.pem"
    
    Write-Host "`n🔗 URLs de acceso:" -ForegroundColor Cyan
    Write-Host "   Aplicación: http://${publicIp}:3001"
    Write-Host "   SSH: ssh -i ${KeyName}.pem ec2-user@${publicIp}"
    
    Write-Host "`n📝 Siguientes pasos manuales:" -ForegroundColor Yellow
    Write-Host "1. Esperar 2-3 minutos más para que termine la configuración inicial"
    Write-Host "2. Subir y desplegar la aplicación:"
    Write-Host ""
    Write-Host "   # Subir aplicación" -ForegroundColor Gray
    Write-Host "   scp -i ${KeyName}.pem inventory-app.zip ec2-user@${publicIp}:/home/ec2-user/"
    Write-Host ""
    Write-Host "   # Conectar y configurar" -ForegroundColor Gray
    Write-Host "   ssh -i ${KeyName}.pem ec2-user@${publicIp}"
    Write-Host "   cd /home/ec2-user/inventory-app"
    Write-Host "   unzip -o /home/ec2-user/inventory-app.zip"
    Write-Host "   npm install"
    Write-Host "   pm2 start server.js --name inventory-app"
    Write-Host "   pm2 startup && pm2 save"
    Write-Host "   exit"
    Write-Host ""
    Write-Host "3. Verificar: http://${publicIp}:3001"
    
    Write-Host "`n💰 Costos estimados:" -ForegroundColor Magenta
    Write-Host "   - t2.micro: `$0/mes (Free Tier) o `$8.50/mes después"
    Write-Host "   - EBS Storage: `$0.10/GB-mes"
    Write-Host "   - Data Transfer: `$0.09/GB"
    
    Write-Host "`n🧹 Para eliminar recursos después:" -ForegroundColor Red
    Write-Host "   aws ec2 terminate-instances --instance-ids $instanceId"
    Write-Host "   aws ec2 delete-security-group --group-id $sg_id"
    Write-Host "   aws ec2 delete-key-pair --key-name $KeyName"
    
} catch {
    Write-Host "`n❌ Error durante el despliegue:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nPara limpiar recursos parcialmente creados, revisa:" -ForegroundColor Yellow
    Write-Host "- Instancias EC2 en la consola AWS"
    Write-Host "- Security Groups"
    Write-Host "- Key Pairs"
    exit 1
}

Write-Host "`n🎯 Despliegue de infraestructura completado!" -ForegroundColor Green