#!/bin/bash

banner ambermin

BASE=`dirname "$(readlink -f "$0")"`

for mod in aff ; do
    if [ ! -d $mod ] ; then continue ; fi
    echo "Launching $mod"
    mkdir -p $mod/ambermin
    cd $mod/ambermin
    (
        for model in ../models/*.pdb ; do
            # ignore already minimized models
            if [[ "$model" == *"amber.pdb" ]] ; then continue ; fi
            if [[ "$model" == *"vacuo"*"pdb" ]] ; then continue ; fi
            if [[ "$model" == *"opls"*".pdb" ]] ; then continue ; fi
            if [[ "$model" == *"solvent"*"pdb" ]] ; then continue ; fi
	    f=`basename $model .pdb`
            target=amber_${f}-H_310K/${f}_amber.pdb
	    #echo $target
            #ls -l $target
            if [ ! -s "$target" ] ; then
                $BASE/amber_dp_optimize.sh $model #&
            fi
        done
    ) 
    cd -
done
