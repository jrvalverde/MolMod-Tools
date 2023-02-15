#!/bin/bash

function pdb_fix_ligand() {
    pdb=$1	# PDB file to fix
    LIG="${2:-LIG}"	# ligand resname (preserving special characters: * ...)
    L=${3:-L}	# ligand chain

    f=`basename $pdb .pdb`

    # CAUTION: THIS WILL ONLY WORK FOR ONE LIGAND! XXX JR XXX

    echo "Checking ligand $LIG in $pdb"
    # check if the ligand is present in the PDB file
    if ! grep -q "^.\{17\}$LIG" $pdb ; then
        echo "$pdb does NOT contain $LIG"
        return
    fi
    echo "$pdb appears to contain $LIG .. backing up"
    cp $pdb $pdb.sav

    ### JR ###
    # NEXT MAKES SENSE IF THE LIGAND IS A DRUG, NOT IF IT IS A PEPTIDE
    ### JR ###
    if [ "$ISPEPTIDE" == "YES" ] ; then
        return
    else
	# the ligand should figure as HETATM, but just in case it is a
	# residue tagged with ATOM records
	if grep -q "^ATOM  .\{11\}$LIG " $pdb ; then
            echo "$pdb contains ATOM ... $LIG .. fixing"
            # change record type only for ATOM  ... $LIG lines
            sed -e "/^ATOM  .\{11\}$LIG/ s/^ATOM  /HETATM/g" $pdb > $pdb.het
	else
            echo "$pdb does not contain ATOM ... $LIG .. OK"
            cp $pdb $pdb.het
	fi

	hetligand=`grep -q "^HETATM" $pdb.het`

	if ! grep -q "^HETATM" $pdb.het ; then
            echo "HORROR: NO HETATM ... $LIG found in $pdb.het !!!"
            return
	fi

	# ensure all ligand atoms belong in the correct chain
	#sed -e "s/^\(HETATM.\{11\}\)$LIG ./\1$LIG $L/g" $pdb.het > $pdb
	### JR ### and are named 'LIG' (to keeo original name use ${LIG:0:3}
	sed -e "s/^\(HETATM.\{11\}\)$LIG ./\1LIG $L/g" $pdb.het > $pdb
	rm $pdb.het

	# we should also ensure all ligand atoms have unique names...
	n=0
	grep "^HETATM.\{11\}$LIG $L" $pdb \
	| while read line ; do
            (( nn++ ))
	    rec=${line:0:6}		# extract variable:offset:length
	    serial=${line:6:5}
	    name=${line:12:4}
	    altloc=${line:16:1}
	    resname=${line:17:3}
	    chainid=${line:21:1}
	    resseq=${line:22:4}
	    icode=${line:26:1}
	    x=${line:30:8}
	    y=${line:38:8}
	    z=${line:46:8}
	    occupancy=${line:54:6}
	    tempfactor=${line:60:6}
	    element=${line:76:2}
	    charge=${line:78:2}
	    # manipulate the atom name
	    name=${name// }
	    name=${name:0:2}
	    name=${name}${nn}
	    # print out formatted record
	    #echo "rec=$rec serial=$serial name=$name altloc=$altloc resname=$resname"
	    #echo "chainid=$chainid resseq=$resseq icode=$icode x=$x y=$y z=$z"
	    #echo "occupancy=$occupancy tempfactor=$tempfactor element=$element charge=$charge"
	    printf "%-6s%5s %-4s%1s%3s %1s%4s%1s   %8s%8s%8s%6s%6s          %2s%2s\n" \
	       "$rec" "$serial" "$name" "$altloc" "$resname" "$chainid" "$resseq" \
	       "$icode" "$x" "$y" "$z" "$occupancy" "$tempfactor" "$element" "$charge"

	done > $pdb.lig
	# remove ligand and leave a mark
	# we use uniq on unsorted because we do not expet any other duplicate line
	# and we expect all ligand atoms to be consecutive !!!   XXX JR XXX
	sed -e 's/^HETATM.\{11\}LIG .*/@@@@/' $pdb | uniq > $pdb.nolig
	# insert ligand and remove mark
	sed -i.orig  "/^@@@@/r $pdb.lig" $pdb.nolig | grep -v "^@@@@" > $pdb
	# we do it this way to preserve conect records if there is any
	rm $pdb.nolig $pdb.lig
    
    fi
    
    return
}

if [[ $0 == $BASH_SOURCE ]] ; then
    pdb_fix_ligand $1 "$2" $3
else
    export _pdb_fix_ligand
fi
