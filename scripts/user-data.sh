#!/bin/bash
# User Data Script para EC2 - Inventory App
# Este script se ejecuta automáticamente al iniciar la instancia EC2

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== Iniciando configuración automática de Inventory App ==="

# Actualizar sistema
echo "Actualizando sistema..."
dnf update -y

# Instalar Node.js 18.x
echo "Instalando Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs git

# Verificar instalaciones
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Instalar PM2 para gestión de procesos
echo "Instalando PM2..."
npm install -g pm2

# Crear directorio de aplicación
echo "Configurando directorio de aplicación..."
mkdir -p /home/ec2-user/inventory-app
chown ec2-user:ec2-user /home/ec2-user/inventory-app

# Instalar Nginx para proxy reverso
echo "Instalando Nginx..."
dnf install -y nginx

# Configurar firewall (si está activo)
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=3001/tcp
    firewall-cmd --reload
fi

echo "=== Configuración inicial completada ==="
echo "Siguiente paso: subir código de aplicación y ejecutar:"
echo "  cd /home/ec2-user/inventory-app"
echo "  npm install"
echo "  pm2 start server.js --name inventory-app"
echo "  pm2 startup && pm2 save"