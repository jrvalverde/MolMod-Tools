#!/bin/bash

###################################################################
## Gro2PDB_multichain.bash is a script that will take a single    #
## .gro file, and construct a pdb file with multiple chains       #
## according to the groups in the provided .ndx file.             #
## Each chain will be given a unique chain ID (up to 26 chains)   #
## Written by Paul Whitford  10/30/08                             #
###################################################################


## INGRO is your input gro file that you want to convert to a pdb
INGRO=input.gro

# NDXFILE is the index file that defines the chains
# it goes through the chains in the order that they appear
# in NDXFILE 
NDXFILE=index.ndx

## OUTPDB is the final pdb that will be written
OUTPDB=output.pdb
##GMXBIN is the location of your gromacs executables
GMXBIN=~/BIN/gromacs-4.0/bin/

## this determines how many chains you have in the .ndx file
LIMIT=`grep '\[' $NDXFILE| wc -l`


i=0
CHID=A
rm $OUTPDB
echo COMMENT This pdb was generated from gro file $INGRO > $OUTPDB
echo COMMENT and ndx file $NDXFILE >> $OUTPDB 

while test  $i -lt  $LIMIT
do
	## convert chain i to a pdb
	echo $i | $GMXBIN/trjconv -pbc nojump -f $INGRO -n $NDXFILE -o $i.pdb -s $INGRO
	## only keep the ATOMs
	grep ATOM $i.pdb > n.pdb
	## insert chainid
	sed "s/^\(.\{21\}\) /\1$CHID/g" n.pdb > $i.pdb
	rm n.pdb
	echo TER >> $i.pdb

	## add segment to main pdb
	cat $i.pdb >> $OUTPDB
	rm $i.pdb
	i=$[$i+1]
	## increment chain ID
	CHID=`echo $CHID | tr "[A-Z]" "[B-ZA]"`

done

