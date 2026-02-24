#!/bin/bash

if [ $# -lt 2 ] ; then
    echo "$0 REC-CHAINS LIG-CHAINS"
    exit
fi

banner rmsd

R=$1
L=$2

ref=refrec.pdb		# reference is the receptor molecule
NUM_PROCS=8

if [ ! -s $ref ] ; then
    echo "$ref does not exist or is empty"
    exit
fi

# make this into a function at some point
for wd in aff ; do
    
    mkdir -p $wd/stats
    mkdir -p $wd/rmsd

    nproc=0
    for i in $wd/models/*.pdb ; do
        #echo "Computing RMSD for $i"
        chk=$i
        match=$wd/rmsd/`basename $i .pdb`-${R}_${L}.rmsd
        matchni=$wd/rmsd/`basename $i .pdb`-${R}_${L}.ni.rmsd

        if (( nproc++ >= NUM_PROCS )); then
	    # if there are already too many jobs running, wait for one to 
	    # finish before procceeding
            wait -n   # wait for one job to complete. Bash 4.3
            # decrease nproc 
	    (( nproc-- ))
        fi

	(
	  # compute RMSD
	  if [ ! -e $match ] ; then
            echo "RMSD: matching $match"
            ls -l $ref $chk
            unset DISPLAY 
            chimera --nogui $ref $chk > $match << END
                mmaker #0 #1
END
	  fi
        
	  # compute unrefined (non-iterated) RMSD
          if [ ! -e $matchni ] ; then
            echo "RMSD: matching $match (not-iterated)"
            unset DISPLAY
            chimera --nogui  $ref $chk > $matchni << END
            mmaker #0 #1 iterate false
END
	  fi
        ) &
    done
    wait	# wait for the last NUM_PROCS jobs to finish

    echo "Building RMSD tables"
    out=$wd/stats/RMSD-${R}_${L}.tab
    outni=$wd/stats/RMSD-${R}_${L}.ni.tab
    rm -f $out ; touch $out
    rm -f $outni ; touch $outni

    # This must be serialized after RMSD has been calculated
    for i in $wd/models/*.pdb ; do
        match=$wd/rmsd/`basename $i .pdb`-${R}_${L}.rmsd
        matchni=$wd/rmsd/`basename $i .pdb`-${R}_${L}.ni.rmsd

        #echo -n "$match	"
        #grep "RMSD between" $match | sed -e 's/.* is //g' -e 's/ .*//g' 
        echo -n `basename $i .pdb`"	" >> $out
        grep "RMSD between" $match | sed -e 's/.* is //g' -e 's/ .*//g' >> $out
        # if there is no RMSD then we lack a new line
        echo "" >> $out		# if uneeded, we'll remove it afterwards
        
        echo -n `basename $i .pdb`"	" >> $outni
        #echo -n "$i	" >> $outni
        grep "RMSD between" $matchni | sed -e 's/.* is //g' -e 's/ .*//g' >> $outni
        # if there is no RMSD then we lack a new line
        echo "" >> $outni		# if in excess we'll remove it afterwards
    done
    
    # squeeze empty new lines
    sort $out | cat -s > kkk.666 && mv kkk.666 $out
    sort $outni | cat -s > kkk.666 && mv kkk.666 $outni

done
