#!/bin/bash

banner chimin

# This will process every three letter (AAcode+digit+digit) directory
# 	First ir creates a subdir called chimin inside
#	Moves into it
#	spawns a background subprocess that will optimize all models
#	in the sister folder "models"
for aa in aff ; do
    if [ ! -d $aa ] ; then continue ; fi
    echo "Launching $aa"
    mkdir -p $aa/chimin
    cd $aa/chimin
    (
        for model in ../models/*.pdb ; do
            # ignore already minimized models
            if [[ "$model" == *"_amber.pdb" ]] ; then continue ; fi
            if [[ "$model" == *"_amber"*".pdb" ]] ; then continue ; fi
            target=chim_`basename $model .pdb`_amber/`basename $model .pdb`_amber.pdb
	    #echo $target
            #ls -l $target
            if [ ! -s "$target" ] ; then
                ~/work/script/chimera_dp_optimize.sh $model #&
            fi
        done
    ) 
    cd -
done

