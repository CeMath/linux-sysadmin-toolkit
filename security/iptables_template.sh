#!/bin/bash
#
# iptables_template.sh
#
# Template de reglas iptables básico para servidores Linux.
# Configura un firewall con política restrictiva de entrada:
#   - Permite tráfico loopback y conexiones establecidas
#   - Permite ICMP (ping)
#   - Permite SSH solo desde IPs/redes autorizadas
#   - Permite un puerto SSH alternativo (por defecto 4445)
#   - Bloquea el puerto SSH estándar (22) para el resto
#   - Permite acceso total desde IPs de monitoreo
#
# Uso:
#   1. Ajustar las variables de configuración en la sección de abajo
#   2. sudo ./iptables_template.sh
#
# Para hacer las reglas persistentes:
#   Debian/Ubuntu: apt install iptables-persistent && netfilter-persistent save
#   CentOS/RHEL:   service iptables save
#
# Dependencias: iptables
#

# ── Configuración — ajustar antes de ejecutar ──────────────

# IPs o rangos con acceso SSH (separadas por espacios)
# Ejemplo: "192.168.1.0/24" o "10.0.0.5 10.0.0.6"
SSH_ALLOWED_NETWORKS="192.168.1.0/24"

# IPs de servidores de monitoreo con acceso total
# Ejemplo: "203.0.113.10 203.0.113.11"
MONITORING_IPS=""

# Puerto SSH alternativo (dejar vacío para no abrir ninguno)
SSH_ALT_PORT="4445"

# ──────────────────────────────────────────────────────────

IPTABLES="/sbin/iptables"

# Verificar root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# ── Limpiar reglas existentes ──────────────────────────────
${IPTABLES} -F
${IPTABLES} -Z

# ── Loopback ───────────────────────────────────────────────
${IPTABLES} -A INPUT -i lo -j ACCEPT

# ── Conexiones establecidas y relacionadas ─────────────────
${IPTABLES} -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# ── ICMP (ping) ────────────────────────────────────────────
${IPTABLES} -A INPUT -p icmp -j ACCEPT

# ── IPs de monitoreo con acceso total ─────────────────────
for ip in ${MONITORING_IPS}; do
    ${IPTABLES} -A INPUT -s "${ip}" -j ACCEPT
done

# ── SSH solo desde redes autorizadas ──────────────────────
for network in ${SSH_ALLOWED_NETWORKS}; do
    ${IPTABLES} -A INPUT -p tcp --dport 22 -s "${network}" -j ACCEPT
done

# ── Puerto SSH alternativo ─────────────────────────────────
if [ -n "${SSH_ALT_PORT}" ]; then
    ${IPTABLES} -A INPUT -p tcp --dport "${SSH_ALT_PORT}" -j ACCEPT
fi

# ── Bloquear puerto SSH estándar para el resto ─────────────
${IPTABLES} -A INPUT -p tcp --dport 22 -j REJECT

# ── Verificación final ─────────────────────────────────────
echo
echo "## Reglas aplicadas ##"
${IPTABLES} -L -n -v --line-numbers
