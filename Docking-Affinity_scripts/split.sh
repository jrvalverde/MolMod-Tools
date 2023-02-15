#!/bin/bash

banner split

R=$1
#	NOTE: in this case, L ($2) should be the chain ID we want to assign
#	to the substrate
L=$2

BASE=`dirname "$(readlink -f "$0")"`

for i in aff ; do 
    cd $i/models 
    mkdir -p ../chains 
    for j in *.pdb ; do
    	echo Cleaning $j 
        # remove MODEL marks and CONECT records 
        cat $j \
        | sed -e '/^MODEL .*/d' \
              -e '/^ENDMDL/d' \
              -e '/^CONECT /d' \
              -e "/^HETATM/ s/^\(.\{21\}\) /\1$L/g" \
        > k ; cp k $j
        base=`basename $j .pdb`
	echo Splitting $j
        if [ ! -s ../chains/${base}_${R}.pdb ] ; then
	    # split in chains
            ~/work/lenjuanes/script/split_pdb_in_chains.sh $j 
            # Now check if R contains more than one chain letter
            # and if so, build a combined file as well
            if [ ${#R} -gt 1 ] ; then
                echo "Building combined receptor ${base}_${R}.(pdb|mol2)"
                cmd="babel -ipdb  --partialcharge mmff94 "
                cmd2="babel -imol2 --partialcharge mmff94 "
                for (( i=0 ; i < ${#R} ; i++ )); do 
                    chains[i]=${R:i:1}
                    cmd="$cmd ${base}_${R:i:1}.pdb"
                    cmd2="$cmd2 ${base}_${R:i:1}.mol2"
                done
                cmd="$cmd -opdb ../chains/${base}_${R}.pdb -j"
                cmd2="$cmd2 -omol2 ../chains/${base}_${R}.mol2 -j"
                #cho $cmd
                #cho $cmd2
                eval $cmd
                eval $cmd2
            fi
	    # split_pdb_in_chains makes the chains in the current dir,
            # move them to ../chains
    	    mv ${base}_[A-Z].pdb ../chains 
    	    mv ${base}_[A-Z].mol2 ../chains 
        fi
        
    done 
    rm k
    cd - 
    # Now dive into $i/chains and build any combined chains for scoring
    if [ ${#R} -gt 1 ] ; then
        # if R contains more than one chain letter
        cd $i/chains
        cmd='babel '
        for (( i=0 ; i < ${#R} ; i++ )); do 
            chains[i]=${R:i:1}
            cmd=$cmd"-i"
        done
        cd -
    fi
done
