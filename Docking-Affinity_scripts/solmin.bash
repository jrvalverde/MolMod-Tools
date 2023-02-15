#!/bin/bash

banner solmin

BASE=`dirname "$(readlink -f "$0")"`
OPLSAA_HOME=~/work/bin


for dir in aff ; do
    if [ ! -d $dir ] ; then continue ; fi
    echo "Minimizing models in $dir/models"
    mkdir -p $dir/solmin
    cd $dir/solmin

    # only process models previously amber-minimized 'in vacuo'
    for model in ../models/*.pdb ; do
        # only process non-minimized files
        if [[ $model == *"amber"* ]]; then continue ; fi
        if [[ $model == *"opls"* ]]; then continue ; fi
        if [[ $model == *"vacuo"* ]]; then continue ; fi
        if [[ $model == *"solvent"* ]]; then continue ; fi
        base=`basename $model .pdb`
        echo "Processing $base"
	if [ ! -s opls-aa_${base}_150mM/${base}_solvent.pdb ] ; then
	    echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb"
            if [ ! -s opls-aa_${base}_150mM/em.gro ] ; then
                echo "Computing opls-aa_${base}_150mM/em.gro"
	        # OPLS-AA works well with UCSF Chimera output files, but
	        # apparently not with Amber output PDB files. The reason
	        # is that chain information has been lost.
                cp $model $base.pdb
                ${OPLSAA_HOME}/opls-aa.bash -i $base.pdb -S -O
                rm $base.pdb
	    fi
	    # we are here because we do not have 
	    #	opls-aa_${base}_150mM/${base}_solvent.pdb
	    # we prefer em.gro + em.tpr to preserve chain information
	    # but note that chain IDs may have changed from the original!!!
            if [ -s opls-aa_${base}_150mM/em.gro ] ; then
                echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb from em.gro"
                echo "Protein" | \
		gmx trjconv -f opls-aa_${base}_150mM/em.gro \
		            -s opls-aa_${base}_150mM/em.tpr \
		            -o opls-aa_${base}_150mM/${base}_solvent.pdb
            elif [ -s opls-aa_${base}_150mM/em.pdb ] ; then
                echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb from em.pdb"
	        cp opls-aa_${base}_150mM/em.pdb opls-aa_${base}_150mM/${base}_solvent.pdb
	    else
                echo "No minimized structure file found."
                echo "Something went wrong with $base optimization in solution"
            fi
        fi

	if [ -s opls-aa_${base}_150mM/em.log ] ; then
	    echo "Extracting energy"
            # save last energy (and gradient) for quick inspection
            lastE=`grep "^Potential Energy " opls-aa_${base}_150mM/em.log | tail -1` 
            echo "$lastE" > "opls-aa_${base}_150mM/E="`echo "$lastE" | cut -d'=' -f2 | tr -d ' '`
        else
            echo "No em.log file found."
            echo "Something went wrong with $base optimization in solution"
	fi

        echo "$base done"


    done

    cd -
done

