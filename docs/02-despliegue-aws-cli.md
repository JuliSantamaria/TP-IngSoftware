# Despliegue con AWS CLI

## 2. DESPLIEGUE CON AWS CLI (EC2)

### Prerequisitos

#### Instalación de AWS CLI

**Windows (PowerShell como administrador):**
```powershell
# Descargar e instalar AWS CLI v2
$url = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$output = "$env:TEMP\AWSCLIV2.msi"
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $output /quiet" -Wait

# Verificar instalación
aws --version
```

#### Configuración de credenciales

```powershell
# Configurar credenciales AWS
aws configure
# AWS Access Key ID [None]: TU_ACCESS_KEY
# AWS Secret Access Key [None]: TU_SECRET_KEY
# Default region name [None]: us-east-1
# Default output format [None]: json

# Verificar configuración
aws sts get-caller-identity
```

### Paso 1: Crear Security Group

```powershell
# Crear Security Group
$sg_id = aws ec2 create-security-group `
  --group-name inventory-app-sg `
  --description "Security group for inventory application" `
  --query 'GroupId' --output text

Write-Host "Security Group creado: $sg_id"

# Agregar reglas de entrada
aws ec2 authorize-security-group-ingress `
  --group-id $sg_id `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress `
  --group-id $sg_id `
  --protocol tcp `
  --port 80 `
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress `
  --group-id $sg_id `
  --protocol tcp `
  --port 3001 `
  --cidr 0.0.0.0/0

Write-Host "Reglas de Security Group configuradas"
```

### Paso 2: Crear Key Pair (si no existe)

```powershell
# Crear nueva key pair
aws ec2 create-key-pair `
  --key-name inventory-app-key `
  --query 'KeyMaterial' `
  --output text > inventory-app-key.pem

# En sistemas Unix-like, cambiar permisos:
# chmod 400 inventory-app-key.pem

Write-Host "Key pair creada: inventory-app-key.pem"
```

### Paso 3: Crear script User Data

```powershell
# Crear script de User Data
$userData = @"
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Iniciando configuración automática ==="

# Actualizar sistema
dnf update -y

# Instalar Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs git

# Verificar instalación
echo "Node version: `$(node --version)`"
echo "NPM version: `$(npm --version)`"

# Instalar PM2 para gestión de procesos
npm install -g pm2

# Crear directorio de aplicación
mkdir -p /home/ec2-user/inventory-app
chown ec2-user:ec2-user /home/ec2-user/inventory-app

echo "=== Configuración inicial completada ==="
echo "Siguiente: subir código de aplicación y ejecutar npm install"
"@

# Codificar en base64 para User Data
$userDataBytes = [System.Text.Encoding]::UTF8.GetBytes($userData)
$userDataBase64 = [System.Convert]::ToBase64String($userDataBytes)

# Guardar en archivo
$userData | Out-File -FilePath "user-data.sh" -Encoding utf8
Write-Host "Script User Data creado: user-data.sh"
```

### Paso 4: Lanzar instancia EC2

```powershell
# Obtener AMI ID más reciente de Amazon Linux 2023
$amiId = aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" `
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' `
  --output text

Write-Host "AMI seleccionada: $amiId"

# Lanzar instancia
$instanceId = aws ec2 run-instances `
  --image-id $amiId `
  --count 1 `
  --instance-type t2.micro `
  --key-name inventory-app-key `
  --security-group-ids $sg_id `
  --user-data $userDataBase64 `
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=inventory-app-server}]' `
  --query 'Instances[0].InstanceId' `
  --output text

Write-Host "Instancia lanzada: $instanceId"
```

### Paso 5: Esperar y obtener IP pública

```powershell
# Esperar a que la instancia esté corriendo
Write-Host "Esperando que la instancia esté en estado 'running'..."
aws ec2 wait instance-running --instance-ids $instanceId

# Obtener IP pública
$publicIp = aws ec2 describe-instances `
  --instance-ids $instanceId `
  --query 'Reservations[0].Instances[0].PublicIpAddress' `
  --output text

Write-Host "IP pública de la instancia: $publicIp"
Write-Host "Esperando a que la configuración inicial termine (aprox. 5 minutos)..."
Start-Sleep -Seconds 300
```

### Paso 6: Desplegar aplicación

```powershell
# Crear archivo ZIP con el código de la aplicación
Compress-Archive -Path ".\server.js", ".\package.json", ".\public\*" -DestinationPath "inventory-app.zip" -Force

# Subir y desplegar aplicación via SSH
$sshCommand = @"
# Subir archivo
scp -i inventory-app-key.pem -o StrictHostKeyChecking=no inventory-app.zip ec2-user@${publicIp}:/home/ec2-user/

# Conectar y configurar
ssh -i inventory-app-key.pem -o StrictHostKeyChecking=no ec2-user@${publicIp} << 'ENDSSH'
cd /home/ec2-user/inventory-app
unzip -o /home/ec2-user/inventory-app.zip
npm install
pm2 start server.js --name inventory-app
pm2 startup
pm2 save
pm2 list
echo "Aplicación desplegada en: http://${publicIp}:3001"
ENDSSH
"@

Write-Host "Ejecutar los siguientes comandos manualmente:"
Write-Host $sshCommand
```

### Paso 7: Configurar Nginx (opcional)

```powershell
# Script adicional para configurar Nginx como proxy reverso
$nginxSetup = @"
ssh -i inventory-app-key.pem ec2-user@${publicIp} << 'ENDSSH'
# Instalar Nginx
sudo dnf install -y nginx

# Configurar proxy reverso
sudo tee /etc/nginx/conf.d/inventory.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Iniciar Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

echo "Nginx configurado. Aplicación disponible en: http://${publicIp}"
ENDSSH
"@

Write-Host "Para configurar Nginx (acceso por puerto 80):"
Write-Host $nginxSetup
```

### Paso 8: Verificación del despliegue

```powershell
# Verificar que la aplicación está respondiendo
Write-Host "Verificando despliegue..."
try {
    $response = Invoke-WebRequest -Uri "http://${publicIp}:3001" -UseBasicParsing
    Write-Host " Aplicación respondiendo correctamente"
    Write-Host " URL: http://${publicIp}:3001"
} catch {
    Write-Host " Error al acceder a la aplicación"
    Write-Host "Verifica manualmente: http://${publicIp}:3001"
}
```


5. **Sin interfaz gráfica**: Ideal para entornos de producción y automatización
