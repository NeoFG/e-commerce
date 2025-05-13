#!/bin/bash

# Verificado si el script se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

echo "Actualizando los repositorios..."
dnf update -y

echo "Instalando Postfix..."
dnf install -y postfix

echo "Habilitando y arrancando el servicio de Postfix..."
systemctl enable postfix
systemctl start postfix

echo "Configurando Postfix..."

# Configurar inet_interfaces
if grep -q "^inet_interfaces = all" /etc/postfix/main.cf; then
    echo "inet_interfaces ya está configurado y activo."
else
    # Comentar cualquier otra configuración de inet_interfaces
    sed -i 's/^inet_interfaces =/#&/' /etc/postfix/main.cf
    sed -i 's/^#inet_interfaces = all/inet_interfaces = all/' /etc/postfix/main.cf
    if ! grep -q "^inet_interfaces = all" /etc/postfix/main.cf; then
        echo "inet_interfaces = all" >> /etc/postfix/main.cf
    fi
    echo "inet_interfaces configurado correctamente."
fi

# Configurar mydestination
if grep -q "^mydestination = \$myhostname, localhost.\$mydomain, localhost" /etc/postfix/main.cf; then
    echo "mydestination ya está configurado y activo."
else
    # Comentar cualquier otra configuración de mydestination
    sed -i 's/^mydestination =/#&/' /etc/postfix/main.cf
    sed -i 's/^#mydestination = .*/mydestination = $myhostname, localhost.$mydomain, localhost/' /etc/postfix/main.cf
    if ! grep -q "^mydestination = \$myhostname, localhost.\$mydomain, localhost" /etc/postfix/main.cf; then
        echo "mydestination = \$myhostname, localhost.\$mydomain, localhost" >> /etc/postfix/main.cf
    fi
    echo "mydestination configurado correctamente."
fi

# Configurar relayhost
if grep -q "^relayhost =" /etc/postfix/main.cf; then
    echo "relayhost ya está configurado y activo."
else
    # Comentar cualquier otra configuración de relayhost
    sed -i 's/^relayhost =/#&/' /etc/postfix/main.cf
    sed -i 's/^#relayhost = .*/relayhost =/' /etc/postfix/main.cf
    if ! grep -q "^relayhost =" /etc/postfix/main.cf; then
        echo "relayhost =" >> /etc/postfix/main.cf
    fi
    echo "relayhost configurado correctamente."
fi

# Configurar myhostname
if grep -q "^myhostname = tiendavirtual" /etc/postfix/main.cf; then
    echo "myhostname ya está configurado y activo."
else
    # Comentar cualquier otra configuración de myhostname
    sed -i 's/^myhostname =/#&/' /etc/postfix/main.cf
    sed -i 's/^#myhostname = tiendavirtual/myhostname = tiendavirtual/' /etc/postfix/main.cf
    if ! grep -q "^myhostname = tiendavirtual" /etc/postfix/main.cf; then
        echo "myhostname = tiendavirtual" >> /etc/postfix/main.cf
    fi
    echo "myhostname configurado correctamente."
fi

# Configurar mydomain
if grep -q "^mydomain = tienda-virtual.com" /etc/postfix/main.cf; then
    echo "mydomain ya está configurado y activo."
else
    # Comentar cualquier otra configuración de mydomain
    sed -i 's/^mydomain =/#&/' /etc/postfix/main.cf
    sed -i 's/^#mydomain = tienda-virtual.com/mydomain = tienda-virtual.com/' /etc/postfix/main.cf
    if ! grep -q "^mydomain = tienda-virtual.com" /etc/postfix/main.cf; then
        echo "mydomain = tienda-virtual.com" >> /etc/postfix/main.cf
    fi
    echo "mydomain configurado correctamente."
fi

# Configurar myorigin
if grep -q "^myorigin = \$mydomain" /etc/postfix/main.cf; then
    echo "myorigin ya está configurado y activo."
else
    # Comentar cualquier otra configuración de myorigin
    sed -i 's/^myorigin =/#&/' /etc/postfix/main.cf
    sed -i 's/^#myorigin = \$mydomain/myorigin = \$mydomain/' /etc/postfix/main.cf
    if ! grep -q "^myorigin = \$mydomain" /etc/postfix/main.cf; then
        echo "myorigin = \$mydomain" >> /etc/postfix/main.cf
    fi
    echo "myorigin configurado correctamente."
fi

# Configurar mynetworks
if grep -q "^mynetworks = 192.168.119.129/24, 127.0.0.0/8" /etc/postfix/main.cf; then
    echo "mynetworks ya está configurado y activo."
else
    # Comentar cualquier otra configuración de mynetworks
    sed -i 's/^mynetworks =/#&/' /etc/postfix/main.cf
    sed -i 's/^#mynetworks = 192.168.119.129\/24, 127.0.0.0\/8/mynetworks = 192.168.119.129\/24 127.0.0.0\/8/' /etc/postfix/main.cf
    if ! grep -q "^mynetworks = 192.168.119.129/24, 127.0.0.0/8" /etc/postfix/main.cf; then
        echo "mynetworks = 192.168.119.129/24, 127.0.0.0/8" >> /etc/postfix/main.cf
    fi
    echo "mynetworks configurado correctamente."
fi

# Configurar home_mailbox
if grep -q "^home_mailbox = Maildir/" /etc/postfix/main.cf; then
    echo "home_mailbox ya está configurado y activo."
else
    # Comentar cualquier otra configuración de home_mailbox
    sed -i 's/^home_mailbox =/#&/' /etc/postfix/main.cf
    sed -i 's/^#home_mailbox = Maildir\//home_mailbox = Maildir\//' /etc/postfix/main.cf
    if ! grep -q "^home_mailbox = Maildir/" /etc/postfix/main.cf; then
        echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf
    fi
    echo "home_mailbox configurado correctamente."
fi

echo "Reiniciando el servicio de Postfix para aplicar los cambios..."
systemctl restart postfix

# Permitir el servicio SMTP
firewall-cmd --add-service=smtp --permanent

# Recargar la configuración del firewall
firewall-cmd --reload

echo "Postfix instalado y configurado correctamente."

echo "Creando la estructura de Maildir para el usuario nuevo..."
read -p "Introduce el nombre del usuario: " nuevo_usuario

# Verificar si el usuario existe
if id "$nuevo_usuario" &>/dev/null; then
    echo "El usuario $nuevo_usuario ya existe. Creando la carpeta Maildir..."
    su - "$nuevo_usuario" -c "maildirmake ~/Maildir"
    echo "Estructura de Maildir creada correctamente para $nuevo_usuario."
else
    echo "El usuario $nuevo_usuario no existe. Creándolo..."
    useradd -m "$nuevo_usuario"
    su - "$nuevo_usuario" -c "maildirmake ~/Maildir"
    echo "Usuario $nuevo_usuario creado y estructura de Maildir configurada correctamente."
fi

# Verificar si la carpeta Maildir se creó correctamente
if [ -d "/home/$nuevo_usuario/Maildir" ]; then
    echo "La carpeta Maildir para el usuario $nuevo_usuario se creó correctamente."
else
    echo "Error: No se pudo crear la carpeta Maildir para el usuario $nuevo_usuario."
fi
# Enviar un correo de prueba al usuario
echo "Enviando un correo de prueba al usuario $nuevo_usuario..."
echo "Este es un correo de prueba" | mail -s "Prueba de correo" "$nuevo_usuario"
# Enviar un correo de prueba al usuario
echo "Enviando un correo de prueba al usuario $nuevo_usuario..."
echo "Este es un correo de prueba" | mail -s "Prueba de correo" "$nuevo_usuario"

# Verificar si el correo fue recibido
echo "Verificando si el correo fue recibido..."
if [ -d "/home/$nuevo_usuario/Maildir/new" ]; then
    correos=$(ls /home/$nuevo_usuario/Maildir/new | wc -l)
    if [ "$correos" -gt 0 ]; then
        echo "El correo de prueba fue recibido correctamente. Archivos en Maildir/new:"
        ls /home/$nuevo_usuario/Maildir/new
        # Mostrar el contenido del correo más reciente
        echo "Buscando el correo más reciente..."
        archivo_mas_reciente=$(ls -t /home/$nuevo_usuario/Maildir/new | head -n 1)
        if [ -n "$archivo_mas_reciente" ]; then
            echo "El archivo más reciente es: $archivo_mas_reciente"
            echo "Contenido del archivo más reciente:"
            cat "/home/$nuevo_usuario/Maildir/new/$archivo_mas_reciente"
        else
            echo "No se pudo determinar el archivo más reciente."
        fi
    else
        echo "No se encontraron correos en /home/$nuevo_usuario/Maildir/new."
    fi
else
    echo "Error: La carpeta /home/$nuevo_usuario/Maildir/new no existe."
fi
