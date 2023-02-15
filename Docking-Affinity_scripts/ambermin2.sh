#!/bin/bash

banner vacmin

BASE=`dirname "$(readlink -f "$0")"`

NUM_PROCS=8

for mod in aff ; do
    if [ ! -d $mod ] ; then continue ; fi
    echo "Launching $mod"
    mkdir -p $mod/vacmin
    cd $mod/vacmin
    (
        nproc=0
        for model in ../models/*.pdb ; do
            # ignore already minimized models
            if [[ "$model" == *"amber"*".pdb" ]] ; then continue ; fi
            if [[ "$model" == *"vacuo"*".pdb" ]] ; then continue ; fi
            if [[ "$model" == *"opls"*".pdb" ]] ; then continue ; fi
            if [[ "$model" == *"solvent"*".pdb" ]] ; then continue ; fi
            if (( nproc++ >= NUM_PROCS )); then
        	# afterwardws, wait for one to finish before proceeding
        	# with the next
        	wait -n   # wait for one job to complete. Bash 4.3
        	# we could decrease nproc here
		(( nproc-- ))
            fi
	    (
		f=`basename $model .pdb`
        	target=amber_${f}-H_310K/${f}_amber_vacuo.pdb
		#echo $target
        	#ls -l $target
        	if [ ! -s "$target" ] ; then
                    $BASE/amber_dp_optimize2.sh $model #&
        	fi
	    ) &
        done
    ) 
    cd -
done
