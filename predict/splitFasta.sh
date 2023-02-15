#!/bin/bash
#
maxlen=1000	# currently determined by I-TASSER (actually 1500)
overlap=$((maxlen / 4 ))

sequence=${1:-sequence.fasta}
destdir=${2:-".."}

# convert to absolute pathname and get sequence file name
sequence=`realpath $sequence`
namedir=${sequence%.*}
name=${namedir##*/}

#  we need to use pyfasta (install with pip pyfasta or download and use
#  python setup.py installss

# get length of the sequence file
seqlen=`pyfasta info $sequence | tail -1 | cut -d' ' -f1`
nchunks=$(( $(( $seqlen / $maxlen )) + 1))

if [ "$seqlen" -gt "$maxlen" ] ; then
    echo "LARGE SEQUENCE ($seqlen)"
    echo "splitting in $nchunks fragments"
    pyfasta split -n $nchunks -k $maxlen -o $overlap $sequence
    rm $sequence.gdx
    rm $sequence.flat
    mv $namedir.[0-$nchunks].${maxlen}mer.${overlap}overlap.fasta $destdir
else
    cp $sequence $destdir
fi
