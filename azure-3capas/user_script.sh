#!/bin/bash

# Este script instala Apache2, PostgreSQL y el agente Amazon SSM en Ubuntu 22.04.
# Además, asegura que el SSM Agent se inicie automáticamente.

# Actualizar los paquetes existentes
sudo apt update -y

# Instalar el Amazon SSM Agent 
sudo snap install amazon-ssm-agent --classic

# Iniciar y habilitar el servicio del SSM Agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl restart snapd
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Instalar Apache2 y PostgreSQL
sudo apt install apache2 postgresql -y

# Instalar postgresql-client para conectarnos a la base de datos
sudo apt install postgresql-client -y

# Habilitar y verificar Apache2
sudo systemctl enable apache2
sudo systemctl start apache2

# Permitir tráfico en el puerto 80 si se está usando UFW (Firewall de Ubuntu)
sudo ufw allow 80/tcp

# Crear un archivo para indicar que el script se ejecutó correctamente
touch /home/ubuntu/my_shell_script_did_things
