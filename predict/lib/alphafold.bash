#!/bin/bash


function alphafold() {
    # The first argument must be the sequence file, optional extra arguments
    # will be passed to ALphaFold
    
    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "seqfile.fas [optional args to AlphaFold]" 
    else notecont $* ; fi
    
    # Define the arguments of the function and their default values
    local file=${1:-"protein.fasta"}
    # Get the absolute path of the file
    file=`abspath $file`                 # abspath from fs_funcs.bash
    # Check if the file exists and isn't empty		
    if [ ! -s "$file" ] ; then
        errexit "$file does not exist"	# from util_funcs.bash
    fi

    # get file directory
    #	if $file is empty this will return "."
    local d=`dirname "$file"`

    local f="${file##*/}"      # Get the filename without the path 
    local ext="${file##*.}"    # Get the extension
    local n="${f%.*}"          # Get the filename without the extension
    
    local comment=''
    
    # Check if the sequence name was correctly obtained
    if [ "$n" = "" ] ; then
        errexit "$file results in an empty sequence name"
    fi

    # Define the alphafold environment
    ALPHAFOLD=~/contrib/alphafold
    ANACONDA=$HOME/contrib/miniconda3
    ALPHAFOLD_ENV=alphafold		# on POLARIS
    
    # DO IT ON POLARIS UNTIL IT WORKS IN NGS
    #
    if [ `hostname` = "ngs" ] ; then
        echo "Running on host NGS, calculating on POLARIS"
        #ssh polaris "(conda activate alphafold ; cd `pwd` ; ~/contrib/alphafold/bin/alphafold $file ; conda deactivate )"
        ssh polaris "(cd `pwd` ; ulimit -n 4096 ; ~/work/amelones/script/lib/alphafold.bash $file )"
        exit
        #ALPHAFOLD_ENV=af2			# on NGS
    fi


    # Activate the alphafold environment
    . $ANACONDA/etc/profile.d/conda.sh
    conda activate $ALPHAFOLD_ENV

    # Create the folder where the results will be stored
    mkdir -p $d/alphafold
    
    # Run alphafold
    $ALPHAFOLD/run_alphafold.sh \
	    -d ~/contrib/alphafold/data ${comment# Directory with supporting data} \
            -o $d/alphafold/            ${comment# Output directory where the results will be stored} \
            -f $file                    ${comment# File with the secuence protein} \
            -t 2022-02-09 \
            -n 40 \
            -g ${comment# [true]/false} \
            "$@" \
            |& tee $d/alphafold/$n.log

    conda deactivate
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

    alphafold "$@"
else
    export ALPHAFOLD='ALPHAFOLD'	# make same so that [[ -v $ALPHAFOLD ]] also works
fi
