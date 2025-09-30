# Guía de Despliegue en AWS - Aplicación de Inventario

Esta aplicación es una PWA (Progressive Web App) desarrollada en Node.js con Express que incluye:
- **Backend**: API REST con Express y SQLite
- **Frontend**: React con Tailwind CSS (servido estáticamente)
- **Puerto**: 3001 (configurable via variable de entorno PORT)
- **Dependencias**: express, cors, sqlite3

## 1. DESPLIEGUE MANUAL EN EC2

### 1.1 Versión Manual Completa

#### Paso 1: Crear instancia EC2 en la consola AWS

1. **Acceder a la consola de AWS** y navegar a EC2
2. **Hacer clic en "Launch Instance"**
3. **Configurar la instancia**:
   - **Name**: `inventory-app-server`
   - **AMI**: Amazon Linux 2023 (Free Tier eligible)
   - **Instance type**: t2.micro (Free Tier)
   - **Key pair**: Crear o seleccionar una key pair existente
   - **Security Group**: Crear nuevo grupo con las siguientes reglas:
     ```
     SSH (22)    - Tu IP o 0.0.0.0/0
     HTTP (80)   - 0.0.0.0/0
     Custom (3001) - 0.0.0.0/0 (puerto de la aplicación)
     ```

#### Paso 2: Conectar a la instancia

```bash
# Windows (PowerShell) - Ajusta la ruta de tu key pair
ssh -i "tu-key.pem" ec2-user@tu-ip-publica-ec2
```

#### Paso 3: Instalar dependencias del sistema

```bash
# Actualizar el sistema
sudo dnf update -y

# Instalar Node.js y npm
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo dnf install -y nodejs

# Verificar instalación
node --version
npm --version

# Instalar Git para clonar el repositorio
sudo dnf install -y git

# Instalar herramientas de desarrollo (para compilar módulos nativos)
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y python3-pip
```

#### Paso 4: Desplegar la aplicación

```bash
# Crear directorio para la aplicación
mkdir -p /home/ec2-user/inventory-app
cd /home/ec2-user/inventory-app

# Opción 1: Clonar desde Git (si tienes repositorio)
git clone https://github.com/tu-usuario/inventory.git .

# Opción 2: Subir archivos manualmente
# Usar scp desde tu máquina local:
# scp -i "tu-key.pem" -r ./inventory/* ec2-user@tu-ip-publica:/home/ec2-user/inventory-app/
```

#### Paso 5: Configurar la aplicación

```bash
# Instalar dependencias de Node.js
npm install

# Configurar variables de entorno (opcional)
export PORT=3001

# Verificar que todos los archivos están presentes
ls -la
```

#### Paso 6: Ejecutar la aplicación

```bash
# Opción 1: Ejecución directa (para pruebas)
node server.js

# Opción 2: Usar PM2 para gestión de procesos (recomendado)
sudo npm install -g pm2
pm2 start server.js --name "inventory-app"
pm2 startup
pm2 save
```

#### Paso 7: Configurar proxy reverso con Nginx (opcional)

```bash
# Instalar Nginx
sudo dnf install -y nginx

# Crear configuración
sudo tee /etc/nginx/conf.d/inventory.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Iniciar y habilitar Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Paso 8: Verificar despliegue

```bash
# Verificar que la aplicación está corriendo
curl http://localhost:3001

# Verificar desde navegador web
# http://tu-ip-publica-ec2:3001
```

### 1.2 Versión con User Data (Automatización Inicial)

#### Script User Data para automatizar la instalación

Al crear la instancia EC2, en la sección "Advanced Details" > "User data", pegar el siguiente script:

```bash
#!/bin/bash
# Log de ejecución
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Iniciando configuración automática..."

# Actualizar sistema
dnf update -y

# Instalar Node.js 18.x
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Instalar herramientas de desarrollo
dnf groupinstall -y "Development Tools"
dnf install -y git python3-pip nginx

# Crear usuario para la aplicación
useradd -m appuser

# Crear directorio de aplicación
mkdir -p /home/appuser/inventory-app
chown appuser:appuser /home/appuser/inventory-app

# Instalar PM2 globalmente
npm install -g pm2

# Crear archivo de servicio para la aplicación
cat << 'EOF' > /home/appuser/inventory-app/package.json
{
  "name": "inventory-pwa-demo",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^5.1.0",
    "sqlite3": "^5.1.7"
  }
}
EOF

# Nota: Los archivos de la aplicación deben subirse después del lanzamiento
echo "Configuración inicial completada. Subir archivos de aplicación y ejecutar npm install."
echo "Para completar: cd /home/appuser/inventory-app && npm install && pm2 start server.js"
```

#### Pasos posteriores al lanzamiento con User Data

```bash
# Conectar via SSH
ssh -i "tu-key.pem" ec2-user@tu-ip-publica

# Subir archivos de aplicación (desde tu máquina local)
scp -i "tu-key.pem" -r ./inventory/* ec2-user@tu-ip-publica:/tmp/

# En la instancia EC2, mover archivos y finalizar configuración
sudo cp -r /tmp/* /home/appuser/inventory-app/
sudo chown -R appuser:appuser /home/appuser/inventory-app
cd /home/appuser/inventory-app
sudo -u appuser npm install
sudo -u appuser pm2 start server.js --name inventory-app
```

