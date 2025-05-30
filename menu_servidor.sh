#!/bin/bash

# ========= MENÚ DE CONFIGURACIÓN DEL SERVIDOR E-COMMERCE =========

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

  echo "🔒 Verificando si mod_ssl está instalado..."
  if rpm -q mod_ssl > /dev/null 2>&1; then
    echo "✅ mod_ssl ya está instalado."
  else
    echo "➡ Instalando mod_ssl y openssl..."
    dnf install -y mod_ssl openssl
  fi

  echo "🔐 Generando certificados autofirmados..."
  mkdir -p /etc/pki/tls/{certs,private}
  openssl genrsa -out /etc/pki/tls/private/ca.key 2048
  openssl req -new -key /etc/pki/tls/private/ca.key -out /etc/pki/tls/private/ca.csr -subj "/C=MX/ST=Puebla/L=Puebla/O=Tiendavirtual/CN=tiendavirtual.local"
  openssl x509 -req -days 365 -in /etc/pki/tls/private/ca.csr -signkey /etc/pki/tls/private/ca.key -out /etc/pki/tls/certs/ca.crt

  echo "🛠️ Configurando SSL de Apache..."
  sed -i 's|^SSLCertificateFile.*|SSLCertificateFile /etc/pki/tls/certs/ca.crt|' /etc/httpd/conf.d/ssl.conf
  sed -i 's|^SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/pki/tls/private/ca.key|' /etc/httpd/conf.d/ssl.conf

  echo "🔁 Reiniciando Apache..."
  systemctl restart httpd

  echo "🧱 Abriendo puertos HTTP/HTTPS..."
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload

  echo "✅ Apache + HTTPS configurado correctamente."
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
  systemctl restart NetworkManager

  echo "🔎 Verificando con nslookup:"
  echo "--------------------------------------------------"
  nslookup dns-primary.tiendavirtual.local
  nslookup www.tiendavirtual.local
  nslookup mail.tiendavirtual.local
  nslookup 192.168.${IP_OCTET3}.25
  echo "--------------------------------------------------"

  echo "✅ DNS tiendavirtual.local verificado correctamente."
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
  echo "1. Instalar HTTP (Apache + HTTPS)"
  echo "2. Instalar DNS (Bind dinámico)"
  echo "3. Instalar POP3 (pendiente)"
  echo "4. Instalar SMTP (pendiente)"
  echo "5. Instalar Nagios (pendiente)"
  echo "6. Configurar Firewall"
  echo "7. Salir"
  echo "======================================================="
  read -p "Selecciona una opción: " opcion

  case $opcion in
    1) instalar_http ;;
    2) instalar_dns ;;
    3) echo "⚠ POP3 aún no implementado." ;;
    4) echo "⚠ SMTP aún no implementado." ;;
    5) echo "⚠ Nagios aún no implementado." ;;
    6) configurar_firewall ;;
    7) echo "👋 Saliendo. ¡Gracias!" ; exit 0 ;;
    *) echo "❌ Opción inválida. Intenta nuevamente." ;;
  esac
}

while true; do
  menu
  read -p "¿Deseas volver al menú? (s/n): " continuar
  [[ "$continuar" != "s" ]] && break
done
  
    
