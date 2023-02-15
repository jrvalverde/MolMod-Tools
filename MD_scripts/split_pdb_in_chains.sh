#!/bin/bash

file=$1
name=`basename $1 .pdb`

for i in `grep -E "^(ATOM  |HETATM)" $file | \
	 cut -c 22 | \
         sort | \
         uniq` ; do
    echo "Extracting chain $i from $file as ./${name}_${i}.(pdb|mol2)"
    if ! grep "^.\{21\}$i" $file > ${name}_${i}.pdb ; then
        rm ${name}_${i}.pdb
    else
        babel --partialcharge qtpie \
              -ipdb ${name}_${i}.pdb \
              -omol2 ${name}_${i}.mol2
    fi
done
