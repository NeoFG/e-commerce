#!/bin/bash

# Script de configuración de firewall para servidor e-commerce 
# Autor: Kory David Ortega Hernández

# Verifica si se está ejecutando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root." 
   exit 1
fi

echo "Iniciando configuración del firewall..."

# Habilitar e iniciar firewalld
echo "Habilitando firewalld..."
systemctl enable --now firewalld

# Establecer zona por defecto
echo "Configurando zona predeterminada a 'public'..."
firewall-cmd --set-default-zone=public

# Eliminar servicios innecesarios
echo "Eliminando servicios innecesarios..."
for svc in dhcpv6-client samba mountd nfs rpc-bind; do
  firewall-cmd --permanent --remove-service=$svc 2>/dev/null
done

# Agregar servicios permitidos
echo "Agregando servicios permitidos (HTTP, HTTPS, SSH, FTP)..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=ftp


# Recargar configuración
echo "Recargando firewall..."
firewall-cmd --reload

# Mostrar reglas actuales
echo "Configuración actual del firewall:"
firewall-cmd --list-all

echo "¡Firewall configurado correctamente con FTP habilitado!"

