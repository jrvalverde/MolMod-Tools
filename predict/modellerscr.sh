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
    
    # Check if cabs was run 
    if [ -e $name/cabs ] ; then
        # Copy all the refined pdb structures obtained after running cabs
        for i in $name/cabs/*+.pdb ; do
            cp $i $a ./pdbsdirectory
            a=$(( $a + 1 ))
        done
    fi
    
    # Run the python script
    python3 $myhome/modellerscr.py -i $sequence -o sequence.ali \
    -pd -t templatesalign.pir -mf multiplealign.pir
}
