#!/bin/bash
#
# server_hardening.sh
#
# Hardening de servidores Linux orientado a entornos de hosting compartido.
# Diseñado para ejecutarse luego de una instalación limpia o ante sospecha
# de compromiso del servidor.
#
# Acciones que realiza:
#   1. Auditoría de lastlog — muestra últimos accesos de usuarios
#   2. Auditoría de crontabs activos por usuario
#   3. Agrega soporte ACL al filesystem raíz (apt/yum + fstab)
#   4. Limpieza de malware kinsing y variantes conocidas:
#        - Mata procesos, elimina binarios en /tmp y /var/tmp
#        - Bloquea recreación con chattr +ia
#   5. Bloqueo de cron para usuarios de servicios web:
#        www-data, httpd, postgres, tomcat, apache
#   6. Restricción de herramientas de descarga via ACL por usuario:
#        wget, curl, python, python3, crontab
#   7. Bloqueo de tráfico saliente por UID con iptables
#        (persiste entre reinicios via if-up.d en Debian o ifup-post en CentOS)
#   8. Configura apache2 con PrivateTmp=false via systemd override
#   9. Reinicia servicios afectados y verifica conectividad
#
# Uso:
#   sudo ./server_hardening.sh
#
# Compatibilidad: Debian/Ubuntu, CentOS/RHEL
#
# Dependencias: acl (setfacl), iptables, systemd, smartmontools
#
# NOTA: Revisar y ajustar la lista de usuarios en la sección
#       "Bloqueo de cron" según los servicios activos en el servidor.
#

# ── Verificar root ─────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# ── Función: actualizar Composer ───────────────────────────
# No se ejecuta automáticamente. Llamar manualmente si se necesita:
#   update_composer
update_composer() {
    # Referencia: https://getcomposer.org/doc/faqs/how-to-install-untrusted-packages-safely.md
    for composer in $(which -a composer); do
        composer_path=$(dirname "${composer}")
        composer --version --no-plugins --no-scripts
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php -r "if (hash_file('SHA384', 'composer-setup.php') === trim(file_get_contents('https://composer.github.io/installer.sig'))) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); exit; } echo PHP_EOL;"
        php composer-setup.php --install-dir="${composer_path}" --filename=composer
        composer --version --no-plugins --no-scripts
    done
}

# ── 1. Auditoría de lastlog ────────────────────────────────
echo "## LASTLOG ##"
lastlog | grep -v 'Never logged in'
read -rp "Presione Enter para continuar..."
echo

# ── 2. Auditoría de crontabs ───────────────────────────────
echo "## CRON LIST ##"
for user in $(cut -f1 -d':' /etc/passwd); do
    cron_user_list=$(crontab -u "${user}" -l 2>/dev/null | grep -v '^#')
    [ -n "${cron_user_list}" ] && echo "${user}" && echo "${cron_user_list}"
done
read -rp "Presione Enter para continuar..."
echo

# ── Notas de hardening manual (PostgreSQL) ─────────────────
# Verificar contraseñas inseguras en: /var/lib/tomcat*/conf/tomcat-users.xml
#
# Habilitar chequeo de contraseñas en PostgreSQL:
#   /etc/postgresql/*/main/postgresql.conf:
#     shared_preload_libraries = '$libdir/passwordcheck'
#     shared_preload_libraries = 'auth_delay'
#     auth_delay.milliseconds  = '1000'
# Ref: https://www.postgresql.org/docs/current/auth-delay.html
#
# Verificar acceso con usuario/contraseña por defecto:
#   psql -U postgres -h <servidor>

# ── 3. Soporte ACL ─────────────────────────────────────────
if ! which setfacl > /dev/null 2>&1; then
    apt install -y acl || yum install -y acl
fi

if ! grep -w -q acl /etc/fstab; then
    cp /etc/fstab /etc/fstab.bkp
    awk '$2~"^/$"{$4=$4",acl"}1' OFS="\t" /etc/fstab > /etc/fstab.acl
    diff /etc/fstab /etc/fstab.acl
    read -rp "Presione Enter para continuar..."
    mv /etc/fstab.acl /etc/fstab
    mount -o remount,acl /
fi

grep -w --color acl /etc/fstab

# ── 4. Limpieza de malware kinsing ─────────────────────────
# IPs conocidas de C2 para monitoreo con tcpdump (comentado, solo referencia):
# tcpdump -i any -nnn net 195.123.220.193 or dst 193.33.87.220 or dst 139.99.50.255 \
#   or dst 45.137.151.106 or dst 178.157.91.26 or dst 45.10.88.124
for file in kdevtmpfsi kinsing zzz dnfDc4LtrN; do
    killall -9 "${file}" 2>/dev/null

    chattr -ia /tmp/"${file}"     2>/dev/null
    chattr -ia /var/tmp/"${file}" 2>/dev/null

    rm -f  /tmp/"${file}"
    rm -f  /var/tmp/"${file}"
    rm -fr /tmp/.ICEd-unix
    rm -fr /var/tmp/.ICEd-unix
    rm -fr /run/shm/.ICEd-unix/

    # Recrear como archivo inmutable para bloquear reinfección
    echo "everything is good here" > /tmp/"${file}"
    echo "everything is good here" > /var/tmp/"${file}"

    chattr +ia /tmp/"${file}"
    chattr +ia /var/tmp/"${file}"
done

# ── 5 y 6. Bloqueo de cron y herramientas de descarga ──────
# Usuarios de servicios web a restringir — ajustar según el servidor
SERVICE_USERS="^www-data\|^httpd\|^postgres\|^tomcat\|^apache"

[ -f /etc/cron.deny ] || touch /etc/cron.deny

for user in $(cut -f1 -d: /etc/passwd | grep -e "${SERVICE_USERS}"); do

    # Bloquear crontab
    grep -w -q "${user}" /etc/cron.deny || crontab -u "${user}" -r 2>/dev/null
    grep -w -q "${user}" /etc/cron.deny || echo "${user}" >> /etc/cron.deny

    if [ -d "/var/spool/cron/crontabs" ]; then
        CRONTAB="/var/spool/cron/crontabs/${user}"
    else
        CRONTAB="/var/spool/cron/${user}"
    fi

    chattr -ia "${CRONTAB}" 2>/dev/null
    rm -f "${CRONTAB}"
    touch "${CRONTAB}"
    setfacl -m user:"${user}":0  "${CRONTAB}"
    setfacl -m group:"${user}":0 "${CRONTAB}"
    chattr +ia "${CRONTAB}"

    # Bloquear acceso a /tmp y /var/tmp
    setfacl -m user:"${user}":0  /tmp/
    setfacl -m group:"${user}":0 /tmp/
    setfacl -m user:"${user}":0  /var/tmp/
    setfacl -m group:"${user}":0 /var/tmp/

    # Bloquear herramientas de descarga y ejecución via ACL
    for cmd in $(which wget curl python python3 crontab GET POST 2>/dev/null); do
        setfacl -m user:"${user}":0  "${cmd}"
        setfacl -m group:"${user}":0 "${cmd}"
        # Verificar que el bloqueo se aplicó correctamente:
        # getfacl "${cmd}"
    done

    # ── 7. Bloquear tráfico saliente por UID ───────────────
    # Detectar archivo de reglas según distro
    [ -d /etc/network/if-up.d ]                      && iptables_rules_file="/etc/network/if-up.d/iptables-rules" && restart_network="systemctl restart networking.service"
    [ -f /etc/sysconfig/network-scripts/ifup-post ]  && iptables_rules_file="/sbin/ifup-local"                    && restart_network="systemctl restart network.service"

    [ -n "${iptables_rules_file}" ] || continue
    [ -f "${iptables_rules_file}" ] || touch "${iptables_rules_file}"

    chmod +x "${iptables_rules_file}"
    grep -q '#!/bin/bash' "${iptables_rules_file}" || echo "#!/bin/bash" >> "${iptables_rules_file}"
    grep -q -w "${user}" "${iptables_rules_file}"  || echo "/sbin/iptables -I OUTPUT -m owner --uid-owner ${user} -j DROP && /sbin/iptables -I OUTPUT -m conntrack -m owner --uid-owner ${user} --ctstate ESTABLISHED -j ACCEPT" >> "${iptables_rules_file}"

done

# ── 8. Configurar apache2 con PrivateTmp=false ─────────────
mkdir -p "/etc/systemd/system/apache2.service.d"

cat <<EOF > /etc/systemd/system/apache2.service.d/override.conf
[Service]
PrivateTmp=false
EOF

systemctl daemon-reload
systemctl stop  apache2.service
systemctl start apache2.service

# ── 9. Reiniciar servicios y verificar ─────────────────────
systemctl stop  cron.service
sleep 2
systemctl start cron.service

[ -n "${restart_network}" ] && ${restart_network}

echo
echo "## SERVICIOS EN ESTADO FAILED O ACTIVATING ##"
systemctl list-units | sort | grep -w -e failed -e activating

echo
echo "## VERIFICANDO CONECTIVIDAD ##"
ping -c3 8.8.8.8 > /dev/null && echo "OK" || { echo "Sin conectividad — intentando levantar eth0"; ifup eth0; }

echo
echo "## REGLAS IPTABLES POR UID ##"
/sbin/iptables -L -n | grep "UID"
