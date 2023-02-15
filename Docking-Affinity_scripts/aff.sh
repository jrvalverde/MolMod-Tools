#!/bin/bash

banner "AFF $1 $2"

R=$1
L=$2

#BASE=`(cd ../script ; pwd)`
BASE=`dirname "$(readlink -f "$0")"`

cd .	# ensure pwd is our last and but-last dir

# Minimize 'in vacuo'
# Run manually so that all jobs run in parallel, wait for them to complete
# and then continue. There should be a trick to do this in the backup from
# villon (in the grid scheduler).
# NO LONGER NEEDED, WE NOW USE GROMACS WHICH IS A LOT FASTER
if [ ! -d aff/chimin ] ; then
    echo '' ; #$BASE/chimin.bash $R $L
    #exit
fi
if [ ! -d aff/ambermin ] ; then
    $BASE/ambermin.sh $R $L
    #exit
fi
# update list of models
for i in aff/ambermin/*/*_amber*.pdb ; do
    if [ ! -s aff/models/`basename $i` ] ; then
	cp $i aff/models/
    fi
done

# Minimize in solution
if [ ! -d aff/solmin ] ; then
    $BASE/solmin.bash
    #exit
fi
# update list of models
for i in aff/solmin/*/*_SolOpt.pdb ; do
    if [ ! -s aff/models/`basename $i` ] ; then
        # chain Z contains the solvent and ions
	egrep -v '^.{20} Z' $i > aff/models/`basename $i`
        # there should also be a _nosol.pdb file, but for now,
        # we'll play it safe
    fi
done


# Split models in chains
#if [ ! -d aff/chains ] ; then
    # split already checks for existence of chains before making them
    $BASE/split2.sh $R $L
#fi

if [ ! -s aff/stats/hbond$R$L.info ] ; then
    $BASE/hbonds2.sh $R $L 
fi

if [ ! -s aff/stats/contact$R$L.info ] ; then
    $BASE/clashcontact2.sh $R $L 
fi

if [ ! -s aff/stats/RMSD$R$L.tab ] ; then
    $BASE/rmsd2.sh $R $L
fi

if [ ! -d aff/chains/dsx ] ; then
     $BASE/score.sh $R $L
    # if we do not score then create empty score files in aff/stats
    touch aff/stats/dsx${R}${L}.info
    touch aff/stats/xscore${R}${L}.info
fi

#cd aff/stats
$BASE/stats.sh $R $L
#cd ../..

$BASE/summary.sh $R $L

