#!/bin/bash
#

function modellerscr(){
    # Call the python script that harbours the needed functions for the fusion
    # of protein fragments whose structure was previously predicted and obtain 
    # an approximate model of the overall protein by using the MODELLER software
    # usage: 
    #       modellerscr [seq.fasta]
    # The argument is optional, if it is not provided "sequence.fasta" will be
    # used by default
    sequence=${1:-sequence.fasta}
    
    a=0 
    if [ -e $out/cabs ] ; then
        for i in $out/cabs/*++.pdb ; do
            cp $i model$a ./pdbsdirectory
            a=$(( $a + 1 ))
        done
    fi

    python3 $myhome/modellerscr.py -i $sequence -o sequence.ali \
    -pd `pwd` -t templatesalign.pir -mf multiplealign.pir
}
