#!/bin/bash

echo -e "\nKernel actual:"
uname -r

echo -e "\nKernels instalados:"
dpkg -l | awk '/linux-image-/ {print $2}' | grep -v "linux-image-[a-z]" | sort -V

K_ACTUAL=`uname -r | cut -d - -f -2`
K_ULTIMO=`dpkg -l | awk '/linux-image-[2345]/ {print $2}' | sort -V | tail -1 | cut -d - -f 3-4`

if [ -z "$(dpkg -l | grep -e "linux-[him].*-[2345]" | awk '{print $2}' | grep -v -e "${K_ULTIMO}" -e "${K_ACTUAL}")" ] ; then
    echo -e "\nNo hay kernels para purgar. Saliendo.\n"
    exit
fi

echo -e "\nPaquetes a purgar:"
dpkg -l | grep -e "linux-[him].*-[2345]" | awk '{print $2}' | grep -v -e "${K_ULTIMO}" -e "${K_ACTUAL}" | sort -V

echo -en "\nPurgar los paquetes listados? (S/N): "
read RTA

if [ "${RTA}" == "S" ] ; then
    echo -e "\nPurgando paquetes...\n"
    apt-get purge `dpkg -l | grep -e "linux-[him].*-[2345]" | awk '{print $2}' | grep -v -e "${K_ULTIMO}" -e "${K_ACTUAL}"`
    echo -e "\nListo!\n"
else
    echo -e "\nSaliendo.\n"
fi
