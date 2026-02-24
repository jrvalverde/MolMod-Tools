#!/bin/bash

GMX_TRJ_ASSEMBLE="GMX_TRJ_ASSEMBLE"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash

function gmx_trj_assemble() {
    md=${1:-md}

    if [ ! -s ${md}.trr -a ! -e ${md}.xtc ] ; then
	echo "MD trajectory $md.trr does not exist! Trying to build it..."
	echo "	We will use \${md}_\$no.trr for \$no=1 to n"

	# concat all sub-trajectories together
	#    if [ ! -e ${md}.trr ] ; then
	#	gmx trjcat -f ${md}_?.trr ${md}_10.trr -o ${md}.trr -cat 
	#    fi
	#    if [ ! -s ${md}.trr ] ; then
	#        echo "MD trajectory $md.trr does not exist!"
	#	exit
	#    fi

	# use -conect to preserve bonds in coarse grained trajectories or when
	# including non-protein molecules when converting to PDB

	cmdtrr="yes c | gmx trjcat -cat -settime -o ${md}.trr -f"
	cmdxtc="yes c | gmx trjcat -cat -settime -o ${md}.xtc -f"
	cmdedr="yes c | gmx eneconv -settime -o ${md}.edr -f"
	i=1
	while [ -e ${md}_$i.trr ] ; do    
            # prepare command to make trajectory
            cmdtrr="${cmdtrr} ${md}_${i}.trr"

	    # prepare command to make compressed trajectory
	    if [ ! -s  ${md}_${i}.xtc ] ; then
		echo System | gmx trjconv -o ${md}_${i}.xtc \
	            -f ${md}_${i}.trr -s ${md}_${i}.tpr
	    fi
            cmdxtc="${cmdxtc} ${md}_${i}.xtc"

            # prepare command to make energy file
	    if [ -s ${md}_$i.edr ] ; then
		cmdedr="${cmdedr} ${md}_${i}.edr"
            else
        	echo "WARNING: ${md}_${i}.edr DOES NOTE EXIST!"
        	echo "	Your ENERGY plots will be unreliable"
            fi

	    # preserve the original topology
	    if [ ! -s ${md}.tpr ] ; then
        	# use the last topology available
		#cp ${md}_${i}.tpr ${md}.tpr
		# only use the first topology (next iterations will find that a
		# topology does already exist
        	cp ${md}_$i.tpr ${md}.tpr

	    fi

            # ensure last output structure is preserved
	    cp ${md}_$i.gro ${md}.gro


            i=$((i + 1))
	done
	if [ $i -ne 1 ] ; then
	    eval $cmdtrr
	    eval $cmdxtc
	    eval $cmdedr
	else
            echo "	No partial sub-trajectories ${md}_* found!"
            echo "	EXITING"
            exit
	fi

	# get a trajectory with correct time steps
    #    yes c | gmx trjcat -f `ls -r ${md}_*trr | tr '\n' ' '` -settime -o ${md}.ok.trr

    fi

}

if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    # [[ -v VAR ]] tests if a variable is set
    # [[ -z "$VAR" ]] tests if length of $VAR is zero
    LIB=`dirname $0`
    source $LIB/include.bash
    include util_funcs.bash
    include gmx_setup_cmds.bash

    gmx_trj_assemble $*
else
    export GMX_TRJ_ASSEMBLE
fi
