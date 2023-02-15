#!/bin/bash

function fix_ligand_pdb() {
    pdb=$1	# PDB file to fix
    LIG=$2	# ligand resname
    L=$3	# ligand chain

    f=`basename $pdb .pdb`
    #check $L
    if [ "$R" == "" ] ; then R="A" ; fi		# this is ignored now
    if [ "$L" == "" ] ; then L="L" ; fi

    # CAUTION: THIS WILL ONLY WORK FOR ONE LIGAND!

    # check if the ligand is present in the PDB file
    if grep -q ".\{17}$LIG " ; then
        echo "$pdb contains $LIG"
        return
    else
        echo "$pdb does NOT contain $LIG"
        return
    fi

    # the ligand should figure as HETATM, but just in case it is a
    # residue tagged with ATOM records
    #LIG=`echo $pdb | sed -e 's/.*_//g' -e 's/\.pdb$//g'
    resligand=`grep -q "^ATOM  .\{11\}$LIG"`
    if $resligand ; then
        echo "$pdb contains ATOM ... $LIG"
        # change record type only for ATOM  ... $LIG lines
        sed -e "/^ATOM  .\{11\}$LIG/ s/^ATOM  /HETATM/g"
    fi

    hetligand=`grep -q "^HETATM" $pdb`
        
    if ! $hetligand ; then
        echo "NO $LIG found in $pdb !!!"
        return
    fi

        echo "ligand is $LIG"
        # check if the ligand has that name
        if grep -q "^HETATM.\{11\}$LIG" $pdb ; then
            # remove any other ligand that might be present
            grep "^HETATM.\{11\}$LIG\|^ATOM" $pdb > $pdb.lig
        else
            # not found, fixing all HETATM to belong to the ligand $LIG !!!
            # NOTE: should there be more than one ligand, this will wreak havoc
            sed -e "/^HETATM/ s/^\(.\{17\}\).../\1$LIG/g" $pdb > $pdb.lig
        fi
        # at this point all HETATM should correspond to the same residue ($LIG)
        # check if the ligand chain has the correct name
        #if grep -q "^HETATM.\{11\}$LIG [^$L]" ; then
        #    # there is at least one HETATM that has not the correct chain id
        #fi
        # we'll just simply coerce all HETATM to belong to $L
        sed -e "/^HETATM/ s/^\(.\{21\}\)./\1$L/g" $pdb.lig > $pdb.ok
        mv $pdb $pdb.orig
        rm $pdb.lig
        # we'll leave conect records and hydrogens
        grep -v "^WARNING" $pdb.ok > $pdb
        # we need to leave hydrogens in case there are peptidic conect records
        # so that atom referencing is preserved
    fi
}

if [[ $0 == $BASH_SOURCE ]] ; then
    fix_ligand_pdb $*
else
    export fix_ligand_pdb
fi
