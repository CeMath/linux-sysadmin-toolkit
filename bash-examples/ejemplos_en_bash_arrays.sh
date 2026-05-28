#!/bin/bash

declare -A my_array

echo -e "\n- my_array=([foo]=bar [baz]=foobar)"
my_array=([foo]=bar [baz]=foobar)

echo -e "\n- my_array[@] (values)"
for value in "${my_array[@]}" ; do
    echo "${value}"
done

echo -e "\n- my_array[*] (values)"
for value in "${my_array[*]}" ; do
    echo "${value}"
done

echo -e "\n- !my_array[@] (keys)"
for key in "${!my_array[@]}" ; do
    echo "${key}"
done

echo -e "\n- !my_array[*] (keys)"
for key in "${!my_array[*]}" ; do
    echo "${key}"
done

echo -e "\n- the array contains ${#my_array[@]} elements"

echo -e "\n- my_array[foo]=\"bar\""
my_array[foo]="bar"

echo -e "- my_array+=([baz]=foobar [foobarbaz]=baz)"
my_array+=([baz]=foobar [foobarbaz]=baz)

echo -e "- unset my_array[foo]"
unset my_array[foo]

echo
echo ${my_array[@]}
echo ${!my_array[@]}
echo
