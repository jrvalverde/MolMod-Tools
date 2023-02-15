#!/bin/bash

function fix_3D_templates() {
    # XXX JR XXX THIS IS AN UGLY HACK PENDING CORRECT REWRITING
    # THIS IS BECAUSE IN SOME CASES, PepBuilder results in negative coordinates
    # larger than -1000.000. This shifts all the coordinates one space right
    # and breaks the PDB format, leading to a failure of CABS.
    # Chimera can read the pdb file and "fix" the coordinates so we just
    # read the file and save it again. This does not actually FIX the file,
    # but distorts the X and Y coordinates so they fit in the box.
    # Thus, it results in a distorted starting structure, but we do not
    # care because any way, we will model it extensively with CABS.
    for i in *.pdb ; do
        cp $i $i.orig
        DISPLAY='' chimera --nogui <<END
            open $i
            write format pdb 0 $i
END
    done
}



function pepbuild() {

    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "seqfile.fas" 
    else notecont $* ; fi

    # this ensures that $sequence has a value (if none was given, then
    # it will be "sequence.fasta" by default
    local sequence=${1:-sequence.fasta}
    sequence=`abspath $sequence`    # get the absolute path of the sequence file
    
    local filename=${sequence##*/}	# remove everything until the last /
    local name=${filename%.*}	# remove the last . and whatever follows from file name
    
    # Define the paths where the pepbuild and anglor commands are stored
    MYHOME=~/work/amelones/script/lib
    PEPBUILD_COMMAND=${MYHOME}/PepBuild.py
    ANGLOR_COMMAND=${HOME}/contrib/anglor/ANGLOR/anglor.pl

    # Check if the sequence file exists and isn't empty
    if [ ! -s "$sequence" ] ; then
        errexit "ERROR: sequence $sequence does not exist"
        # without a sequence we cannot make any templates
    fi

    # generate output directory in accordance with other model-building methods
    outdir=pepbuild
    mkdir -p $outdir/$name
    cp $sequence $outdir

    # Generate various starting configurations
    # ----------------------------------------
    #
    # NOTE: we do not know which one may work better, it will depend on the actual
    # structure of the target and its predominant features.
    #
    # We could have a starting model as a parameter, but this way we ensure that
    # we always generate a minimum set of trial models.
    #
    # PepBuild.py is an auxiliary script in Python that generates structures
    # using package PeptideBuilder
    #

    cd $outdir/
    ls
    if [ ! -s $name/helix.pdb ] ; then
        python3 $PEPBUILD_COMMAND -i $sequence \
	    -o $name/helix.pdb -a
    fi

    if [ ! -e $name/sheet.pdb ] ; then
        python3 $PEPBUILD_COMMAND -i $sequence \
	    -o $name/sheet.pdb -b
    fi

    if [ ! -e $name/coil.pdb ] ; then
        python3 $PEPBUILD_COMMAND -i $sequence \
	    -o $name/coil.pdb -c
    fi

    if [ ! -e $name/extended.pdb ] ; then
        python3 $PEPBUILD_COMMAND -i $sequence \
	    -o $name/extended.pdb -e
    fi

    # for the next ones we need a secondary structure prediction and a
    # phi-psi angle prediction. We'll get both using our slightly modified
    # ANGLOR which first runs psipred (to get secondary structure predictions
    # and put them in fasta format) and then ANN and SVM to get phi-psi
    # angle predictions
    if [ ! -d anglor ] ; then
        $ANGLOR_COMMAND `basename $sequence`
    fi

    if [ ! -e $name/ss.pdb ] ; then
        # check if anglor generated a secondary structure fasta file
        if [ -e anglor/seq.ss ] ; then
            python3 $PEPBUILD_COMMAND -i $sequence \
	        -o $name/ss.pdb -s anglor/seq.ss
        fi
    fi

    if [ ! -e $name/pp.pdb ] ; then
        if [ -e anglor/seq.ann.phi -a -e anglor/seq.svr.psi ] ; then
            python3 $PEPBUILD_COMMAND -i $sequence \
	        -o $name/pp.pdb -P anglor/seq.ann.phi -S anglor/seq.svr.psi
        fi
    fi

    # Additionally, we might try to use other auxiliary programs to get
    # better starting structures.
    # Or, alternatively, copy them into the current directory before
    # calling this script. Then this script will find them and process
    # them as well.

    # fix a bug in PepBuild that can generate too large negative coordinates
    # XXX JR XXX THIS IS AN UGLY HACK PENDING CORRECT REWRITING
    # THIS IS BECAUSE IN SOME CASES, PepBuilder results in negative coordinates
    # larger than -1000.000. This shifts all the coordinates one space right
    # and breaks the PDB format, leading to a failure of CABS.
    # Chimera can read the pdb file and "fix" the coordinates so we just
    # read the file and save it again. This does not actually FIX the file,
    # but distorts the X and Y coordinates so they fit in the box.
    # Thus, it results in a distorted starting structure, but we do not
    # care because any way, we will model it extensively with CABS.
    for i in $name/*.pdb ; do
        notecont "fixing $i"
        fix_3D_templates $i 
    done

    cd -
}

#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    # this may be either a command or a library function
    if [ -d "$LIB/lib" ] ; then
        LIB="$LIB/lib"
    fi
    # if var is a variable then do && else ||
    [[ -v FS_FUNCS ]] || source $LIB/fs_funcs.bash
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash

    pepbuild "$@"
else
    export PEPBUILD='PEPBUILD'	# make same so [[ -v $PEPBUILD ]] also works
fi
