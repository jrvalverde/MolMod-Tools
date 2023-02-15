#!/bin/bash

function i-tasser() {

    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "seqfile.fas [optional args to I-TASSER]" 
    else notecont $* ; fi
    
    local comment=''
  
    # IMPORTANT NOTE!!!
    # usage: i-tasser sequence.fasta [...]
    #
    # the first argument must be the fasta file containing the sequence to model
    # optionally, additional arguments can be provided with additional options to
    # I-TASSER

    #myname=`basename "${BASH_SOURCE[0]}"`	# we may not be at the I-TASSER 
    #mydir=`dirname "${BASH_SOURCE[0]}"`	# installation directory
    #myhome=`realpath $mydir`			# which is why these lines are
    #itasser_home=$myhome			# commented out
    # use this if run from a different directory
    local itasser_home=~/contrib/I-TASSER5.1

    # Define the arguments of the function and their default values
    local file=${1:-"protein.fasta"}
    # Get the absolute path of the file
    file=`abspath $file`			# asbpath is in fs_funcs.bash
    # Check if the file exists and isn't empty
    if [ ! -s "$file" ] ; then
        errexit "$file does not exist!"		# errexit is in util_funcs.bash
    fi

    # get file directory
    #	if $file is empty this will return "."
    local d=`dirname "$file"`

    local f="${file##*/}"     # Get the filename without the path
    local ext="${file##*.}"   # Get the extension
    local n="${f%.*}"         # Get the filename without the extension
    
    # Check if the sequence name was correctly obtained
    if [ "$n" = "" ] ; then
        exrrexit "$file results in an empty sequence name!"
    fi

    mkdir -p $d/i-tasser/$n     # Create the folder where the results will be stored
    cp $file $d/i-tasser/$n/    # Copy the file with the protein sequence to the folder
    cp $file $d/i-tasser/$n/seq.fasta   # Copy the file again but change its name
    
    # Print the command used to run i-tasser in the screen
    if [ "$VERBOSE" -ge 1 ] ; then
        echo "$0 $d/$f"
        echo $itasser_home/I-TASSERmod/runI-TASSER.pl \
	        -pkgdir ~/contrib/I-TASSER5.1/ \
	        -libdir /db/i-tasser \
	        -runstyle gnuparallel \
	        -LBS true \
	        -EC true \
	        -GO true \
	        -datadir $d/i-tasser/$n \
	        -outdir $d/i-tasser/$n \
	        -seqname $n \
	        -light true \
                "$@"
    fi
    
    # Run i-tasser
    $itasser_home/I-TASSERmod/runI-TASSER.pl \
	    -pkgdir ~/contrib/I-TASSER5.1/ \
	    -libdir /db/i-tasser \
	    -runstyle gnuparallel \
	    -LBS true \
	    -EC true \
	    -GO true \
	    -datadir $d/i-tasser/$n ${comment# Directory where the sequence is found } \
	    -outdir $d/i-tasser/$n  ${comment# Directory where the results will be stored} \
	    -seqname $n             ${comment# Protein sequence } \
	    -light true \
	    "$@" \
	    |& tee -a $d/i-tasser/$n/i-tasser.log

    # runstyle : serial parallel gnuparallel
    # LBS: predict ligand binding site 
    # EC: predict EC number
    # GO: predict GO terms
    # -light : run in fast mode
    # -hours : maximum hours of simulations (default=5 when -light true)
    # -outdir : default is same as -datadir

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
    [[ -v FS_FUNCS ]] || source $LIB/fs_funcs.bash
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash

    i-tasser "$@"
else
    export I_TASSER='I_TASSER'
fi


