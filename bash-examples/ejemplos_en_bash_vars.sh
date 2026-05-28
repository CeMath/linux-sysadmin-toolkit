#!/bin/bash

SPECIALS=( "~" "@" "%" "-" "_" "=" "+" "," "." )
echo -e "\n- Caracter aleatorio de un array (${SPECIALS[@]}):"
SIZE=${#SPECIALS[@]}
INDICE=$((${RANDOM} % ${SIZE}))
echo ${SPECIALS[$INDICE]}

echo -e "\nEjemplos de uso de cadenas en bash"
echo -e "----------------------------------"

echo -e "\n- Variable \${myvar} con valor default:"
echo "${myvar:=default}"

echo -e "\n- Variable \${myvar2} vacia da error y sale!:"
echo "${myvar2:?ERROR: la variable myvar no esta definida}"

echo

exit
