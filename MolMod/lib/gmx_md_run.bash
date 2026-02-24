#!/bin/bash
#
# NAME
#	run_md - run a Molecular Mechanics or Molecular Dynamics simulation
#
# SYNOPSIS
#	run_md simulation coordinates
#
# DESCRIPTION
#	run_md runs a Molecular Mechanics or Molecular Dynamics simulation
#	using a configuration file named 'simulation.mdp' over a coordinates
#	and topology dataset.
#
#	simulation must be the name of a Gromacs input configuration file
#	WITHOUT the .mdp extension. This name will be used as the base to
#	generate the names for subsequent files produced during the run.
#
#	coordinates must be the name of the coordinates/topology dataset
#	files, again WITHOUT extention. The actual atomic coordinates will
#	be run from a Gromacs or PDB file named 'coordinates.gro' or
#	'coordinates.pdb', and the topology will be read from a Gromacs
#	topology file named 'coordinates.top'
#
#	The coordinates provided will be used as the starting topology
#	for the run. Once the run is finished, all files generated will
#	be named after the provided run-name:
#
#		.gro	-- final coordinates in Gromcas format
#		.pdb	-- final coordinates in PDB format (generated
#			using the original coordinates as a reference 
#			to recover chain assignments)
#		.top	-- final topology
#		out.mdp	-- the actual parameters used
#		.tpr .trr .xtc	-- trajectory files (high and low resolution)
#		_noPBC.xtc	-- trajectory files (PBC removed for analysis)
#	
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#


GMX_RUN_MD="GMX_CENTER_NOPBC"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#echo $LIB
source $LIB/include.bash
include util_funcs.bash
VERBOSE=1

function gmx_run_md {
    if [ $# -ne 2 ] ; then errexit "md structure"
    else notecont $* ; fi

    # arguments:
    #	$1 MDP MD Parameters base name (without MDP extension)
    #		
    #	$2 starting structure (without extension)
    #
    # Requires
    #	a .mdp config file for the MD run
    #	a .pdb or .gro file and a .top file for the MD run
    #
    # The results will be named after the .mdp MD configuration file
    #	$md.gro
    #	$md.pdb
    #	$md.top
    #	$md.tpr
    #	Optional (may not exist in E.M. runs)
    #		.trr .xtc _noPDB.xtc
    local md=$1
    local struct=$2
    local top=''
    local gro=''
    local pdb=''
    local coords=''
    
    echo ""
    notecont "Running MD simulation $md on $struct"
    echo ""
    
    # check that the MDP file exists
    if [ ! -e $md.mdp ] ; then
    	warncont "$md.mdp does not exist!"
        return $ERROR
    fi
    if [ -e $struct.top ] ; then
        top=$struct.top
    else
        warncont "$struct.top does not exist!"
        return $ERROR
    fi
    # we prefer a .gro file if it exists
    if [ -e $struct.gro ] ; then
        coords="$struct.gro"
        pdb='no'
        gro='yes'
    elif [ -e $struct.pdb ] ; then
        coords="$struct.pdb"
        pdb='yes'
    else
        warncont "$md: No $struct.gro or $struct.pdb file found!"
        return $ERROR
    fi
    
    make_ext_index $struct
    
    if [ -s $md.pdb ] ; then
        notecont "Final output $md.pdb exists. Assuming the simulation"
        notecont "has already been run."
        return $OK
    else
	    notecont "Running $md simulation."
        # Run an MD simulation
	    # we will allow at least one warning in case charge is not exact
	    # e.g. a charge of 0.0002 will raise a warning when using Ewald
	    #
	    # It would be better to first try without maxwarn, and if that
	    # fails, inspect the output for 
	    # 
	    # "You are using Ewald electrostatics in a system with net charge"
	    #
	    # In that case then we should also check for
	    #
	    # "System has non-zero total charge: 0.000"*
	    #
	    # And then retry with -maxwarn 1
	    #
	    # But there are many other potential harmless cases that should be
	    # checked. We could deal with them as they arise. Yeah, probably
	    # we should... To Be Done.
        $grompp -f $md.mdp -c $coords -r $coords -n $struct.ndx -p $top \
		        -o $md.tpr -maxwarn 1
        if [ $? -ne 0 ] ; then return $ERROR ; fi

	    # MPI and MPInodes are in global setup
        if [ "$MPI" != 'yes' ] ; then
            if [ "$gmx" == "" ] ; then
            	# index option name changed after gromacs 4
                $mdrun -nt $nthreads -rdd $maxdd-v -deffnm $md -n $struct.ndx
            else
                $mdrun -nt $nthreads -rdd $maxdd -v -deffnm $md -mn $struct.ndx
            fi
            if [ $? -ne 0 ] ; then return $ERROR ; fi
        else
            if [ "$gmx" == "" ] ; then
            	# index option name changed after gromacs 4
                mpirun -n $MPInodes $mdrun_mpi -v -deffnm $md -n $struct.ndx
            else
                mpirun -n $MPInodes $mdrun_mpi -v -deffnm $md -mn $struct.ndx
            fi
            if [ $? -ne 0 ] ; then return $ERROR ; fi
	    fi
        mv mdout.mdp $md.out.mdp

        # MDRUN produces a GRO file, create corresponding PDB file
        notecont "Using previous $coords as reference to make $md.pdb"
	    if [ "$pdb" = "yes" ] ; then
            #index_chains $coords ${struct}_chains.ndx
            #grondx2pdb $md.gro ${struct}_chains.ndx
            #
            # use extended index (with solute, solvent and chains)
            #grondx2pdb $md.gro Complex_b4em.ndx
            groref2pdb $md.gro ${struct}.pdb
	    else
            $editconf -f $md.gro -o $md.pdb
	    fi
        # Note: this file DOES NOT match the TOP file exactly because
        #	we assign atoms not in a chain to chain Z, and this
        #	chain is unknown in the topology
        
        # Create a low-resolution XTC trajectory
        # Minimization runs do not generate trajectories
        if [ -e $md.trr -a ! -e $md.xtc ] ; then
            echo "System" | $trjconv -f $md.trr -s $md.tpr -o $md.xtc
        fi
        
	    # Correct trajectory to account for PBC
        if [ -e $md.xtc -a ! -e ${md}_noPBC.xtc ] ; then
                echo "System" | $trjconv -s $md.tpr -f $md.xtc -o ${md}_noPBC.xtc -pbc mol -ur compact
        fi

        # both, initial and final systems use the same topology parameters
        cp $struct.top $md.top
    fi
    return $OK
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

    gmx_run_md $*
else
    export GMX_RUN_MD
fi
