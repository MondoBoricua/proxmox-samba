#!/bin/bash

# 🗂️ Instalador Automático de Samba para Proxmox LXC
# Desarrollado por MondoBoricua para la comunidad de Proxmox
# Versión: 1.0

set -e  # Salir si hay algún error

# Colores para output - pa' que se vea bonito
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables por defecto - puedes cambiarlas aquí
DEFAULT_CTID=200
DEFAULT_HOSTNAME="samba-server"
DEFAULT_PASSWORD="samba123"
DEFAULT_STORAGE="local-lvm"
DEFAULT_DISK_SIZE="4G"
DEFAULT_MEMORY=1024
DEFAULT_CORES=2
DEFAULT_BRIDGE="vmbr0"

# Función para mostrar mensajes con estilo
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Verificar que estamos en Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        print_error "Este script debe ejecutarse en un servidor Proxmox VE"
        print_error "Comando 'pct' no encontrado"
        exit 1
    fi
    
    if ! command -v pvesm &> /dev/null; then
        print_error "Este script debe ejecutarse en un servidor Proxmox VE"
        print_error "Comando 'pvesm' no encontrado"
        exit 1
    fi
    
    print_success "Proxmox VE detectado correctamente"
}

# Verificar que el script se ejecute como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Buscar el mejor template disponible
find_best_template() {
    print_message "Buscando templates disponibles..."
    
    # Buscar templates de Ubuntu y Debian
    TEMPLATE=""
    
    # Prioridad: Ubuntu 22.04, Ubuntu 20.04, Debian 12, Debian 11
    for template_pattern in "ubuntu-22.04" "ubuntu-20.04" "debian-12" "debian-11"; do
        found_template=$(pveam available --section system | grep "$template_pattern" | head -1 | awk '{print $2}' || true)
        if [ -n "$found_template" ]; then
            TEMPLATE="$found_template"
            print_message "Template encontrado: $TEMPLATE"
            break
        fi
    done
    
    # Si no encontramos ninguno, buscar cualquier Ubuntu o Debian
    if [ -z "$TEMPLATE" ]; then
        for template_pattern in "ubuntu" "debian"; do
            found_template=$(pveam available --section system | grep "$template_pattern" | head -1 | awk '{print $2}' || true)
            if [ -n "$found_template" ]; then
                TEMPLATE="$found_template"
                print_message "Template alternativo encontrado: $TEMPLATE"
                break
            fi
        done
    fi
    
    if [ -z "$TEMPLATE" ]; then
        print_error "No se encontró ningún template de Ubuntu o Debian disponible"
        print_error "Ejecuta 'pveam available --section system' para ver templates disponibles"
        exit 1
    fi
    
    # Verificar si el template ya está descargado
    if ! pveam list local | grep -q "$TEMPLATE"; then
        print_message "Descargando template: $TEMPLATE"
        pveam download local "$TEMPLATE"
        print_success "Template descargado exitosamente"
    else
        print_message "Template ya disponible localmente: $TEMPLATE"
    fi
}

# Verificar que el storage existe
check_storage() {
    if ! pvesm status | grep -q "^$STORAGE "; then
        print_error "Storage '$STORAGE' no encontrado"
        print_message "Storages disponibles:"
        pvesm status
        exit 1
    fi
    print_message "Storage '$STORAGE' verificado"
}

# Verificar que el bridge de red existe
check_bridge() {
    if ! ip link show "$BRIDGE" &>/dev/null; then
        print_error "Bridge de red '$BRIDGE' no encontrado"
        print_message "Bridges disponibles:"
        ip link show | grep "^[0-9]" | grep "vmbr\|br"
        exit 1
    fi
    print_message "Bridge de red '$BRIDGE' verificado"
}

# Verificar que el CTID no esté en uso
check_ctid() {
    if pct list | grep -q "^$CTID "; then
        print_error "El contenedor ID $CTID ya existe"
        print_message "Contenedores existentes:"
        pct list
        exit 1
    fi
    print_message "ID de contenedor $CTID disponible"
}

# Solicitar configuración al usuario
get_user_input() {
    print_header "Configuración del Contenedor LXC"
    
    # ID del contenedor
    read -p "ID del contenedor [$DEFAULT_CTID]: " CTID
    CTID=${CTID:-$DEFAULT_CTID}
    
    # Hostname
    read -p "Nombre del contenedor [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    
    # Contraseña
    echo -n "Contraseña root [$DEFAULT_PASSWORD]: "
    read -s PASSWORD_INPUT
    echo
    PASSWORD=${PASSWORD_INPUT:-$DEFAULT_PASSWORD}
    
    # Storage
    echo
    print_message "Storages disponibles:"
    pvesm status | grep -v "^Type" | awk '{print "  - " $1 " (" $2 ")"}'
    read -p "Storage para el contenedor [$DEFAULT_STORAGE]: " STORAGE
    STORAGE=${STORAGE:-$DEFAULT_STORAGE}
    
    # Tamaño del disco
    read -p "Tamaño del disco [$DEFAULT_DISK_SIZE]: " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-$DEFAULT_DISK_SIZE}
    
    # Memoria RAM
    read -p "Memoria RAM en MB [$DEFAULT_MEMORY]: " MEMORY
    MEMORY=${MEMORY:-$DEFAULT_MEMORY}
    
    # Núcleos de CPU
    read -p "Núcleos de CPU [$DEFAULT_CORES]: " CORES
    CORES=${CORES:-$DEFAULT_CORES}
    
    # Bridge de red
    echo
    print_message "Bridges de red disponibles:"
    ip link show | grep "^[0-9]" | grep -E "vmbr|br" | awk -F': ' '{print "  - " $2}' | awk '{print $1}'
    read -p "Bridge de red [$DEFAULT_BRIDGE]: " BRIDGE
    BRIDGE=${BRIDGE:-$DEFAULT_BRIDGE}
    
    # Configuración de red
    read -p "¿Usar IP estática? (s/n) [n]: " USE_STATIC_IP
    USE_STATIC_IP=${USE_STATIC_IP:-n}
    
    if [[ $USE_STATIC_IP == "s" || $USE_STATIC_IP == "S" ]]; then
        read -p "IP estática (ej: 192.168.1.100/24): " STATIC_IP
        read -p "Gateway: " GATEWAY
        NET_CONFIG="ip=$STATIC_IP,gw=$GATEWAY"
    else
        NET_CONFIG="ip=dhcp"
    fi
    
    # Mapeo de carpetas del host
    read -p "¿Mapear carpeta del host Proxmox? (s/n) [n]: " MAP_HOST_FOLDER
    MAP_HOST_FOLDER=${MAP_HOST_FOLDER:-n}
    
    if [[ $MAP_HOST_FOLDER == "s" || $MAP_HOST_FOLDER == "S" ]]; then
        read -p "Ruta en el host (ej: /mnt/storage): " HOST_PATH
        read -p "Punto de montaje en el contenedor [/srv/samba/host-data]: " MOUNT_POINT
        MOUNT_POINT=${MOUNT_POINT:-/srv/samba/host-data}
        
        # Verificar que la carpeta del host existe
        if [ ! -d "$HOST_PATH" ]; then
            print_warning "La carpeta $HOST_PATH no existe en el host"
            read -p "¿Quieres crearla? (s/n) [s]: " CREATE_HOST_FOLDER
            CREATE_HOST_FOLDER=${CREATE_HOST_FOLDER:-s}
            
            if [[ $CREATE_HOST_FOLDER == "s" || $CREATE_HOST_FOLDER == "S" ]]; then
                mkdir -p "$HOST_PATH"
                print_success "Carpeta $HOST_PATH creada"
            fi
        fi
    fi
    
    print_success "Configuración recopilada"
}

# Mostrar resumen de configuración
show_configuration_summary() {
    print_header "Resumen de Configuración"
    
    echo -e "${CYAN}📋 CONFIGURACIÓN DEL CONTENEDOR:${NC}"
    echo -e "   🆔 ID: ${GREEN}$CTID${NC}"
    echo -e "   🏷️  Hostname: ${GREEN}$HOSTNAME${NC}"
    echo -e "   💾 Storage: ${GREEN}$STORAGE${NC}"
    echo -e "   📦 Tamaño disco: ${GREEN}$DISK_SIZE${NC}"
    echo -e "   🧠 Memoria: ${GREEN}$MEMORY MB${NC}"
    echo -e "   ⚡ CPU cores: ${GREEN}$CORES${NC}"
    echo -e "   🌐 Bridge: ${GREEN}$BRIDGE${NC}"
    echo -e "   📡 Red: ${GREEN}$NET_CONFIG${NC}"
    echo -e "   📁 Template: ${GREEN}$TEMPLATE${NC}"
    
    if [[ $MAP_HOST_FOLDER == "s" || $MAP_HOST_FOLDER == "S" ]]; then
        echo -e "   🔗 Mapeo: ${GREEN}$HOST_PATH → $MOUNT_POINT${NC}"
    fi
    
    echo
    read -p "¿Continuar con la instalación? (s/n) [s]: " CONFIRM
    CONFIRM=${CONFIRM:-s}
    
    if [[ $CONFIRM != "s" && $CONFIRM != "S" ]]; then
        print_message "Instalación cancelada por el usuario"
        exit 0
    fi
}

# Crear el contenedor LXC
create_container() {
    print_header "Creando Contenedor LXC"
    
    print_message "Creando contenedor $CTID..."
    
    # Comando base para crear el contenedor
    # Extraer solo el número del tamaño del disco (quitar la G si existe)
    DISK_SIZE_NUM=$(echo "$DISK_SIZE" | sed 's/[^0-9]//g')
    
    CREATE_CMD="pct create $CTID /var/lib/vz/template/cache/$TEMPLATE \
        --hostname $HOSTNAME \
        --storage $STORAGE \
        --rootfs $STORAGE:$DISK_SIZE_NUM \
        --password $PASSWORD \
        --net0 name=eth0,bridge=$BRIDGE,$NET_CONFIG \
        --memory $MEMORY \
        --cores $CORES \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 \
        --start 1"
    
    # Ejecutar el comando
    if eval $CREATE_CMD; then
        print_success "Contenedor $CTID creado exitosamente"
    else
        print_error "Error al crear el contenedor"
        exit 1
    fi
    
    # Esperar a que el contenedor esté completamente iniciado
    print_message "Esperando a que el contenedor esté listo..."
    sleep 10
    
    # Verificar que el contenedor está corriendo
    if pct status $CTID | grep -q "running"; then
        print_success "Contenedor $CTID está corriendo"
    else
        print_error "El contenedor no se inició correctamente"
        pct status $CTID
        exit 1
    fi
}

# Configurar mapeo de carpetas si se solicitó
configure_host_mapping() {
    if [[ $MAP_HOST_FOLDER == "s" || $MAP_HOST_FOLDER == "S" ]]; then
        print_header "Configurando Mapeo de Carpetas"
        
        print_message "Configurando mapeo: $HOST_PATH → $MOUNT_POINT"
        
        # Detener el contenedor temporalmente
        pct stop $CTID
        
        # Agregar el punto de montaje
        pct set $CTID -mp0 "$HOST_PATH,mp=$MOUNT_POINT"
        
        # Reiniciar el contenedor
        pct start $CTID
        
        # Esperar a que esté listo
        sleep 10
        
        print_success "Mapeo de carpetas configurado"
    fi
}

# Configurar autologin
configure_autologin() {
    print_header "Configurando Autologin"
    
    print_message "Configurando autologin para acceso sin contraseña..."
    
    # Configurar autologin en el contenedor
    pct exec $CTID -- bash -c "
        # Configurar autologin para consola
        mkdir -p /etc/systemd/system/console-getty.service.d/
        cat > /etc/systemd/system/console-getty.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
        
        # Configurar autologin para tty1
        mkdir -p /etc/systemd/system/getty@tty1.service.d/
        cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
        
        # Recargar systemd
        systemctl daemon-reload
    "
    
    print_success "Autologin configurado"
}

# Instalar y configurar Samba
install_samba() {
    print_header "Instalando Samba en el Contenedor"
    
    print_message "Descargando script de instalación de Samba..."
    
    # Descargar el script de Samba al contenedor
    pct exec $CTID -- bash -c "
        curl -sSL https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/samba.sh -o /tmp/samba.sh || 
        wget -O /tmp/samba.sh https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/samba.sh
    " 2>/dev/null || {
        print_warning "No se pudo descargar desde GitHub, usando versión local..."
        
        # Si no se puede descargar, crear el script localmente
        create_local_samba_script
    }
    
    # Hacer el script ejecutable
    pct exec $CTID -- chmod +x /tmp/samba.sh
    
    print_message "Ejecutando instalación automatizada de Samba..."
    
    # Ejecutar el script de Samba con configuración automática
    pct exec $CTID -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        
        # Ejecutar en modo automático
        /tmp/samba.sh --auto || {
            echo 'Error en la instalación de Samba'
            exit 1
        }
    "
    
    print_success "Samba instalado y configurado exitosamente"
}

# Crear script local de Samba si no se puede descargar
create_local_samba_script() {
    print_message "Creando script de Samba local..."
    
    # Copiar el contenido del script principal al contenedor
    pct exec $CTID -- bash -c "
        cat > /tmp/samba.sh << 'SAMBA_SCRIPT_EOF'
#!/bin/bash
# Script básico de instalación de Samba
set -e

echo 'Instalando Samba...'
apt update
apt install -y samba samba-common-bin

echo 'Configurando Samba...'
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

cat > /etc/samba/smb.conf << 'SMB_CONF_EOF'
[global]
    workgroup = WORKGROUP
    server string = Samba Server LXC
    security = user
    map to guest = never
    log file = /var/log/samba/log.%m
    max log size = 1000

[public]
    path = /srv/samba/public
    browsable = yes
    writable = yes
    guest ok = yes
    read only = no
    public = yes
    create mask = 0666
    directory mask = 0777

SMB_CONF_EOF

# Crear directorios
mkdir -p /srv/samba/public
chmod 777 /srv/samba/public

# Iniciar servicios
systemctl enable smbd nmbd
systemctl start smbd nmbd

echo 'Samba instalado exitosamente'
SAMBA_SCRIPT_EOF
    "
}

# Configurar recursos compartidos adicionales
configure_additional_shares() {
    if [[ $MAP_HOST_FOLDER == "s" || $MAP_HOST_FOLDER == "S" ]]; then
        print_header "Configurando Recurso Compartido del Host"
        
        print_message "Agregando recurso compartido para $MOUNT_POINT..."
        
        # Agregar configuración del recurso compartido del host
        pct exec $CTID -- bash -c "
            cat >> /etc/samba/smb.conf << 'EOF'

[host-data]
    comment = Datos del Host Proxmox
    path = $MOUNT_POINT
    browsable = yes
    writable = yes
    guest ok = yes
    read only = no
    public = yes
    create mask = 0666
    directory mask = 0777

EOF
            
            # Reiniciar Samba para aplicar cambios
            systemctl restart smbd nmbd
        "
        
        print_success "Recurso compartido del host configurado"
    fi
}

# Obtener información del contenedor
get_container_info() {
    print_header "Obteniendo Información del Contenedor"
    
    # Obtener IP del contenedor
    CONTAINER_IP=""
    for i in {1..30}; do
        CONTAINER_IP=$(pct exec $CTID -- hostname -I 2>/dev/null | awk '{print $1}' || true)
        if [ -n "$CONTAINER_IP" ]; then
            break
        fi
        print_message "Esperando que el contenedor obtenga IP... ($i/30)"
        sleep 2
    done
    
    if [ -z "$CONTAINER_IP" ]; then
        print_warning "No se pudo obtener la IP del contenedor automáticamente"
        CONTAINER_IP="[IP_DEL_CONTENEDOR]"
    fi
    
    print_success "IP del contenedor: $CONTAINER_IP"
}

# Mostrar información final
show_final_info() {
    print_header "🎉 INSTALACIÓN COMPLETADA"
    
    echo -e "${GREEN}✅ Servidor Samba creado y configurado exitosamente${NC}"
    echo
    echo -e "${CYAN}📋 INFORMACIÓN DEL CONTENEDOR:${NC}"
    echo -e "   🆔 ID: ${GREEN}$CTID${NC}"
    echo -e "   🏷️  Hostname: ${GREEN}$HOSTNAME${NC}"
    echo -e "   🌐 IP: ${GREEN}$CONTAINER_IP${NC}"
    echo -e "   🔑 Contraseña root: ${YELLOW}$PASSWORD${NC}"
    echo
    
    echo -e "${CYAN}🔗 CÓMO CONECTARSE:${NC}"
    echo -e "   🖥️  Desde Windows: ${GREEN}\\\\$CONTAINER_IP${NC}"
    echo -e "   🐧 Desde Linux: ${GREEN}smb://$CONTAINER_IP${NC}"
    echo -e "   📱 Desde móvil: ${GREEN}smb://$CONTAINER_IP${NC}"
    echo
    
    echo -e "${CYAN}📂 RECURSOS COMPARTIDOS:${NC}"
    echo -e "   📁 ${GREEN}public${NC} - Acceso público sin autenticación"
    if [[ $MAP_HOST_FOLDER == "s" || $MAP_HOST_FOLDER == "S" ]]; then
        echo -e "   🔗 ${GREEN}host-data${NC} - Datos del host Proxmox ($HOST_PATH)"
    fi
    echo
    
    echo -e "${CYAN}🛠️  GESTIÓN DEL CONTENEDOR:${NC}"
    echo -e "   📝 Acceder a consola: ${GREEN}pct enter $CTID${NC}"
    echo -e "   🔄 Reiniciar: ${GREEN}pct reboot $CTID${NC}"
    echo -e "   ⏹️  Detener: ${GREEN}pct stop $CTID${NC}"
    echo -e "   ▶️  Iniciar: ${GREEN}pct start $CTID${NC}"
    echo -e "   📊 Ver estado: ${GREEN}pct status $CTID${NC}"
    echo
    
    echo -e "${CYAN}🔧 HERRAMIENTAS EN EL CONTENEDOR:${NC}"
    echo -e "   📊 Ver información: ${GREEN}samba-info${NC} (dentro del contenedor)"
    echo -e "   🔧 Gestionar Samba: ${GREEN}/opt/samba/samba-manager.sh${NC}"
    echo -e "   💾 Crear backup: ${GREEN}/opt/samba/backup-config.sh${NC}"
    echo
    
    print_success "¡Listo pa' usar! Tu servidor Samba está funcionando perfectamente."
    
    # Opción para acceder directamente al contenedor
    echo
    read -p "¿Quieres acceder al contenedor ahora? (s/n) [s]: " ACCESS_CONTAINER
    ACCESS_CONTAINER=${ACCESS_CONTAINER:-s}
    
    if [[ $ACCESS_CONTAINER == "s" || $ACCESS_CONTAINER == "S" ]]; then
        print_message "Accediendo al contenedor $CTID..."
        print_message "Usa 'exit' para salir del contenedor"
        echo
        exec pct enter $CTID
    fi
}

# Función de limpieza en caso de error
cleanup_on_error() {
    if [ -n "$CTID" ] && pct list | grep -q "^$CTID "; then
        print_warning "Limpiando contenedor $CTID debido a error..."
        pct stop $CTID 2>/dev/null || true
        pct destroy $CTID 2>/dev/null || true
        print_message "Contenedor $CTID eliminado"
    fi
}

# Configurar trap para limpieza en caso de error
trap cleanup_on_error ERR

# Función principal
main() {
    print_header "🗂️ Instalador Automático de Samba para Proxmox LXC"
    echo -e "${CYAN}Desarrollado por MondoBoricua para la comunidad${NC}"
    echo
    
    # Verificaciones iniciales
    check_root
    check_proxmox
    
    # Proceso de instalación
    get_user_input
    find_best_template
    check_storage
    check_bridge
    check_ctid
    show_configuration_summary
    create_container
    configure_autologin
    configure_host_mapping
    install_samba
    configure_additional_shares
    get_container_info
    
    # Información final
    show_final_info
}

# Ejecutar función principal
main "$@" 