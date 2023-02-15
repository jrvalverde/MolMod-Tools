#!/bin/bash

R=$1	# ignored
L=$2	# ignored

banner vacmin

BASE=`dirname "$(readlink -f "$0")"`

NUM_PROCS=8
njobs=0

for mod in aff ; do
    if [ ! -d $mod ] ; then continue ; fi
    echo "Minimizing ${mod}/models"
    mkdir -p $mod/vacmin
    cd $mod/vacmin
    (
        for model in ../models/*.pdb ; do
	    name=`basename $model .pdb`
            # ignore already minimized models
            if [[ $model == *"amber"* ]]; then continue ; fi
            if [[ $model == *"opls"* ]]; then continue ; fi
            if [[ "$model" == *"vacuo"*".pdb" ]] ; then continue ; fi
            if [[ "$model" == *"solvent"*".pdb" ]] ; then continue ; fi
            # this is an un-minimized model, check if the corresponding
            # model exists in ../models, and if it doesn't check if we
            # already have a minimized model available that we can copy
            # to avoid recomputing it.
            if [ -s ../models/${name}_vacuo.pdb ] ; then
                continue
            elif [ -s amber_${name}-H_310K/${name}_vacuo.pdb ] ; then
                cp amber_${name}-H_310K/${name}_vacuo.pdb ../models/
                continue
            fi
            # at this point we are with an un-minimized model that
            # lacks a vacuum-minimized corresponding version in ../models/
            # Compute a minimization in vacuum using AMBER.
            # The calculation is parallelized: we check if there are
            # already too many jobs, and if so, wait for one to finish,
            # otherwise, we launch a new background job
            if (( njobs++ >= NUM_PROCS )); then
        	# afterwardws, wait for one to finish before proceeding
        	# with the next
        	wait -n   # wait for one job to complete. Bash 4.3
        	# we could decrease njobs here
            fi
	    (
                # this check is unneeded because amber_dp_optimize3 already
                # does it before anything else
        	target=amber_${name}-H_310K/${name}_vacuo.pdb
		#echo $target
        	#ls -l $target
        	if [ ! -s "$target" ] ; then
                    $BASE/amber_dp_optimize3.sh $model $R $L #&
        	fi
	    ) &     
        done
	wait
    ) 
    cd -
done
