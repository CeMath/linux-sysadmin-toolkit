#!/bin/bash

echo -en "\nUsando:\nkernel-"
uname -r
echo -e "\nInstalados:"

if [ -f /etc/debian_version ] ; then
    dpkg -l | awk '/linux-image-/ {print $2}' | grep -v "linux-image-[a-z]" | sort -V
elif grep -qs 'Arch Linux' /etc/os-release ; then
    pacman -Q linux
elif egrep -qs "(CentOS |Alma|Rocky )Linux release [78]" /etc/redhat-release ; then
    rpm -q kernel kernel-PAE kernel-debug kernel-lt kernel-ml kernel-plus kernel-core kernel-modules | grep -vE "est. inst|not inst" | sort -V
elif grep -qs "CentOS release 6" /etc/redhat-release ; then
    rpm -q kernel kernel-PAE kernel-debug kernel-lt kernel-ml kernel-plus xen | grep -vE "est. inst|not inst" | sort -V
else
    rpm -q kernel kernel-PAE kernel-debug kernel-lt kernel-ml kernel-plus kernel-xen xen xen-hypervisor | grep -vE "est. inst|not inst" | sort
fi
echo
