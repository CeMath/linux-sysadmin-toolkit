#!/bin/bash

ayuda() {
    echo -e "   Uso $0 [-a] [-b ALGO] [-c] [-l MENSAJE]\n"
    exit $1  ## 1er parametro pasado a la funcion, no al script!
}

while getopts "ab:chl:" OPCION ; do
    case ${OPCION} in
        "a")
            echo "-a especificado"
            ;;
        "b")
            echo "-b especificado con parametro ${OPTARG}"
            ;;
        "c")
            echo "-c especificado"
            ;;
        "l")
            echo "-l especificado, activando logging en syslog (si se puede)"
            LOG="y"
            MSG="${OPTARG}"
            ;;
        "h")
            ayuda 0
            ;;
        \?)  ## No andara con *?
            echo "Opcion invalida: -${OPTARG}" >&2  ## A la salida de error
            ayuda 1
            ;;
    esac
done

registrar() {
    if [ "${LOG}" == "y" ] ; then
	logger $@
	echo
	tail -1 /var/log/syslog
	echo
    fi
}

registrar "Mensaje desde el mas aca: ${MSG}"

shift $((OPTIND-1))  ## Eliminamos las opciones para que solo queden los parametros requeridos

lockfile="/tmp/$$"  ## $$ es el PID del proceso actual

vete() {
    echo
    rm ${lockfile}
    exit
}

trap vete SIGINT

touch ${lockfile}
echo -e "\nDurmiendo 5 segundos (${lockfile} creado)"
sleep 5
rm ${lockfile}

echo -e "\nDurmiendo 30 segundos pero muriendo en 3"
(sleep 3 ; kill -SIGALRM $$) &
sleep 30

# Salida
echo
