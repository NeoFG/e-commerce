#!/bin/bash

# ======== FUNCIONES Implementadas =========

# Verificado si el script se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

function detectar_ip() {
  IP_LOCAL=$(ip -4 addr show | grep -v 127.0.0.1 | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
  IP_INVERSA=$(echo "$IP_LOCAL" | awk -F. '{print $3"."$2"."$1}')
  ULT_OCTETO=$(echo "$IP_LOCAL" | awk -F. '{print $4}')
}

function instalar_http() {
  echo "➡ Verificando si Apache ya está instalado..."
  if rpm -q httpd > /dev/null 2>&1; then
    echo "✅ Apache ya está instalado."
  else
    echo "➡ Instalando Apache..."
    dnf install -y httpd
    systemctl enable httpd
    systemctl start httpd
    echo "✅ Apache instalado y en ejecución."
  fi

  echo "🧱 Abriendo puertos HTTP..."
  firewall-cmd --permanent --add-service=http
  firewall-cmd --reload

  echo "✅ Apache configurado correctamente."
}

function instalar_dns() {
  echo "➡ Verificando si Bind ya está instalado..."
  if rpm -q bind > /dev/null 2>&1; then
    echo "✅ Bind DNS ya está instalado."
  else
    echo "📦 Instalando Bind DNS..."
    dnf install -y bind bind-chroot bind-utils
  fi

  systemctl enable named
  systemctl start named

  echo "📡 Detectando IP local..."
  IP_LOCAL=$(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+' | head -n 1)
  IP_OCTET3=$(echo $IP_LOCAL | cut -d '.' -f3)
  IP_OCTET4=$(echo $IP_LOCAL | cut -d '.' -f4)
  IP_INVERSA="${IP_OCTET3}.168.192"

  echo "🧠 IP detectada: $IP_LOCAL"
  echo "🔁 IP inversa generada: $IP_INVERSA"

  # Copia de seguridad
  cp /etc/named.conf /etc/named.resp

  echo "✍️ Configurando /etc/named.conf"
  cat <<EOF > /etc/named.conf
options {
    listen-on port 53 { 127.0.0.1; $IP_LOCAL; };
    directory "/var/named";
    allow-query { any; };
    recursion yes;
};

zone "tiendavirtual.local" IN {
    type master;
    file "tiendavirtual.local.db";
    allow-update { none; };
    allow-query { any; };
};

zone "$IP_INVERSA.in-addr.arpa" IN {
    type master;
    file "tiendavirtual.local.rev";
    allow-update { none; };
    allow-query { any; };
};
EOF

  echo "📁 Archivo de zona directa..."
  cat <<EOF > /var/named/tiendavirtual.local.db
\$TTL 86400
@ IN SOA dns-primary.tiendavirtual.local. admin.tiendavirtual.local. (
    2020011800 ;Serial
    3600 ;Refresh
    1800 ;Retry
    604800 ;Expire
    86400 ;Minimum TTL
)
@ IN NS dns-primary.tiendavirtual.local.
dns-primary IN A $IP_LOCAL
www IN A 192.168.${IP_OCTET3}.25
mail IN A 192.168.${IP_OCTET3}.26
EOF

  echo "📁 Archivo de zona inversa..."
  cat <<EOF > /var/named/tiendavirtual.local.rev
\$TTL 86400
@ IN SOA dns-primary.tiendavirtual.local. admin.tiendavirtual.local. (
    2020011800 ;Serial
    3600 ;Refresh
    1800 ;Retry
    604800 ;Expire
    86400 ;Minimum TTL
)
@ IN NS dns-primary.tiendavirtual.local.
${IP_OCTET4} IN PTR dns-primary.tiendavirtual.local.
25 IN PTR www.tiendavirtual.local.
26 IN PTR mail.tiendavirtual.local.
EOF

  chown named:named /var/named/tiendavirtual.local.*

  echo "🧪 Verificando configuración DNS..."
  named-checkconf
  named-checkzone tiendavirtual.local /var/named/tiendavirtual.local.db
  named-checkzone $IP_INVERSA.in-addr.arpa /var/named/tiendavirtual.local.rev

  systemctl restart named

  echo "🧱 Abriendo puertos DNS..."
  firewall-cmd --permanent --add-port=53/tcp
  firewall-cmd --permanent --add-port=53/udp
  firewall-cmd --reload

  echo "⚙️ Configurando resolv.conf para usar $IP_LOCAL como DNS"
  echo "nameserver $IP_LOCAL" > /etc/resolv.conf

  echo "♻️ Reiniciando red..."
  if systemctl is-active --quiet NetworkManager; then
    systemctl restart NetworkManager
  elif systemctl is-active --quiet network; then
    systemctl restart network
  else
    echo "⚠️ No se encontró un servicio de red activo para reiniciar."
  fi

  echo "🔎 Verificando con nslookup:"
  echo "--------------------------------------------------"
  nslookup dns-primary.tiendavirtual.local
  nslookup www.tiendavirtual.local
  nslookup mail.tiendavirtual.local
  nslookup 192.168.${IP_OCTET3}.25
  echo "--------------------------------------------------"

  echo "✅ DNS tiendavirtual.local verificado correctamente."
}

function instalar_smtpYpop3(){
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
}

function configurar_firewall() {
  echo "⚙️ Ejecutando el script de configuración del firewall..."
  # Ejecuta el script Firewall2.sh
  ./Firewall2.sh
  echo "✅ Configuración del firewall completada."
}

function menu() {
  clear
  echo "========= MENÚ DE CONFIGURACIÓN DEL SERVIDOR ========="
  echo "1. Instalar HTTP"
  echo "2. Instalar DNS "
  echo "3. Instalar POP3 y SMTP "
  echo "4. Instalar Nagios (pendiente)"
  echo "5. Firewall"
  echo "6. Salir"
  echo "======================================================="
  read -p "Selecciona una opción: " opcion

  case $opcion in
    1) instalar_http ;;
    2) instalar_dns ;;
    3) instalar_smtpYpop3;;
    4) echo "⚠ Nagios aún no implementado." ;;
    5) configurar_firewall ;;
    6) echo "👋 Saliendo. ¡Gracias!" ; exit 0 ;;
    *) echo "❌ Opción inválida. Intenta nuevamente." ;;
  esac
}

# ======= EJECUCIÓN =========

while true; do
  menu
  read -p "¿Deseas volver al menú? (s/n): " continuar
  [[ "$continuar" != "s" ]] && break
done
