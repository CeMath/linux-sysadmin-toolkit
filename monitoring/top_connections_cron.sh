#!/bin/bash
# Monitor de conexiones Apache con bloqueo automático de IPs
# Detecta: flood por minuto, flood por hora, ataques wp-login/xmlrpc.php

# =============================================================================
# CONFIGURACIÓN - Ajustar según el entorno
# =============================================================================

# Modo test: 1=solo muestra qué bloquearía (sin cambios), 0=bloquea de verdad
TEST="1"

# Host y usuario del router/firewall para ejecutar bloqueos via SSH
ROUTER_HOST="router.ejemplo.interno"
ROUTER_PORT="22"
ROUTER_USER="admin"

# Paths de scripts en el router
SCRIPT_BLOCK_IPV4="sudo /scripts/deshabilita_IP.sh"
SCRIPT_BLOCK_IPV6="sudo /scripts/deshabilita_IPv6.sh"

# Paths locales
SCRIPTS_DIR="/scripts/top_connections"
LOG_APACHE="/var/log/apache/centralizados.log"
LOG_BLOCKED="/var/log/top_connections_blocked_ip"
GEOIP_DB="/usr/share/GeoIP/GeoLite2-Country.mmdb"
SCRIPT_GET_IP_VERSION="/scripts/get_ip_version.py"
SCRIPT_CLOUDFLARE_CHECK="${SCRIPTS_DIR}/buscar_IPv4_rango_cloudflare.sh"
SCRIPT_PROTECT_WP="${SCRIPTS_DIR}/protege-wp-admin.sh"
SCRIPT_GETUSER="sudo /scripts/getuserquiet"

# Archivos de listas
FILE_IP_WHITELIST="${SCRIPTS_DIR}/ip_whitelist"
FILE_IP_BLACKLIST_V6="${SCRIPTS_DIR}/blacklist_net_ipv6"
FILE_COUNTRY_BLACKLIST="${SCRIPTS_DIR}/country_blacklist"
FILE_IGNORE_IPS="/var/log/ignore_ips.txt"
FILE_TRUSTED_NETS="${SCRIPTS_DIR}/trusted_nets"       # ex IPs_donweb, IPs_mercadolibre, etc.
FILE_REPORTED_DOMAINS="${SCRIPTS_DIR}/DOMINIO_reportado"

# IPs siempre excluidas del reporte (localhost, etc.)
BASE_WHITELIST_IPS="127.0.0.1"

# Regex para identificar servidores propios (ej: c100, c101...)
FIS_REGEX="c[0-9][0-9][0-9]"

# Umbrales
THRESHOLD_CONN_PER_MIN=100        # Conexiones por minuto para alerta
THRESHOLD_CONN_PER_HOUR=6000      # Conexiones en la hora en curso
THRESHOLD_CONN_TRUSTED=10000      # Umbral especial para IPs de redes confiables
THRESHOLD_ERRORS_4XX_HOUR=500     # Errores 4XX en la hora
THRESHOLD_ERRORS_4XX_MIN=10       # Errores 4XX en el último minuto
THRESHOLD_CONN_MIN_FOR_HOUR=60    # Conexiones en el último minuto (trigger extra para bloqueo por hora)
THRESHOLD_CONN_MIN_TRUSTED=120    # Ídem para redes confiables
THRESHOLD_XMLRPC_POSTS=10         # POSTs a xmlrpc.php
THRESHOLD_XMLRPC_TOTAL=150        # Total conexiones para bloqueo xmlrpc
THRESHOLD_XMLRPC_MIN=30           # Conexiones xmlrpc en último minuto (IPv6)
THRESHOLD_XMLRPC_MIN_V4=60        # Conexiones xmlrpc en último minuto (IPv4)
THRESHOLD_WPLOGIN_SITES=5         # Sitios distintos con >50 hits al wp-login
THRESHOLD_WPLOGIN_HITS=50         # Hits al wp-login para conteo multi-sitio
THRESHOLD_WPLOGIN_SINGLE=100      # Hits al wp-login de un mismo dominio
THRESHOLD_WPLOGIN_MIN=60          # Hits wp-login en el último minuto
THRESHOLD_TOTAL_APPEARANCES=200   # Apariciones totales en el log

# Archivos temporales
TMP_LOG_LAST_MIN="/tmp/log_apache_centralizado_last_minute"
TMP_TOP_CONN="/tmp/top_connections"
TMP_TOP_CONN_MIN="/tmp/top_connections_last_minute"
TMP_WP_LOGIN="/tmp/top_connections_wp-login"
TMP_WP_LOGIN_X_DOM="/tmp/top_connections_wp-login-x-dominio"
TMP_WP_LOGIN_1_DOM="/tmp/top_connections_wp-login-1-dominio"
TMP_XMLRPC="/tmp/top_connections_xmlrcp"
TMP_IP_REPORTED="/tmp/IP_reportada"

# =============================================================================
# FUNCIONES
# =============================================================================

log_block() {
    local ip="$1"
    local reason="$2"
    echo "$(date) - $ip - $reason" >> "$LOG_BLOCKED" 2>/dev/null
}

geoip_lookup() {
    local ip="$1"
    mmdblookup --file "$GEOIP_DB" --ip "$ip" country names en 2>/dev/null \
        | grep '"' | cut -d'"' -f2
}

is_cloudflare() {
    local ip="$1"
    "$SCRIPT_CLOUDFLARE_CHECK" "$ip"
}

get_ip_version() {
    local ip="$1"
    "$SCRIPT_GET_IP_VERSION" "$ip"
}

is_country_blacklisted() {
    local country="$1"
    # Retorna vacío si el país SÍ está en la blacklist (para bloqueo)
    echo "$country" | grep -vE "$(cat "$FILE_COUNTRY_BLACKLIST")"
}

is_trusted_net() {
    local ip="$1"
    grep -q "$ip" "$FILE_TRUSTED_NETS" 2>/dev/null
}

block_ip() {
    local ip="$1"
    local version="$2"
    local flags="${3:-}"
    local script

    if [ "$version" = "6" ]; then
        script="$SCRIPT_BLOCK_IPV6"
    else
        script="$SCRIPT_BLOCK_IPV4"
    fi

    if [ "$TEST" = "1" ]; then
        echo "  [TEST] ssh -q -o StrictHostKeyChecking=no ${ROUTER_USER}@${ROUTER_HOST} -p ${ROUTER_PORT} \"${script} ${ip} APACHELOG ${flags}\""
    else
        ssh -q -o StrictHostKeyChecking=no \
            -p "$ROUTER_PORT" \
            "${ROUTER_USER}@${ROUTER_HOST}" \
            "${script} ${ip} APACHELOG ${flags}" \
            >/dev/null 2>/dev/null
    fi
}

mark_ip_reported() {
    local ip="$1"
    echo -n "|$ip" >> "$TMP_IP_REPORTED"
}

# =============================================================================
# CHECKS INICIALES
# =============================================================================

# Evitar ejecución con load alto
if [ "$(awk '{printf "%d", $1}' /proc/loadavg)" -gt 5 ]; then
    echo "Abortando: load promedio mayor a 5"
    exit 0
fi

# Reiniciar lista de IPs reportadas al minuto 01 de cada hora
if [ "$(date '+%M')" = "01" ]; then
    echo -n "$BASE_WHITELIST_IPS" > "$TMP_IP_REPORTED"
fi

if [ "$TEST" = "1" ]; then
    echo "[MODO TEST] No se realizará ningún bloqueo, solo se mostrará qué se bloquearía."
else
    echo "[MODO ACTIVO] Se ejecutarán bloqueos."
fi

# =============================================================================
# PREPARAR LOG DEL ÚLTIMO MINUTO
# =============================================================================

> "$TMP_LOG_LAST_MIN"
grep "$(date '+%H:%M:' --date=@$(( $(date +%s) - 60 )))" "$LOG_APACHE" >> "$TMP_LOG_LAST_MIN"

# =============================================================================
# CHECK 0: IPs con más de $THRESHOLD_CONN_PER_MIN conexiones en el último minuto
# =============================================================================

> "$TMP_TOP_CONN_MIN"
egrep -v "Googlebot|bingbot" "$TMP_LOG_LAST_MIN" \
    | grep -vE "$(cat "$FILE_IP_WHITELIST")" \
    | awk '{print $6}' \
    | sort | uniq -c | sort -nrk1 \
    | awk -v t="$THRESHOLD_CONN_PER_MIN" '$1 > t' \
    >> "$TMP_TOP_CONN_MIN"

CHECK0=$(cat "$TMP_TOP_CONN_MIN" | while read CONECT IP; do
    echo -n "$IP"
    geoip_lookup "$IP"
done | grep -vE "$(cat "$TMP_IP_REPORTED")")

if [ -n "$CHECK0" ]; then
    TITULO=0
    cat "$TMP_TOP_CONN_MIN" | grep -vE "$(cat "$TMP_IP_REPORTED")" | head -10 | while read CONECT IP0; do
        if grep -q "$IP0" "$FILE_IP_BLACKLIST_V6" 2>/dev/null \
           || grep -q "$IP0" "$FILE_IGNORE_IPS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nIPs CON MAS DE $THRESHOLD_CONN_PER_MIN CONEXIONES DURANTE EL ULTIMO MINUTO\n"
            echo -e "Conex\tIP\t\tOrigen"
            TITULO=1
        fi
        echo -n "$CONECT  $IP0  "
        PAIS=$(geoip_lookup "$IP0")
        echo -n "$PAIS"
        IPVERSION=$(get_ip_version "$IP0")

        if [ "$IPVERSION" = "6" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP0" "$TMP_LOG_LAST_MIN" | awk '{print $16}' | grep "4[0-5][0-9]" | awk -v t="$THRESHOLD_ERRORS_4XX_MIN" '$1 > t')
            C3=$(grep "$IP0" "$FILE_IP_BLACKLIST_V6" 2>/dev/null)
            if { [ -z "$C1" ] || [ -n "$C2" ]; } && [ -z "$C3" ]; then
                log_block "$IP0" "MAS DE $THRESHOLD_CONN_PER_MIN CONEXIONES DURANTE UN MINUTO"
                block_ip "$IP0" "6"
                echo -e "\t(bloqueada en el router)"
                mark_ip_reported "$IP0"
                echo "$IP0" >> "$FILE_IP_BLACKLIST_V6"
            else
                echo
            fi
        elif [ "$IPVERSION" = "4" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP0" "$TMP_LOG_LAST_MIN" | awk '{print $16}' | grep "4[0-5][0-9]" | awk -v t="$THRESHOLD_ERRORS_4XX_MIN" '$1 > t')
            C3=$(grep "$IP0" "$FILE_TRUSTED_NETS" 2>/dev/null)
            if { [ -z "$C1" ] || [ -n "$C2" ]; } && [ -z "$C3" ]; then
                CLOUDFLARE=$(is_cloudflare "$IP0")
                if [ -z "$CLOUDFLARE" ]; then
                    log_block "$IP0" "MAS DE $THRESHOLD_CONN_PER_MIN CONEXIONES DURANTE UN MINUTO"
                    block_ip "$IP0" "4"
                    echo -e "\t(bloqueada en el router)"
                    mark_ip_reported "$IP0"
                else
                    echo -e "\t(Pertenece a cloudflare)"
                fi
            else
                echo
            fi
        fi
    done
fi

# =============================================================================
# CHECK 1: IPs con más de $THRESHOLD_CONN_PER_HOUR conexiones en la hora en curso
# =============================================================================

> "$TMP_TOP_CONN"
egrep -v "Googlebot|bingbot" "$LOG_APACHE" \
    | awk '{print $6" "$16}' \
    | grep -vE "$(cat "$FILE_IP_WHITELIST")" \
    | sort | uniq -c \
    | awk -v t="$THRESHOLD_CONN_PER_HOUR" '$1 > t' \
    | sort -nrk1 | head -50 \
    >> "$TMP_TOP_CONN"

CHECK1=$(cat "$TMP_TOP_CONN" | while read CONECT IP COD; do
    echo -n "$IP"
    geoip_lookup "$IP"
done | grep -vE "$(cat "$TMP_IP_REPORTED")")

if [ -n "$CHECK1" ]; then
    TITULO=0
    cat "$TMP_TOP_CONN" | grep -vE "$(cat "$TMP_IP_REPORTED")" | head -10 | while read CONECT IP COD; do
        if grep -q "$IP" "$FILE_IGNORE_IPS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nIPs CON MAS DE $THRESHOLD_CONN_PER_HOUR CONEXIONES DURANTE LA HORA EN CURSO ($(date +%H)hs)\n"
            echo -e "Conex\tIP\t\tOrigen"
            TITULO=1
        fi
        echo -n "$CONECT  $IP  "
        PAIS=$(geoip_lookup "$IP")
        echo -n "$PAIS"
        IPVERSION=$(get_ip_version "$IP")

        if [ "$IPVERSION" = "6" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP" "$TMP_TOP_CONN" | grep "4[0-5][0-9]" | awk -v t="$THRESHOLD_ERRORS_4XX_HOUR" '$1 > t')
            C3=$(grep "$IP" "$TMP_LOG_LAST_MIN" | wc -l)
            C4=$(grep "$IP" "$FILE_IP_BLACKLIST_V6" 2>/dev/null)
            if { [ "$CONECT" -ge 5000 ] || [ -z "$C1" ] || [ -n "$C2" ] || [ "$C3" -ge "$THRESHOLD_CONN_MIN_FOR_HOUR" ]; } && [ -z "$C4" ]; then
                log_block "$IP" "MAS DE $THRESHOLD_CONN_PER_HOUR CONEXIONES DURANTE LA HORA EN CURSO"
                block_ip "$IP" "6" "-f"
                echo -e "\t(bloqueada en el router)"
                mark_ip_reported "$IP"
                echo "$IP" >> "$FILE_IP_BLACKLIST_V6"
            else
                echo
            fi
        elif [ "$IPVERSION" = "4" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP" "$TMP_TOP_CONN" | grep "4[0-5][0-9]" | awk -v t="$THRESHOLD_ERRORS_4XX_HOUR" '$1 > t')
            C3=$(grep "$IP" "$TMP_LOG_LAST_MIN" | wc -l)
            C4=$(grep "$IP" "$FILE_TRUSTED_NETS" 2>/dev/null)
            C5_TRUSTED=$(is_trusted_net "$IP")

            if [ -n "$C5_TRUSTED" ]; then
                # Red confiable: umbral más alto
                if { [ -z "$C1" ] || [ -n "$C2" ] || [ "$C3" -ge "$THRESHOLD_CONN_MIN_TRUSTED" ]; } \
                   && [ "$CONECT" -ge "$THRESHOLD_CONN_TRUSTED" ] && [ -z "$C4" ]; then
                    log_block "$IP" "MAS DE $THRESHOLD_CONN_TRUSTED CONEXIONES (RED CONFIABLE)"
                    block_ip "$IP" "4" "-f"
                    echo -e "\t(bloqueada en el router)"
                    mark_ip_reported "$IP"
                else
                    echo
                fi
            else
                if { [ "$CONECT" -ge 5000 ] || [ -z "$C1" ] || [ -n "$C2" ] || [ "$C3" -ge "$THRESHOLD_CONN_MIN_FOR_HOUR" ]; } && [ -z "$C4" ]; then
                    CLOUDFLARE=$(is_cloudflare "$IP")
                    if [ -z "$CLOUDFLARE" ]; then
                        log_block "$IP" "MAS DE $THRESHOLD_CONN_PER_HOUR CONEXIONES DURANTE LA HORA EN CURSO"
                        block_ip "$IP" "4"
                        echo -e "\t(bloqueada en el router)"
                        mark_ip_reported "$IP"
                    else
                        echo -e "\t(Pertenece a cloudflare)"
                    fi
                else
                    echo
                fi
            fi
        fi
    done
fi

# =============================================================================
# CHECK 2: IPs con >$THRESHOLD_WPLOGIN_HITS hits al wp-login en más de $THRESHOLD_WPLOGIN_SITES sitios distintos
# =============================================================================

> "$TMP_WP_LOGIN"
fgrep wp-login "$LOG_APACHE" \
    | awk '{print $6"      "$8}' \
    | grep -vE "$(cat "$FILE_IP_WHITELIST")" \
    | sort | uniq -c | sort -n \
    | awk -v t="$THRESHOLD_WPLOGIN_HITS" '$1 > t' \
    | awk '{print $1" "$2" "$3}' \
    | sort -k2 | awk '{print $2}' \
    | uniq -c | sort -nrk1 \
    | fgrep -v ' 1 ' \
    >> "$TMP_WP_LOGIN"

CHECK2=$(cat "$TMP_WP_LOGIN" | grep -vE "$(cat "$TMP_IP_REPORTED")")
if [ -n "$CHECK2" ]; then
    TITULO=0
    cat "$TMP_WP_LOGIN" | grep -vE "$(cat "$TMP_IP_REPORTED")" | while read CANT_SITIOS IP2; do
        if grep -q "$IP2" "$FILE_IP_BLACKLIST_V6" 2>/dev/null \
           || grep -q "$IP2" "$FILE_IGNORE_IPS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nIPs CON MAS DE $THRESHOLD_WPLOGIN_HITS CONEXIONES AL WP-LOGIN DE DISTINTOS SITIOS EN AL MENOS $THRESHOLD_WPLOGIN_SITES SITIOS\n"
            echo -e "Sitios\tIP\t\tOrigen"
            TITULO=1
        fi
        echo -n "$CANT_SITIOS  $IP2  "
        PAIS=$(geoip_lookup "$IP2")
        echo -n "$PAIS"

        if [ "$CANT_SITIOS" -ge "$THRESHOLD_WPLOGIN_SITES" ]; then
            IPVERSION=$(get_ip_version "$IP2")
            if [ "$IPVERSION" = "6" ]; then
                C1=$(grep "$IP2" "$LOG_APACHE" | wc -l)
                C2=$(is_country_blacklisted "$PAIS")
                C3=$(grep "$IP2" "$FILE_IP_BLACKLIST_V6" 2>/dev/null)
                if { [ "$C1" -ge "$THRESHOLD_TOTAL_APPEARANCES" ] || [ -z "$C2" ]; } && [ -z "$C3" ]; then
                    log_block "$IP2" "MAS DE $THRESHOLD_WPLOGIN_HITS CONEXIONES AL WP-LOGIN EN AL MENOS $THRESHOLD_WPLOGIN_SITES SITIOS"
                    block_ip "$IP2" "6"
                    echo -e "\t(bloqueada en el router)"
                    mark_ip_reported "$IP2"
                    echo "$IP2" >> "$FILE_IP_BLACKLIST_V6"
                else
                    echo
                fi
            elif [ "$IPVERSION" = "4" ]; then
                C1=$(grep "$IP2" "$LOG_APACHE" | wc -l)
                C2=$(is_country_blacklisted "$PAIS")
                C3=$(grep "$IP2" "$FILE_TRUSTED_NETS" 2>/dev/null)
                if { [ "$C1" -ge "$THRESHOLD_TOTAL_APPEARANCES" ] || [ -z "$C2" ]; } && [ -z "$C3" ]; then
                    CLOUDFLARE=$(is_cloudflare "$IP2")
                    if [ -z "$CLOUDFLARE" ]; then
                        log_block "$IP2" "MAS DE $THRESHOLD_WPLOGIN_HITS CONEXIONES AL WP-LOGIN EN AL MENOS $THRESHOLD_WPLOGIN_SITES SITIOS"
                        block_ip "$IP2" "4"
                        echo -e "\t(bloqueada en el router)"
                        mark_ip_reported "$IP2"
                    else
                        echo -e "\t(Pertenece a cloudflare)"
                    fi
                else
                    echo
                fi
            fi
        fi
    done
fi

# =============================================================================
# CHECK 3: IPs con más de $THRESHOLD_XMLRPC_POSTS POSTs a xmlrpc.php
# =============================================================================

> "$TMP_XMLRPC"
fgrep xmlrpc.php "$LOG_APACHE" | fgrep POST \
    | awk '{print $6}' \
    | grep -vE "$(cat "$FILE_IP_WHITELIST")" \
    | sort | uniq -c \
    | awk -v t="$THRESHOLD_XMLRPC_POSTS" '$1 > t' \
    | sort -nrk1 | head -10 \
    >> "$TMP_XMLRPC"

CHECK3=$(cat "$TMP_XMLRPC" | grep -vE "$(cat "$TMP_IP_REPORTED")")
if [ -n "$CHECK3" ]; then
    TITULO=0
    cat "$TMP_XMLRPC" | grep -vE "$(cat "$TMP_IP_REPORTED")" | while read CONECT3 IP3; do
        if grep -q "$IP3" "$FILE_IP_BLACKLIST_V6" 2>/dev/null \
           || grep -q "$IP3" "$FILE_IGNORE_IPS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nIPs CON MAS DE $THRESHOLD_XMLRPC_POSTS POST AL ARCHIVO xmlrpc.php\n"
            echo -e "Conex\tIP\t\tOrigen"
            TITULO=1
        fi
        echo -n "$CONECT3  $IP3  "
        PAIS=$(geoip_lookup "$IP3")
        echo -n "$PAIS"
        IPVERSION=$(get_ip_version "$IP3")

        if [ "$IPVERSION" = "6" ]; then
            C2=$(is_country_blacklisted "$PAIS")
            C3=$(grep "$IP3" "$LOG_APACHE" | awk '{print $8}' | sort | uniq -c | wc -l)
            C4=$(grep "$IP3" "$TMP_LOG_LAST_MIN" | fgrep xmlrpc.php | wc -l)
            C5=$(grep "$IP3" "$FILE_IP_BLACKLIST_V6" 2>/dev/null)
            if { [ "$CONECT3" -ge "$THRESHOLD_XMLRPC_TOTAL" ] || [ -z "$C2" ] || [ "$C3" -ge 2 ] || [ "$C4" -ge "$THRESHOLD_XMLRPC_MIN" ]; } && [ -z "$C5" ]; then
                log_block "$IP3" "MAS DE $THRESHOLD_XMLRPC_POSTS POST AL ARCHIVO xmlrpc.php"
                block_ip "$IP3" "6" "-f"
                echo -e "\t(bloqueada en el router)"
                mark_ip_reported "$IP3"
                echo "$IP3" >> "$FILE_IP_BLACKLIST_V6"
            else
                echo
            fi
        elif [ "$IPVERSION" = "4" ]; then
            C2=$(is_country_blacklisted "$PAIS")
            C3=$(grep "$IP3" "$LOG_APACHE" | awk '{print $8}' | sort | uniq -c | wc -l)
            C4=$(grep "$IP3" "$TMP_LOG_LAST_MIN" | fgrep xmlrpc.php | wc -l)
            C5=$(grep "$IP3" "$FILE_TRUSTED_NETS" 2>/dev/null)
            if { [ "$CONECT3" -ge "$THRESHOLD_XMLRPC_TOTAL" ] || [ -z "$C2" ] || [ "$C3" -ge 2 ] || [ "$C4" -ge "$THRESHOLD_XMLRPC_MIN_V4" ]; } && [ -z "$C5" ]; then
                CLOUDFLARE=$(is_cloudflare "$IP3")
                if [ -z "$CLOUDFLARE" ]; then
                    log_block "$IP3" "MAS DE $THRESHOLD_XMLRPC_POSTS POST AL ARCHIVO xmlrpc.php"
                    block_ip "$IP3" "4" "-f"
                    echo -e "\t(bloqueada en el router)"
                    mark_ip_reported "$IP3"
                else
                    echo -e "\t(Pertenece a cloudflare)"
                fi
            else
                echo
            fi
        fi
    done
fi

# =============================================================================
# CHECK 4: Dominios con ataque distribuido al wp-login
# =============================================================================

> "$TMP_WP_LOGIN_X_DOM"
fgrep wp-login "$LOG_APACHE" \
    | awk '{print $8" "$6}' \
    | grep -vE "$(cat "$FILE_IP_WHITELIST")" \
    | grep -vwE "$(grep -v '#' "$FILE_IGNORE_IPS" | tr '\n' '|' | sed 's/|$//')" \
    | sort -k1 | uniq -c \
    | awk '{print $2}' | uniq -c | sort -rk1 \
    | awk -v t=30 '$1 > t' \
    | head -10 \
    >> "$TMP_WP_LOGIN_X_DOM"

# Limpiar dominios ya reportados
while IFS= read -r dom; do
    [[ "$dom" =~ ^# ]] && continue
    sed -i "/${dom}$/d" "$TMP_WP_LOGIN_X_DOM"
done < "$FILE_REPORTED_DOMAINS"

CHECK4=$(cat "$TMP_WP_LOGIN_X_DOM")
if [ -n "$CHECK4" ]; then
    TITULO=0
    awk '{print $2}' "$TMP_WP_LOGIN_X_DOM" | while read DOMAIN; do
        if grep -wiq "$DOMAIN" "$FILE_REPORTED_DOMAINS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nDOMINIOS CON ATAQUE DISTRIBUIDO AL WP-LOGIN\n"
            echo -e "IPs\tDominio"
            TITULO=1
        fi
        if ! grep -wiq "$DOMAIN" "$FILE_REPORTED_DOMAINS" 2>/dev/null; then
            DOMAIN=$(echo "$DOMAIN" | sed 's/www\.//')
            echo -e "$DOMAIN  (se protege wp-login.php y se abre ticket al cliente)"
            echo "$DOMAIN" >> "$FILE_REPORTED_DOMAINS"
            SERVER=$(grep "$DOMAIN" "$LOG_APACHE" | head -1 | awk '{print $4}' | cut -d'.' -f1)
            if [ -z "$(echo "$SERVER" | grep -v "${FIS_REGEX}")" ]; then
                SERVER=$(echo "$SERVER" | cut -c1-4)
            fi
            "$SCRIPT_PROTECT_WP" "$DOMAIN" "$SERVER" >/dev/null 2>/dev/null
            # Obtener usuario del servidor y abrir ticket si corresponde
            # USER=$(sshpass -p "PASS" ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${ROUTER_USER}@${SERVER}" "${SCRIPT_GETUSER} ${DOMAIN} | tr -d '\r'")
            # Descomentar y ajustar la apertura de ticket según el sistema de soporte
        fi
    done
fi

# =============================================================================
# CHECK 5: IPs con más de $THRESHOLD_WPLOGIN_SINGLE conexiones al wp-login del mismo dominio
# =============================================================================

> "$TMP_WP_LOGIN_1_DOM"
fgrep wp-login "$LOG_APACHE" | grep -wv "GET" \
    | awk '{print $6" "$8" "$16}' \
    | fgrep -v " 401" \
    | awk '{print $1" "$2}' \
    | sort -k1 | uniq -c | sort -nrk1 | head -10 \
    | awk -v t="$THRESHOLD_WPLOGIN_SINGLE" '$1 > t' \
    >> "$TMP_WP_LOGIN_1_DOM"

CHECK5=$(cat "$TMP_WP_LOGIN_1_DOM" | grep -vE "$(cat "$TMP_IP_REPORTED")")
if [ -n "$CHECK5" ]; then
    TITULO=0
    cat "$TMP_WP_LOGIN_1_DOM" | grep -vE "$(cat "$TMP_IP_REPORTED")" | while read CONEX5 IP5 DOMINIO5; do
        if grep -q "$IP5" "$FILE_IP_BLACKLIST_V6" 2>/dev/null \
           || grep -q "$IP5" "$FILE_IGNORE_IPS" 2>/dev/null; then
            continue
        fi
        if [ "$TITULO" -eq 0 ]; then
            echo -e "\nIPs CON MAS DE $THRESHOLD_WPLOGIN_SINGLE CONEXIONES AL WP-LOGIN DEL MISMO DOMINIO\n"
            echo -e "Conex\tIP\t\tDominio\t\tOrigen"
            TITULO=1
        fi
        echo -n "$CONEX5  $IP5  $DOMINIO5  "
        PAIS=$(geoip_lookup "$IP5")
        echo -n "$PAIS"
        IPVERSION=$(get_ip_version "$IP5")

        if [ "$IPVERSION" = "6" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP5" "$TMP_LOG_LAST_MIN" | fgrep wp-login | wc -l)
            C3=$(grep "$IP5" "$LOG_APACHE" | awk '{print $8}' | sort | uniq -c | wc -l)
            C4=$(grep "$IP5" "$FILE_IP_BLACKLIST_V6" 2>/dev/null)
            if { [ -z "$C1" ] || [ "$C2" -ge "$THRESHOLD_WPLOGIN_MIN" ] || [ "$C3" -ge 2 ] || [ "$CONEX5" -ge "$THRESHOLD_XMLRPC_TOTAL" ]; } && [ -z "$C4" ]; then
                log_block "$IP5" "MAS DE $THRESHOLD_WPLOGIN_SINGLE CONEXIONES AL WP-LOGIN DEL MISMO DOMINIO"
                block_ip "$IP5" "6"
                echo -e "\t(bloqueada en el router)"
                mark_ip_reported "$IP5"
                echo "$IP5" >> "$FILE_IP_BLACKLIST_V6"
            else
                echo
            fi
        elif [ "$IPVERSION" = "4" ]; then
            C1=$(is_country_blacklisted "$PAIS")
            C2=$(grep "$IP5" "$TMP_LOG_LAST_MIN" | fgrep wp-login | wc -l)
            C3=$(grep "$IP5" "$LOG_APACHE" | awk '{print $8}' | sort | uniq -c | wc -l)
            C4=$(grep "$IP5" "$FILE_TRUSTED_NETS" 2>/dev/null)
            if { [ -z "$C1" ] || [ "$C2" -ge "$THRESHOLD_WPLOGIN_MIN" ] || [ "$C3" -ge 2 ] || [ "$CONEX5" -ge "$THRESHOLD_XMLRPC_TOTAL" ]; } && [ -z "$C4" ]; then
                CLOUDFLARE=$(is_cloudflare "$IP5")
                if [ -z "$CLOUDFLARE" ]; then
                    log_block "$IP5" "MAS DE $THRESHOLD_WPLOGIN_SINGLE CONEXIONES AL WP-LOGIN DEL MISMO DOMINIO"
                    block_ip "$IP5" "4"
                    echo -e "\t(bloqueada en el router)"
                    mark_ip_reported "$IP5"
                else
                    echo -e "\t(Pertenece a cloudflare)"
                fi
            else
                echo
            fi
        fi
    done
fi
