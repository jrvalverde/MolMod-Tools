#!/bin/bash

R=$1	# ignored
L=$2	# ignored

banner solmin

BASE=`dirname "$(readlink -f "$0")"`
OPLSAA_HOME=~/work/bin

NUM_PROCS=8

# EXPLANATION:
# wait can take as argument the pid of the process to wait for
# we can get the pid of the latest spawned process
# if we store the PIDs as we spawn processes in an array, we can
# then wait for all of them
#
#for i in $n_procs; do
#    ./procs[${i}] &
#    pids[${i}]=$!	# or pids="$pids $!"
#done
#
## wait for all pids
#for pid in ${pids[*]}; do
#    wait $pid
#done
#
# As an alternative, we may spawn all of them, and then use jobs -p to get
# the PIDs of each process group leader
# for i in $njobs , do
#    newjob &
# done
# for pid in `jobs -p` ; do
#    wait $pid || let "FAIL+=1"
# done
# if [ $FAIL != 0 ] ; then
#     echo "There were $FAIL failed jobs"
# fi
#
# another possibility is
# wait < <(jobs -p)
#
# FINALLY this last example will run N jobs and wait for one of them to
# complete before running the next
#
#!/usr/bin/env bash
#set -m     # See below
#
## number of processes to run in parallel
#num_procs=5
#
## function that processes one item
#my_job() {
#    printf 'Processing %s\n' "$1"
#    sleep "$(( RANDOM % 5 + 1 ))" 
#}
#
#i=0
#while IFS= read -r line; do
#    if (( i++ >= num_procs )); then
#        wait -n   # wait for any job to complete. New in 4.3
#    fi
#    my_job "$line" &
#done < inputlist
#
#wait     # wait for the remaining processes
#
#set -x

# This will process every model in '$1/models'
# 	First ir creates a subdir called vacmin inside
#	Moves into it
#	spawns a background subprocess that will optimize all models
#	in the sister folder "models"
#for dir in aff ; do
function solmin() {
    dir=$1
    R=$2
    L=$3

    if [ ! -d $dir ] ; then return ; fi
    echo "Minimizing models in $dir/models"

    # prepare models by superposing and centering them
    mkdir -p $dir/cmodels	# centered models
    mkdir -p $dir/csmodels	# centered and superposed
    mkdir -p $dir/stats
    
    pending=0
    # check first if we need to compute any solution minimization
    for model in $dir/models/*.pdb ; do
        # only process unprocessed files
        if [[ $model == *"amber"* ]]; then continue ; fi
        if [[ $model == *"opls"* ]]; then continue ; fi
        if [[ $model == *"vacuo"* ]]; then continue ; fi
        if [[ $model == *"solvent"* ]]; then continue ; fi

        echo -n $model
        base=`basename $model .pdb`
        if [ -s $dir/models/${base}_solvent.pdb ] ; then 
            echo " done"
            #echo $pending
            continue 
        else
            echo " not done"
            pending=$((pending + 1))
            #echo $pending
        fi
    done
    #echo "models pending solvent minimization=$pending"
    if [ $pending -eq 0 ] ; then 
        echo "solmin: all models in $dir/models have already been minimized"
        return
    else
        echo "solmin: We need to minimize $count models"
    fi

    
    # As long as there is any pendig we need to center and superpose
    # it with all others to get the maximal dimensions
    echo "Centering and superposing models to get maximal dimensions"
    csmdims=$dir/stats/csmdims
    truncate -s 0 $csmdims
    no=0
    for model in $dir/models/*.pdb ; do
        # only process unprocessed files
        if [[ $model == *"amber"* ]]; then continue ; fi
        if [[ $model == *"opls"* ]]; then continue ; fi
        if [[ $model == *"vacuo"* ]]; then continue ; fi
        if [[ $model == *"solvent"* ]]; then continue ; fi

        no=$((no + 1))
        
        # To minimize in solution we need to define a PBC box;
        # for this, we will center the model, superpose each to
        # a reference (the first model), and compute th
        # dimensions.
        # We will then find the maximal dimensions and calculate
        # a box size large enough to accommodate any of the models
        # and use this size for all models.
        # This will ensure all models are minimized with the same
        # box (and system) size, and that the energies calculated
        # are more or less comparable.
	
	# center and superpose models
	cmodel=$dir/cmodels/`basename $model`
	csmodel=$dir/csmodels/`basename $model`

	# choose first model as reference for superoposition
	if [ $no -eq 1 ] ; then
		ref=$cmodel
	fi

	if [ ! -s $csmodel ] ; then
	    # center models
	    if [ ! -s $cmodel ] ; then
	        echo "centering $model"
		babel -c $model $cmodel
	    fi

	    # superpose models
	    if [ $no -eq 1 ] ; then
		cp $ref $csmodel
	    else
	        echo "aligning $cmodel to $ref"
		unset DISPLAY
		chimera --nogui $ref $cmodel << END
		mmaker #0 #1
		write relative #0 format pdb #1 $csmodel
END
	    fi
	fi
	if [ ! -s $csmodel ] ; then
	    echo "ERROR: could not make $csmodel"
	    exit
	fi
	# now get molecule size
	echo -n `basename $csmodel .pdb`'	' >> $csmdims
	$BASE/get_pdb_dimensions.sh $csmodel size >> $csmdims
	
    done
    # find maximal dimensions
    xmax=`cut -f2 $csmdims | sort -g | tail -1`
    ymax=`cut -f3 $csmdims | sort -g | tail -1`
    zmax=`cut -f4 $csmdims | sort -g | tail -1`
    echo "Maximum sizes: $xmax $ymax $zmax"
    # compute box size (+12 Å on each side and convert to nm)
    # this is wasteful, but...
    xbox=`echo "scale=3; ($xmax + 24)/10" | bc -l`
    ybox=`echo "scale=3; ($ymax + 24)/10" | bc -l`
    zbox=`echo "scale=3; ($zmax + 24)/10" | bc -l`
    echo "We will use a common box of size $xbox $ybox $zbox"

    # Now move to solmin and minimize
    mkdir -p $dir/solmin
    cd $dir/solmin

    i=0
    for model in ../csmodels/*.pdb ; do
        base=`basename $model .pdb`
        # only process non-minimized files
        # there should be no minimized files in ../csmodels 
        # but just in case...
        if [[ "$model" == *"amber"*".pdb" ]] ; then continue ; fi
        if [[ "$model" == *"opls"*".pdb" ]] ; then continue ; fi
        if [[ "$model" == *"vacuo"*".pdb" ]] ; then continue ; fi
        if [[ "$model" == *"solvent"*".pdb" ]] ; then continue ; fi
        
        # avoid recomputing already calculated models
        if [ -s ../models/${base}_solvent.pdb ] ; then 
            continue 
        elif [ -s opls-aa_${base}_150mM/${base}_solvent.pdb ] ; then
            cp opls-aa_${base}_150mM/${base}_solvent.pdb ../models/
            continue
        fi
        
        # loop until we have num_procs processes spawned
        if (( i++ >= NUM_PROCS )); then
            # afterwardws, wait for one to finish before proceeding
            # with the next
            wait -n   # wait for one job to complete. Bash 4.3
            # we could decrease i here
        fi
        # we'll do everything in a subshell to be able to work in parallel
        (
        echo "Processing $base"
	if [ ! -s opls-aa_${base}_150mM/${base}_solvent.pdb ] ; then
	    echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb"
            if [ ! -s opls-aa_${base}_150mM/em.gro ] ; then
                echo "Computing opls-aa_${base}_150mM/em.gro"
	        # OPLS-AA works well with UCSF Chimera output files, but
	        # apparently not with Amber output PDB files. The reason
	        # is that chain information has been lost.
                cp $model $base.pdb
                base=`basename $model .pdb`
                ${OPLSAA_HOME}/opls-aa-box.bash -i $base.pdb -S -O \
			-b ${xbox},${ybox},${zbox}
#			--box $xbox $ybox $zbox
                rm $base.pdb
	    fi
	    
	    # we are here because we do NOT have 
	    #	opls-aa_${base}_150mM/${base}_solvent.pdb
	    # we prefer em.gro + em.tpr to preserve chain information
	    # but note that chain IDs may have changed from the original!!!
            if [ -s opls-aa_${base}_150mM/em.gro ] ; then
                echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb from em.gro"
                echo "WARNING: chain IDs may have changed!"
		echo "System" | \
		gmx trjconv -f opls-aa_${base}_150mM/em.gro \
		            -s opls-aa_${base}_150mM/em.tpr \
		            -o opls-aa_${base}_150mM/${base}_solvent-nj.pdb \
			    -pbc nojump
                echo "System" | \
		gmx trjconv -f opls-aa_${base}_150mM/em.gro \
		            -s opls-aa_${base}_150mM/em.tpr \
		            -o opls-aa_${base}_150mM/${base}_solvent.pdb \
			    -pbc mol
            elif [ -s opls-aa_${base}_150mM/em.pdb ] ; then
                echo "Making opls-aa_${base}_150mM/${base}_solvent.pdb from em.pdb"
                echo "WARNING: chain IDs may have changed!"
	        cp opls-aa_${base}_150mM/em.pdb opls-aa_${base}_150mM/${base}_solvent.pdb
	    else
                echo "No minimized structure file found."
                echo "Something went wrong with $base optimization in solution"
            fi
        fi
        
	if [ -s opls-aa_${base}_150mM/em.log ] ; then
            echo "Extracting energy of ${base}"
            # save last energy (and gradient) for quick inspection
            lastE=`grep "^Potential Energy " opls-aa_${base}_150mM/em.log | tail -1` 
            echo "$lastE" > "opls-aa_${base}_150mM/E="`echo "$lastE" | cut -d'=' -f2 | tr -d ' '`
        else
            echo "No em.log file found."
            echo "Something went wrong with $base optimization in solution"
        fi
        #echo "$base done"
	) &
        
    done
    wait
    cd -
}

solmin aff $R $L

