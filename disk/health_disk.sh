#!/bin/bash
#
# health_disk.sh
#
# Diagnóstico completo de discos físicos en servidores Linux.
# Para cada disco detectado (excepto el disco del sistema):
#   - Habilita soporte SMART si está desactivado
#   - Formatea y particiona el disco para testeo
#   - Test de escritura  (dd bs=1G  count=1)
#   - Test de latencia   (dd bs=512 count=1000)
#   - Test de lectura    (dd bs=512 count=1000)
#   - Chequeo de atributos SMART críticos:
#       ID   5 — Reallocated Sector Count
#       ID   9 — Power On Hours
#       ID 187 — Reported Uncorrectable Errors
#       ID 188 — Command Timeout
#       ID 196 — Reallocated Event Count
#       ID 197 — Current Pending Sector Count
#       ID 198 — Offline Uncorrectable Sectors
#   - Short test SMART con resultado final
#
# Uso:
#   sudo ./health_disk.sh
#
# Logs generados en ./logs/ :
#   logListDisk  — listado de discos testeados
#   logTest      — resumen completo del testeo
#
# Notas:
#   - Si algún disco está montado antes de correr el script,
#     desmontar manualmente o descomentar la línea de umount al inicio.
#   - El disco que contiene /boot se excluye automáticamente del testeo.
#
# Dependencias: smartmontools, util-linux (fdisk, sfdisk), e2fsprogs (mkfs.ext4), hdparm
#

# ── Colores ────────────────────────────────────────────────
AZUL="\e[34m"
LAZUL="\e[94m"
VERDE="\e[32m"
ROJO="\e[31m"
LAMARILLO="\e[93m"
LMAGENTA="\e[95m"
CIAN="\e[36m"
NARANJA="\e[33m"
BOLD="\e[1m"
SUB="\e[4m"
ENDCOLOR="\e[0m"

# ── Verificar root ─────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}Este script debe ejecutarse como root.${ENDCOLOR}"
    exit 1
fi

clear

# Desmontar discos si fuera necesario — descomentar y ajustar el punto de montaje
# umount -a /media/*

# ── Carpeta de logs ────────────────────────────────────────
SCRIPT_DIR="$(dirname -- "$0")"
LOG_DIR="${SCRIPT_DIR}/logs"

if [ ! -d "${LOG_DIR}" ]; then
    echo -e "${BOLD}${LMAGENTA}"
    echo -e " -------------------------------------------------------------------------------------------"
    echo -e "                 Creando carpeta de logs..."
    echo -e " -------------------------------------------------------------------------------------------${ENDCOLOR}"
    mkdir "${LOG_DIR}"
else
    echo -e "${BOLD}${LAMARILLO}"
    echo -e " -----------------------------------------------------------------------------------------"
    echo -e "                              Carpeta de logs encontrada"
    echo -e " -----------------------------------------------------------------------------------------${ENDCOLOR}"
fi

# ── Rutas de logs ──────────────────────────────────────────
discos="${LOG_DIR}/logListDisk"
testeo="${LOG_DIR}/logTest"
latencia="${LOG_DIR}/Latencia"
escritura="${LOG_DIR}/Escritura"
lectura="${LOG_DIR}/Lectura"
errors="${LOG_DIR}/errors"

> "${discos}"
> "${testeo}"
> "${latencia}"
> "${escritura}"
> "${lectura}"

# ── Detectar discos ────────────────────────────────────────
fdisk -l | grep -i "Disk /dev/sd" | awk '{print $2}' | cut -d":" -f1 | cut -d"/" -f3 > "${discos}"

# Excluir el disco que contiene /boot
principal="$(df -l | grep /boot | awk '{print $1}' | cut -d":" -f1 | cut -d"/" -f3 | cut -b -3)"
sed -i "s/${principal}//g" "${discos}"
sed -i '/^$/d' "${discos}"

echo -e "${BOLD}${LAMARILLO}"
echo -e " -------------------------------------------------------------------"
echo -e " Se realizará el formateo y testeo de los siguientes discos:"
echo -e " -------------------------------------------------------------------${ENDCOLOR}"
cat "${discos}"
echo -e "\n${BOLD}${LAMARILLO}Presione [ENTER] para continuar o [Ctrl+C] para cancelar${ENDCOLOR}"
read -r

# ── Loop principal ─────────────────────────────────────────
while read -r disk; do

    # Habilitar soporte SMART si está desactivado
    if smartctl -i /dev/${disk} | grep -q 'SMART support is: Disabled\|SMART support is: Unavailable'; then
        smartctl -T permissive /dev/${disk} > /dev/null
        smartctl -s on /dev/${disk} > /dev/null
    fi

    echo -e "\n\n\n                    ${BOLD}${CIAN}---------------------------------------------"
    echo -e "                    Disco a testear: /dev/${disk}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e "                    $(hdparm -i /dev/${disk} | grep Serial | awk '{print $1, $2, $4}')" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

    # ── Atributos SMART críticos ───────────────────────────
    ReallSec=$(smartctl -A /dev/${disk} | grep -i Reallocated_Sector_Ct    | awk 'NR==1{print $10}'); ReallSec=${ReallSec:-0}
    Hour=$(    smartctl -A /dev/${disk} | grep -i Power_On_Hours            | awk 'NR==1{print $10}'); Hour=${Hour:-0}
    ReporUnco=$(smartctl -A /dev/${disk} | grep -i Reported_Uncorrect       | awk 'NR==1{print $10}'); ReporUnco=${ReporUnco:-0}
    CommTime=$( smartctl -A /dev/${disk} | grep -i Command_Timeout          | awk 'NR==1{print $10}'); CommTime=${CommTime:-0}
    ReallEven=$(smartctl -A /dev/${disk} | grep -i Reallocated_Event_Count  | awk 'NR==1{print $10}'); ReallEven=${ReallEven:-0}
    PendSec=$(  smartctl -A /dev/${disk} | grep -i Current_Pending_Sector_Ct | awk 'NR==1{print $10}'); PendSec=${PendSec:-0}
    OffUnco=$(  smartctl -A /dev/${disk} | grep -i Offline_Uncorrectable    | awk 'NR==1{print $10}'); OffUnco=${OffUnco:-0}

    echo -e "                    El disco tiene ${Hour} horas de uso" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e "                    --------------------------------------------- ${ENDCOLOR}\n" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

    # ── Formateo y particionado ────────────────────────────
    echo -e "${BOLD}${LAMARILLO}"
    echo -e " -----------------------------------------------------------------------------------------"
    echo -e "                          Formateamos el disco y particionamos"
    echo -e " -----------------------------------------------------------------------------------------${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

    echo 'type=83' | sfdisk /dev/${disk} &> /dev/null
    mkfs.ext4 /dev/${disk}1 &> "${errors}"

    if grep -q "Not enough space to build proposed filesystem while setting up superblock" "${errors}"; then
        echo -e "${BOLD}${ROJO}"
        echo -e " No se pudo formatear el disco /dev/${disk} debido a errores irrecuperables."
        echo -e " El tamaño reportado por lsblk no corresponde al tamaño real del disco."
        echo -e " Se debe dar de baja el disco.\n"
        echo -e " lsblk:${ENDCOLOR}"
        lsblk | grep "${disk}"
        echo -e "${BOLD}${LAMARILLO} -----------------------------------------------------------------------------------------${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
        continue
    fi

    mount /dev/${disk}1 /mnt

    # ── Test de escritura ──────────────────────────────────
    echo -e "${BOLD}${LAMARILLO}"
    echo -e " -----------------------------------------------------------------------------------------"
    echo -e "                                  Test de escritura"
    echo -e " -----------------------------------------------------------------------------------------${ENDCOLOR}"

    dd if=/dev/zero of=/tmp/test1.img bs=1G count=1 oflag=dsync &> "${escritura}"
    aux=$(grep copied "${escritura}" | awk '{print $10,$11}')
    echo -e "${BOLD}${LMAGENTA} Velocidad de escritura: ${aux}${ENDCOLOR}\n"

    # ── Test de latencia ───────────────────────────────────
    echo -e "${BOLD}${LAMARILLO}"
    echo -e " -----------------------------------------------------------------------------------------"
    echo -e "                                  Test de latencia"
    echo -e " -----------------------------------------------------------------------------------------${ENDCOLOR}"

    dd if=/dev/zero of=/tmp/test2.img bs=512 count=1000 oflag=dsync &> "${latencia}"
    aux=$(grep copied "${latencia}" | awk '{print $10,$11}')
    echo -e "${BOLD}${LMAGENTA} Velocidad de latencia (escrituras pequeñas): ${aux}${ENDCOLOR}\n"

    # ── Test de lectura ────────────────────────────────────
    echo -e "${BOLD}${LAMARILLO}"
    echo -e " -----------------------------------------------------------------------------------------"
    echo -e "                                  Test de lectura"
    echo -e " -----------------------------------------------------------------------------------------${ENDCOLOR}"

    dd if=/dev/zero of=/tmp/test3.img bs=512 count=1000 oflag=dsync &> "${lectura}"
    aux=$(grep copied "${lectura}" | awk '{print $10,$11}')
    echo -e "${BOLD}${LMAGENTA} Velocidad de lectura: ${aux}${ENDCOLOR}\n"

    rm -f /tmp/test1.img /tmp/test2.img /tmp/test3.img
    umount /mnt

    # ── Resumen atributos SMART ────────────────────────────
    echo -e "${BOLD}${LAZUL}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ----------------------------------------------------------------------------------------" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ----------------------------- Check de atributos críticos ------------------------------" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " -------- Cualquier valor mayor a cero representa una potencial falla de disco ----------" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ----------------------------------------------------------------------------------------${ENDCOLOR}\n" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

    echo -e " ${BOLD}${AZUL}Atr   5 - ${SUB}Sectores relocalizados:${ENDCOLOR}${BOLD}${VERDE}             ${ReallSec}${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr   9 - ${SUB}Horas de uso:${ENDCOLOR}${BOLD}${VERDE}                       ${Hour}${ENDCOLOR}"     | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr 187 - ${SUB}Lecturas fallidas:${ENDCOLOR}${BOLD}${VERDE}                  ${ReporUnco}${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr 188 - ${SUB}Timeouts de comando:${ENDCOLOR}${BOLD}${VERDE}                ${CommTime}${ENDCOLOR}"  | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr 196 - ${SUB}Eventos de reasignación:${ENDCOLOR}${BOLD}${VERDE}            ${ReallEven}${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr 197 - ${SUB}Sectores pendientes de relocalización:${ENDCOLOR}${BOLD}${VERDE} ${PendSec}${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    echo -e " ${BOLD}${AZUL}Atr 198 - ${SUB}Sectores defectuosos irrecuperables:${ENDCOLOR}${BOLD}${VERDE}  ${OffUnco}${ENDCOLOR}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

    # ── Short test SMART ───────────────────────────────────
    aux=$(smartctl -t short /dev/${disk} | grep -i Please | awk '{print $3}')

    if [ -n "${aux}" ]; then
        echo -e "${BOLD}${ROJO}" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
        echo -e " ----------------------------------------------------------------------------------------" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
        echo -e "     Se realizará un short test SMART, durará aproximadamente ${aux} minuto/s" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
        echo -e "                           Espere por favor..." | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
        echo -e " ----------------------------------------------------------------------------------------${ENDCOLOR}\n" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")

        sleep $(( aux * 60 ))

        aux=$(smartctl -H /dev/${disk} | grep -i result | awk 'NR==1{print $6}')
        echo -e " ${BOLD}${AZUL}${SUB}Resultado del test:${ENDCOLOR}${BOLD}${VERDE} ${aux}${ENDCOLOR}\n" | tee >(sed $'s/\033[[][^A-Za-z]*m//g' >> "${testeo}")
    else
        echo " Ya hay un testeo de disco en curso, aguarde o cancélelo con: smartctl -X /dev/${disk}"
    fi

    # ── Veredicto final ────────────────────────────────────
    if [ "${ReallSec}" -ne 0 ] || [ "${ReporUnco}" -ne 0 ] || [ "${CommTime}" -ne 0 ] || \
       [ "${ReallEven}" -ne 0 ] || [ "${PendSec}"  -ne 0 ] || [ "${OffUnco}"  -ne 0 ]; then
        echo -e "${BOLD}${ROJO}"
        echo -e " -------------------------------------------------------------------------------------------"
        echo -e " ADVERTENCIA: El disco /dev/${disk} tiene atributos SMART críticos con valor > 0."
        echo -e " Es probable que falle a corto plazo. Se recomienda dar de baja el hardware."
        echo -e " -------------------------------------------------------------------------------------------${ENDCOLOR}"
    fi

done < "${discos}"

echo -e "\n${BOLD}${NARANJA} Logs guardados en: ${LOG_DIR}/${ENDCOLOR}\n"

# Desmontar discos si fuera necesario — descomentar y ajustar el punto de montaje
# umount -a /media/*

# Limpiar logs temporales
rm -f "${latencia}" "${escritura}" "${lectura}"
