#!/bin/bash

# Obtener la dirección IP pública del servidor (función)
configurar_smtp_firewall() {
  echo "--- Configuración de SMTP ---"
  ip_servidor=$(curl -s https://api.ipify.org)

  # Validar si se obtuvo una IP
  if [ -n "$ip_servidor" ]; then
    echo "La dirección IP pública de este servidor es: $ip_servidor"

    # Limitar acceso SMTP a la IP del servidor
    sudo firewall-cmd --add-rich-rule="rule family='ipv4' source address='$ip_servidor' service name='smtp' accept" --permanent
    sudo firewall-cmd --remove-service=smtp --permanent # Eliminar la regla general si existe una

    echo "Acceso SMTP permitido solo desde la IP de este servidor ($ip_servidor)."
  else
    echo "No se pudo obtener la dirección IP pública de este servidor."
  fi

  # Permitir SMTPS
  sudo firewall-cmd --add-service=smtps --permanent

  # Permitir Submission
  sudo firewall-cmd --add-port=587/tcp --permanent

  # Recargar la configuración del firewall
  sudo firewall-cmd --reload

  echo "Configuración de SMTP en el firewall completada."
  echo "-----------------------------"
}

# Funciones para mostrar información
mostrar_estado() {
  echo "Estado del Firewall:"
  sudo systemctl status firewalld
}

mostrar_zona_activa() {
  echo "Zona Activa:"
  sudo firewall-cmd --get-active-zones
}

listar_servicios() {
  zona="$1"
  echo "Servicios permitidos en la zona '$zona':"
  sudo firewall-cmd --list-services --zone="$zona"
}

listar_puertos() {
  zona="$1"
  echo "Puertos abiertos en la zona '$zona':"
  sudo firewall-cmd --list-ports --zone="$zona"
}

# Funciones para modificar la configuración
añadir_servicio() {
  servicio="$1"
  zona="$2"
  echo "Añadiendo el servicio '$servicio' a la zona '$zona' (permanentemente)..."
  sudo firewall-cmd --add-service="$servicio" --zone="$zona" --permanent
  sudo firewall-cmd --reload
  echo "Servicio '$servicio' añadido a la zona '$zona'."
}

eliminar_servicio() {
  servicio="$1"
  zona="$2"
  echo "Eliminando el servicio '$servicio' de la zona '$zona' (permanentemente)..."
  sudo firewall-cmd --remove-service="$servicio" --zone="$zona" --permanent
  sudo firewall-cmd --reload
  echo "Servicio '$servicio' eliminado de la zona '$zona'."
}

añadir_puerto() {
  puerto="$1"
  protocolo="$2"
  zona="$3"
  echo "Abriendo el puerto '$puerto/$protocolo' en la zona '$zona' (permanentemente)..."
  sudo firewall-cmd --add-port="$puerto/$protocolo" --zone="$zona" --permanent
  sudo firewall-cmd --reload
  echo "Puerto '$puerto/$protocolo' abierto en la zona '$zona'."
}

eliminar_puerto() {
  puerto="$1"
  protocolo="$2"
  zona="$3"
  echo "Cerrando el puerto '$puerto/$protocolo' en la zona '$zona' (permanentemente)..."
  sudo firewall-cmd --remove-port="$puerto/$protocolo" --zone="$zona" --permanent
  sudo firewall-cmd --reload
  echo "Puerto '$puerto/$protocolo' cerrado en la zona '$zona'."
}

cambiar_zona_interfaz() {
  interfaz="$1"
  nueva_zona="$2"
  echo "Cambiando la interfaz '$interfaz' a la zona '$nueva_zona' (permanentemente)..."
  sudo firewall-cmd --change-interface="$interfaz" --zone="$nueva_zona" --permanent
  sudo firewall-cmd --reload
  echo "Interfaz '$interfaz' ahora en la zona '$nueva_zona'."
}

# Menú principal
mostrar_menu() {
  echo "-----------------------------------------"
  echo "    Configuración de Firewalld"
  echo "-----------------------------------------"
  echo "1. Mostrar estado del firewall"
  echo "2. Mostrar zona activa"
  echo "3. Listar servicios permitidos en una zona"
  echo "4. Listar puertos abiertos en una zona"
  echo "5. Añadir un servicio a una zona"
  echo "6. Eliminar un servicio de una zona"
  echo "7. Añadir un puerto a una zona"
  echo "8. Eliminar un puerto de una zona"
  echo "9. Cambiar la zona de una interfaz"
  echo "10. Recargar configuración del firewall"
  echo "11. Configuración de SMTP"
  echo "0. Salir"
  echo "-----------------------------------------"
  echo "Selecciona una opción:"
}

# Bucle principal del script
while true; do
  mostrar_menu
  read -r opcion

  case "$opcion" in
    1) mostrar_estado ;;
    2) mostrar_zona_activa ;;
    3)
      read -p "Introduce la zona a listar (ej: public, private): " zona_listar
      listar_servicios "$zona_listar"
      ;;
    4)
      read -p "Introduce la zona a listar (ej: public, private): " zona_listar_puertos
      listar_puertos "$zona_listar_puertos"
      ;;
    5)
      read -p "Introduce el servicio a añadir (ej: http, ssh): " servicio_añadir
      read -p "Introduce la zona (ej: public, private): " zona_añadir_servicio
      añadir_servicio "$servicio_añadir" "$zona_añadir_servicio"
      ;;
    6)
      read -p "Introduce el servicio a eliminar (ej: http, ssh): " servicio_eliminar
      read -p "Introduce la zona (ej: public, private): " zona_eliminar_servicio
      eliminar_servicio "$servicio_eliminar" "$zona_eliminar_servicio"
      ;;
    7)
      read -p "Introduce el puerto a abrir (ej: 8080): " puerto_añadir
      read -p "Introduce el protocolo (tcp o udp): " protocolo_añadir
      read -p "Introduce la zona (ej: public, private): " zona_añadir_puerto
      añadir_puerto "$puerto_añadir" "$protocolo_añadir" "$zona_añadir_puerto"
      ;;
    8)
      read -p "Introduce el puerto a cerrar (ej: 8080): " puerto_eliminar
      read -p "Introduce el protocolo (tcp o udp): " protocolo_eliminar
      read -p "Introduce la zona (ej: public, private): " zona_eliminar_puerto
      eliminar_puerto "$puerto_eliminar" "$protocolo_eliminar" "$zona_eliminar_puerto"
      ;;
    9)
      read -p "Introduce la interfaz a cambiar (ej: eth0, wlan0): " interfaz_cambiar
      read -p "Introduce la nueva zona (ej: public, private): " nueva_zona_interfaz
      cambiar_zona_interfaz "$interfaz_cambiar" "$nueva_zona_interfaz"
      ;;
    10)
      echo "Recargando la configuración del firewall..."
      sudo firewall-cmd --reload
      echo "Configuración recargada."
      ;;
    11)
      configurar_smtp_firewall
      ;;
    0)
      echo "Saliendo del script."
      exit 0
      ;;
    *)
      echo "Opción inválida. Por favor, selecciona una opción del menú."
      ;;
  esac
  echo ""
done
