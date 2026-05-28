#!/bin/bash

CADENA="Dattatec.com"
REGEX="[A-Za-z0-9\.]+"

if [[ ${CADENA} =~ ${REGEX} ]] ; then
    echo "${CADENA} matchea la regex"
fi

echo "This sentence has has repeated words" | egrep --color "(\b[[:alpha:]]+\b) \1"
