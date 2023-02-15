#!/bin/bash

for i in */md*.log ; do 
    echo -n $i ': '
    grep 'DD  step' $i | tail -1 | cut -d' ' -f4
done
