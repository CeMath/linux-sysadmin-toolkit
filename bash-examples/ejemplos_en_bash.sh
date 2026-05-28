#!/bin/bash

CADENA="UnaCadenaLargaDeEjemplo"

echo -e "\nEjemplos de uso de cadenas en bash"
echo -e "----------------------------------"
echo -e "\nCADENA = ${CADENA}"

echo -e "\n- CADENA tiene ${#CADENA} caracteres de largo"

echo -e "\n- CADENA dice \"cadena\" a partir del $(expr index ${CADENA} Cadena)º caracter (se cuenta desde 0)"
echo -e "\n- Subcadena a partir del 9º caracter (index = 8): ${CADENA:8}"
echo -e "\n- Subcadena de 5 caracteres a partir del 9º caracter: ${CADENA:8:5}"

echo -e "\n- CADENA sin \"una\" al principio (simil sed): ${CADENA#Una}"
echo -e "\n- CADENA sin \"deejemplo\" al al final (simil sed): ${CADENA%DeEjemplo}"

echo -e "\n- Reemplazo (al estilo sed 's//'): ${CADENA/Larga/MuchoMasLarga}"
echo -e "\n- Reemplazo global (al estilo sed 's//g'): ${CADENA//a/A}"

echo -e "\n- Cadena sin capitalizar: ${CADENA,}"
echo -e "\n- Cadena en minusculas:   ${CADENA,,}"

echo -e "\n- Cadena capitalizada:    ${CADENA^}"
echo -e "\n- Cadena en mayusculas:   ${CADENA^^}"

echo -e "\nAWK: reemplazar una determinada columna"
echo -e "1 2 3 4\n4 3 2 1\n9 8 7 6\n6 7 8 9" | awk '{gsub(".*", "x", $2)}1'

echo -e "\n- Variable referenciada por cadena\n\$ variable_to_inspect=\"HOME\"\n\$ echo \${!variable_to_inspect}:"
#variable_to_inspect="HOME"
#echo "${!variable_to_inspect}"

files="$(ls -d x* y* z* 2>/dev/null)"
PS3="Tu eleccion?: "
echo -e "\n- Elije un archivo de la lista siguiente:"
select filename in ${files} ; do
    echo -e "\nHas seleccionado ${filename}"
    ls --color -ld "${filename}"
    break
done

echo -e "\n ----------------------------------"

echo -e "\n- Quitar o reemplazar la ultima ocurrencia de un caracter: rpm -qa | sort | rev | sed 's/-/ /' | rev"

getnum() {
    echo $2
}

echo -e "\n- Simil awk con funcion getnum:  $(getnum `grep ^MemFree: /proc/meminfo`)"

echo -e "\n- Sumatoria de nros: cat cant_users_x_server.txt | paste -sd+ | bc"

echo -e "\n- Pi con bc: $(echo 'scale=5; 4*a(1)' | bc -l)"

echo -e "\n- Ver mas en:\n  https://www.linuxjournal.com/content/whats-new-bash-parameter-expansion\n  https://linuxconfig.org/introduction-to-bash-shell-parameter-expansions"

#echo -e "\n- "

echo

exit
