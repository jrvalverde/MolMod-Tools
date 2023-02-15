#!/bin/bash

function pdb_rename_chain() {
    pdb=$1
    A=${2:-Z}
    B=${3:-Z}
    
    if [ "$A" == "$B" ] ; then
        echo "Origin chain $A is the same as destination chain $B"
        return
    fi
    if [ ! -s "$pdb" ] ; then
        echo "Usage: file.pdb [one-letter-origin] [one-letter-destination]"
        return
    fi
    #if grep -q "^.\{21\}$B" $pdb ; then
    if grep -q "^\(ATOM  \|HETATM\).\{15\}$B" $pdb ; then
        echo "Destination chain $B already exists in $pdb !"
        return
    fi
    if ! grep -q "^\(ATOM  \|HETATM\).\{15\}$A" $pdb ; then
        echo "Origin chain $A is not present in $pdb !"
        return
    fi

    # change ATOM/HETATOM records in chain $A to chain $B
    cp $pdb $pdb.bck
    sed -e "/^\(ATOM  \|^HETATM\).\{15\}$A/ s/^\(.\{21\}\)$A/\1$B/g" \
        $pdb.bck > $pdb

    return
}

if [[ $0 == $BASH_SOURCE ]] ; then
    pdb_rename_chain $*
else
    export _pdb_rename_chain
fi
