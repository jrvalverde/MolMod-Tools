#!/bin/bash
#

function split_fasta_seq_to_dir() {

    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "seqfile.fas [output-dir] [max-len]" 
    else notecont $* ; fi
    # split a fasta file in pieces and store them in the specified 
    # output folder
    # usage:
    #    split_fasta_seq_to_dir [seq.fasta] [out-dir] [max-len]
    # all arguments are optional, if they are not provided, we will
    # use by default "sequence.fasta" "splitted" and "1000"
    
    notecont $*
    
    # Define the arguments of the function and their default values
    sequence=${1:-sequence.fasta}
    destdir=${2:-"splitted"}
    maxlen=${3:-1000}       # By default it will be 1000 (i-tasser limit=1500)

    # use an overlap of 1/4 (NOTE: this may be too short for short lengths)
    overlap=$((maxlen / 4 ))
    uniquelen=$((maxlen - overlap))

    # Create the directory where the resulting fragments will be stored
    if [ ! -d "$destdir" ] ; then mkdir -p $destdir ; fi

    # convert to absolute pathname and get sequence file name
    sequence=`realpath $sequence`
    #namedir=${sequence%.*}
    #name=${namedir##*/}

    #  we need to use pyfasta (install with pip pyfasta or download and use
    #  python setup.py install

    # get length of the sequence file
    seqlen=`pyfasta info $sequence | tail -1 | cut -d' ' -f1`
    # get the number of chunks depending on the sequence length
    nchunks=$(( $(( $seqlen / $uniquelen )) + 1))

    # Check if the legnth sequence is bigger than the limit and split the protein
    if [ "$seqlen" -gt "$maxlen" ] ; then
        notecont "LARGE SEQUENCE ($seqlen)"
        notecont "splitting in $nchunks fragments"
        pyfasta split -n $nchunks -k $maxlen -o $overlap $sequence
        rm $sequence.gdx
        rm $sequence.flat
        # Move the fragments to the destination directory
        for i in *overlap.fasta; do
    	    mv $i $destdir
        done
        #mv *overlap.fasta $destdir
        #mv $namedir.[0-$nchunks].${maxlen}mer.${overlap}overlap.fasta $destdir
    else
        cp $sequence $destdir   # Copy the protein sequence in the destination directory
    fi

    return $nchunks
}

#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash

    split_fasta_seq_to_dir $*
else
    export SPLIT_FASTA=''
fi
