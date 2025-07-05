# 🗂️ Samba Server para Proxmox LXC

Un script automatizado para crear y configurar servidores Samba en contenedores LXC de Proxmox, perfecto para compartir archivos en tu red local sin complicaciones.

## 📋 Requisitos

* **Proxmox VE** (cualquier versión reciente)
* **Template LXC** (Ubuntu 22.04 o Debian 12 - se detecta automáticamente)
* **Acceso de red** para el contenedor
* **Carpetas a compartir** (opcional - se pueden crear durante la instalación)

## 🚀 Instalación Rápida

### Método 1: Instalación Automática Completa (¡RECOMENDADO!) 🎯

**Opción A: Súper Rápida (Dos pasos)** ⚡

```bash
# Paso 1: Descargar el instalador
curl -sSL https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/auto-install.sh | bash

# Paso 2: Ejecutar el instalador (copia y pega el comando que aparece)
bash /tmp/proxmox-auto-install.sh
```

> **💡 Nota**: El primer comando descarga el instalador, el segundo lo ejecuta. Así evitamos problemas con pipes.

**Opción B: Descarga y Ejecuta** 📥

```bash
# Desde el host Proxmox (SSH o consola)
wget https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/proxmox-auto-install.sh
chmod +x proxmox-auto-install.sh
./proxmox-auto-install.sh
```

**¿Qué hace este script?**

* ✅ Crea el contenedor LXC automáticamente
* ✅ Detecta y usa el mejor template disponible (Ubuntu 22.04 o Debian 12)
* ✅ Configura la red y almacenamiento
* ✅ Instala y configura Samba
* ✅ Crea recursos compartidos predeterminados
* ✅ Configura usuarios y permisos
* ✅ Habilita autoboot (se inicia automáticamente con Proxmox)
* ✅ Configura autologin en consola (sin contraseña)
* ✅ Contraseña por defecto: `samba123` (personalizable)
* ✅ Crea pantalla de bienvenida con información del servidor
* ✅ Configura compartidos seguros y públicos
* ✅ ¡Todo listo en 5 minutos!

### Método 2: Instalación Manual en Contenedor Existente

#### 1. Crear el Contenedor LXC

En Proxmox, crea un nuevo contenedor LXC:

* **Template**: Ubuntu 22.04 o Debian 11/12
* **RAM**: 1GB (recomendado para múltiples usuarios)
* **Disco**: 4GB (mínimo)
* **Red**: Configurada con IP estática o DHCP
* **Features**: Nesting habilitado (opcional)

#### 2. Acceder al Contenedor

```bash
# Desde Proxmox, accede al contenedor
pct enter [ID_DEL_CONTENEDOR]
```

#### 3. Instalación (Método Rápido) 🚀

```bash
# Instalación en una sola línea
curl -sSL https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/install.sh | sudo bash
```

#### 3. Instalación (Método Manual)

```bash
# Descargar el script
wget https://raw.githubusercontent.com/MondoBoricua/proxmox-samba/main/samba.sh

# Darle permisos de ejecución
chmod +x samba.sh

# Ejecutar como root
sudo ./samba.sh
```

### 4. Configurar Durante la Instalación

El script te pedirá:

* **Nombre del servidor**: Nombre que aparecerá en la red
* **Grupo de trabajo**: Por defecto `WORKGROUP`
* **Usuarios**: Crear usuarios para acceso autenticado
* **Recursos compartidos**: Carpetas a compartir y sus permisos
* **Mapeo de carpetas**: Si quieres mapear carpetas del host Proxmox

## 🔧 Lo que Hace el Script

El instalador automáticamente:

1. **Instala Samba** y dependencias necesarias
2. **Configura el archivo** `/etc/samba/smb.conf` con configuración optimizada
3. **Crea usuarios** del sistema y de Samba
4. **Establece recursos compartidos** con permisos apropiados
5. **Configura el firewall** (si está habilitado)
6. **Inicia los servicios** Samba automáticamente
7. **Crea herramientas** de gestión y monitoreo

## 📁 Estructura Creada

Después de la instalación encontrarás:

```
/opt/samba/
├── samba-manager.sh      # Herramienta de gestión
├── welcome.sh           # Pantalla de bienvenida
└── backup-config.sh     # Script de respaldo

/etc/samba/
├── smb.conf            # Configuración principal
└── smb.conf.backup     # Respaldo de configuración

/srv/samba/             # Directorio base para compartidos
├── public/             # Compartido público
├── private/            # Compartido privado
└── users/              # Directorios de usuarios

/var/log/samba/         # Logs del servidor
```

## 🔓 Acceso al Contenedor

### **Consola Proxmox (Recomendado)**

```bash
# Acceso directo sin contraseña (autologin habilitado)
pct enter [ID_CONTENEDOR]
```

### **SSH (Opcional)**

```bash
# Acceso por SSH (requiere contraseña)
ssh root@IP_DEL_CONTENEDOR
# Contraseña por defecto: samba123
```

### **Autoboot**

El contenedor se inicia automáticamente cuando Proxmox arranca.

## 🖥️ Pantalla de Bienvenida

Cuando entres al contenedor (`pct enter [ID]`), verás automáticamente:

* 🌐 **Información del servidor Samba**
* 📡 **IP del servidor y puertos activos**
* 👥 **Usuarios configurados**
* 📂 **Recursos compartidos disponibles**
* 🔄 **Estado de los servicios**
* 📊 **Estadísticas de conexiones activas**
* 🛠️ **Comandos de gestión disponibles**

**Comando rápido**: Escribe `samba-info` en cualquier momento para ver la información.

## 🔍 Verificar que Funciona

### Comprobar el Servicio

```bash
# Ver si Samba está activo
systemctl status smbd nmbd

# Verificar la configuración
testparm

# Ver recursos compartidos
smbclient -L localhost
```

### Probar Conexiones

```bash
# Desde Windows (Ejecutar)
\\IP_DEL_CONTENEDOR

# Desde Linux
smbclient //IP_DEL_CONTENEDOR/public -U usuario

# Montar desde Linux
sudo mount -t cifs //IP_DEL_CONTENEDOR/public /mnt/samba -o username=usuario
```

### Gestión de Usuarios

```bash
# Crear nuevo usuario
/opt/samba/samba-manager.sh add-user nombre_usuario

# Listar usuarios
/opt/samba/samba-manager.sh list-users

# Cambiar contraseña
/opt/samba/samba-manager.sh change-password usuario

# Eliminar usuario
/opt/samba/samba-manager.sh remove-user usuario
```

## 🛠️ Gestión Avanzada

### Agregar Nuevos Recursos Compartidos

```bash
# Usar el gestor integrado
/opt/samba/samba-manager.sh add-share

# O editar manualmente
nano /etc/samba/smb.conf
systemctl reload smbd
```

### Mapear Carpetas del Host Proxmox

```bash
# Desde el host Proxmox, mapear carpeta al contenedor
pct set [ID_CONTENEDOR] -mp0 /ruta/en/host,mp=/srv/samba/host-data

# Luego agregar al smb.conf
[host-data]
    path = /srv/samba/host-data
    browsable = yes
    writable = yes
    valid users = @sambashare
```

### Configuraciones Predeterminadas

El script crea estos recursos compartidos por defecto:

* **public** - Acceso público sin autenticación
* **private** - Acceso solo para usuarios autenticados
* **users** - Directorios personales para cada usuario

## 🛠️ Solución de Problemas

### Problemas con el Instalador Automático

#### Error: "Este script debe ejecutarse en un servidor Proxmox VE"

```bash
# Asegúrate de estar en el HOST Proxmox, no en un contenedor
# Usa SSH para conectarte al servidor Proxmox directamente
ssh root@IP_DE_TU_PROXMOX
```

#### El contenedor no se puede conectar a la red

```bash
# Verificar configuración de red
pct config [ID_CONTENEDOR]

# Reiniciar la red del contenedor
pct reboot [ID_CONTENEDOR]
```

### Problemas de Conectividad

#### No puedo ver el servidor en la red

```bash
# Verificar que los servicios estén corriendo
systemctl status smbd nmbd

# Verificar puertos abiertos
netstat -tulpn | grep -E '139|445'

# Reiniciar servicios
systemctl restart smbd nmbd
```

#### Error de autenticación

```bash
# Verificar usuarios de Samba
pdbedit -L

# Recrear usuario
smbpasswd -x usuario
smbpasswd -a usuario
```

### Problemas de Permisos

```bash
# Verificar permisos de carpetas
ls -la /srv/samba/

# Corregir permisos
chown -R root:sambashare /srv/samba/
chmod -R 775 /srv/samba/
```

## 🔧 Personalización

### Cambiar Configuración de Red

```bash
# Editar configuración principal
nano /etc/samba/smb.conf

# Sección [global] - cambiar interfaz de red
interfaces = eth0 192.168.1.0/24
bind interfaces only = yes
```

### Optimizar Rendimiento

```bash
# Para redes modernas, agregar a [global]:
min protocol = SMB2
max protocol = SMB3
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072
```

## 🔄 Backup y Restauración

### Crear Backup

```bash
# Backup automático de configuración
/opt/samba/backup-config.sh

# Backup manual
tar -czf samba-backup-$(date +%Y%m%d).tar.gz /etc/samba/ /srv/samba/
```

### Restaurar Configuración

```bash
# Restaurar desde backup
tar -xzf samba-backup-YYYYMMDD.tar.gz -C /
systemctl restart smbd nmbd
```

## 🔄 Desinstalar

Si necesitas remover Samba:

```bash
# Detener servicios
systemctl stop smbd nmbd
systemctl disable smbd nmbd

# Eliminar paquetes
apt remove --purge samba samba-common-bin

# Eliminar configuraciones
rm -rf /etc/samba/
rm -rf /srv/samba/
rm -rf /opt/samba/
```

## 📝 Configuraciones de Ejemplo

### Servidor de Archivos Empresarial

```ini
[global]
    workgroup = EMPRESA
    server string = Servidor de Archivos Empresa
    security = user
    map to guest = never
    log file = /var/log/samba/log.%m
    max log size = 1000
    logging = file
    panic action = /usr/share/samba/panic-action %d

[departamentos]
    path = /srv/samba/departamentos
    browsable = yes
    writable = yes
    valid users = @empleados
    create mask = 0664
    directory mask = 0775
```

### Servidor Multimedia

```ini
[media]
    path = /srv/samba/media
    browsable = yes
    writable = no
    guest ok = yes
    read only = yes
    follow symlinks = yes
    wide links = yes
```

## 📊 Monitoreo

### Ver Conexiones Activas

```bash
# Conexiones actuales
smbstatus

# Archivos abiertos
smbstatus -L

# Usuarios conectados
smbstatus -u
```

### Logs del Sistema

```bash
# Ver logs de Samba
tail -f /var/log/samba/log.smbd

# Ver logs del sistema
journalctl -u smbd -f
```

## 📝 Notas Importantes

* **Compatibilidad**: Funciona con Ubuntu 22.04 y Debian 12 (detección automática)
* **Templates**: El script busca automáticamente el mejor template disponible
* **Autologin**: La consola de Proxmox no requiere contraseña (configurado automáticamente)
* **Contraseña SSH**: Por defecto es `samba123` (puedes cambiarla durante la instalación)
* **Autoboot**: El contenedor se inicia automáticamente con Proxmox
* **Seguridad**: Por defecto se configura con autenticación de usuarios
* **Firewall**: Compatible con UFW y iptables
* **Backup**: Configuración automática de respaldos
* **Performance**: Optimizado para redes modernas (SMB3)

## 🤝 Contribuir

¿Encontraste un bug o tienes una mejora?

1. Haz fork del repositorio
2. Crea tu rama de feature (`git checkout -b feature/mejora-increible`)
3. Commit tus cambios (`git commit -am 'Añade mejora increíble'`)
4. Push a la rama (`git push origin feature/mejora-increible`)
5. Crea un Pull Request

## 📜 Licencia

Este proyecto está bajo la Licencia MIT - ve el archivo LICENSE para más detalles.

## ⭐ ¿Te Sirvió?

Si este script te ayudó, ¡dale una estrella al repo! ⭐

---

**Desarrollado con ❤️ para la comunidad de Proxmox**

**Hecho en 🇵🇷 Puerto Rico con mucho ☕ café**

## 🔗 Recursos Adicionales

* [Documentación oficial de Samba](https://www.samba.org/samba/docs/)
* [Guía de Proxmox LXC](https://pve.proxmox.com/wiki/Linux_Container)
* [Configuración avanzada de SMB](https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Standalone_Server) 