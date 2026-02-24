#!/bin/bash

file=$1
name=`basename $1 .pdb`

# chain is in column 22
# when we grep the chain, we seek for it in ATOM(4 char) lines 
# so we want the char after (4+17=21)
for i in `grep -E "^(ATOM  |HETATM)" $file | \
	 cut -c 22 | \
         sort | \
         uniq` ; do
    echo "Extracting chain $i from $file as ./${name}_${i}.(pdb|mol2)"
    if ! grep -e "^REMARK" -e "^TITLE" -e "^CRYST" \
              -e "^MODEL" -e "^ENDMDL" \
              -e "^ATOM.\{17\}$i" $file \
              -e "^ANISOU.\{15\}$i" $file \
               > ${name}_${i}.pdb ; then
        rm ${name}_${i}.pdb
    else
	    echo "Converting to ${name}_${i}.mol2"
        obabel --partialcharge qtpie \
               -ipdb ${name}_${i}.pdb \
               -omol2 \
			   -O ${name}_${i}.mol2
    fi
done
