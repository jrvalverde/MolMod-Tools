#!/bin/bash
#
#et -x

banner "AFF $1 $2"

R=$1		# Receptor chain(s), e.g. A or AB
L=$2		# Ligand chain

#BASE=`(cd ../script ; pwd)`
BASE=`dirname "$(readlink -f "$0")"`

cd .	# ensure pwd is our last and but-last dir

# Minimize in vacuo with Amber using UCSF Chimera
# Run manually so that all jobs run in parallel, wait for them to complete
# and then continue. There should be a trick to do this in the backup from
# villon (in our grid meta-scheduler).
# NO LONGER NEEDED, WE NOW USE GROMACS WHICH IS A LOT FASTER
#if [ ! -d aff/chimin ] ; then
#    echo '' ; #$BASE/chimin.bash $R $L &
#    exit
#fi

# Minimize in vacuo with Amber using GROMACS
# vacmin will check for the existence of proper output and parallelize
# the calculations.
#if [ ! -d aff/vacmin ] ; then
    $BASE/vacmin2.sh $R $L
    #exit
#fi
# update list of models
for i in aff/vacmin/*/*_vacuo.pdb ; do
    if [ ! -s aff/models/`basename $i` ] ; then
	cp $i aff/models/
	#cho "$i"
    fi
done

# Minimize in solution using OPLS-AA and Gromacs
#if [ ! -d aff/solmin ] ; then
    $BASE/solmin2.bash
    #exit
#fi
# update list of models
for i in aff/solmin/*/*_solvent.pdb ; do
    if [ ! -s aff/models/`basename $i` ] ; then
        # chains Z (or " ") contain the solvent and ions
	egrep -v '^.{20} Z' $i \
	| egrep -v '^.{20}  ' > aff/models/`basename $i`
	#cho "$i"
    fi
done


# Split models in chains
#if [ ! -d aff/chains ] ; then
    # split already checks for existence of chains before making them
    $BASE/split2.sh $R $L
#fi

if [ ! -s aff/stats/hbond-$R-$L.info ] ; then
    $BASE/hbonds2.sh $R $L 
fi

if [ ! -s aff/stats/contact-$R-$L.info ] ; then
    $BASE/clashcontact2.sh $R $L 
fi

if [ ! -s aff/stats/RMSD-$R-$L.tab ] ; then
    $BASE/rmsd2.sh $R $L
fi

if [ ! -s aff/stats/xscore-${R}_${L}.info ] ; then
    $BASE/score2.sh $R $L
    # if we do not score then create empty score files in aff/stats
    touch aff/stats/dsx${R}${L}.info
    touch aff/stats/xscore${R}${L}.info
fi

if [ ! -s aff/repulsion-${R}_${L}.tab ] ; then
    $BASE/compute_esctrostatic.sh $R $L
fi

#cd aff/stats
$BASE/stats2.sh $R $L
#cd ../..

# join_stats.sh is not totally ready yet.

$BASE/summary2.sh $R $L

