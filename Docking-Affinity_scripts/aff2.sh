#!/bin/bash
#
#et -x

banner "AFF $1 $2"

R=$1		# Receptor chain(s), e.g. A or AB
L=$2		# Ligand chain

#BASE=`(cd ../script ; pwd)`
BASE=`dirname "$(readlink -f "$0")"`

receptor_reference_pdb=`pwd`/receptor/receptor.pdb

if [ "$CLEAN" == "yes" ] ; then
    rm -rf aff/clean/*
    rm -rf aff/chains/*
    rm -rf aff/clash/*
    rm -rf aff/contact/*
    rm -rf aff/dlscore/*
    rm -rf aff/dsx/*
    rm -rf aff/hbond/*
    rm -rf aff/repulsion/*
#    rm -rf aff/solmin/*
    rm -rf aff/stats/*
    rm -rf aff/summary/*
#    rm -rf aff/vacmin/*
    rm -rf aff/xscore/*
fi


cd .	# ensure pwd is our last and but-last dir

# Pre-populate the models subdirectory with optimized (in vacuo and in
# solution) models.

# Minimize in vacuo with Amber using UCSF Chimera
# Run manually so that all jobs run in parallel, wait for them to complete
# and then continue. There should be a trick to do this in the backup from
# villon (in our grid meta-scheduler).
# NO LONGER NEEDED, WE NOW USE GROMACS WHICH IS A LOT FASTER
# We can still use it by requesting chimera in vacmin2.sh
#if [ ! -d aff/chimin ] ; then
#    echo '' ; #$BASE/chimin.bash $R $L &
#    exit
#fi

# Minimize in vacuo with Amber using GROMACS
# vacmin will check for the existence of proper output and parallelize
# the calculations.
if [ ! -d aff/vacmin ] ; then
#   $BASE/vacmin2.sh $R $L
    #exit
    echo ''
fi
# update list of models
for i in aff/vacmin/*/*_vacuo.pdb ; do
    # if empty or non-existing, skip it
    if [ ! -s "$i" ] ; then continue ; fi
    # if not already copied
    if [ ! -s aff/models/`basename $i` ] ; then
        # copy it to models
	cp $i aff/models/
	#cho "$i"
    fi
done

# Minimize in solution using OPLS-AA and Gromacs
if [ ! -d aff/solmin ] ; then
#   $BASE/solmin2.bash
    #exit
    echo ''
fi
# update list of models
for i in aff/solmin/*/*_solvent.pdb ; do
    # if empty or non-existing, skip it
    if [ ! -s "$i" ] ; then continue ; fi
    # if not already copied
    if [ ! -s aff/models/`basename $i` ] ; then
        # chains Z (or " ") contain the solvent and ions, we'll remove them
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
    $BASE/rmsd2.sh $R $L $receptor_reference_pdb
fi

if [ ! -s aff/stats/xscore-${R}_${L}.info ] ; then
    $BASE/score2.sh $R $L
    # if we do not score then create empty score files in aff/stats
    touch aff/stats/dsx${R}${L}.info
    touch aff/stats/xscore${R}${L}.info
fi

if [ ! -s aff/repulsion-${R}_${L}.tab ] ; then
    $BASE/compute_electrostatic.sh $R $L
fi

#cd aff/stats
$BASE/stats2.sh $R $L
#cd ../..

# join_stats.sh is not totally ready yet.

$BASE/summary2.sh $R $L

