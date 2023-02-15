#!/bin/bash
#
export HEX=$HOME/contrib/hex
export HEX_ROOT=$HOME/contrib/hex
export HEX_VERSION=6d
export PATH=${PATH}:${HEX_ROOT}/bin
export HEX_CACHE=$HOME/contrib/hex/hex6d_cache
export FIRE_DOCK=~/contrib/FireDock
export LD_LIBRARY_PATH=$FIRE_DOCK/lib:$LD_LIBRARY_PATH
export PATH=~/bin:$PATH
cmd=~/work/lenjuanes/script

# avoid refinement because we cannot convert to FireDock format yet
REFINE="no"		# whether to do additional FireDock refinement
USE_FIRST="no"		# no=use best poses at each stage instead of first poses

r=${r:-$1}
dir=`dirname $r`
rbase=`basename $r .pdb`
l=${l:-$2}
lbase=`basename $l .pdb`

# Change to working directory and set up link to model data file
cd $dir

if [ ! -d hex-${rbase}-${lbase} ] ; then mkdir hex-${rbase}-${lbase} ; fi
cd hex-${rbase}-${lbase}

if [ ! -e DONEHD ] ; then 

ln -s ../$rbase.pdb $rbase.ent
ln -s ../$lbase.pdb $lbase.ent
# remove H atoms
grep -v " H$" $rbase.ent > receptor.pdb
grep -v " H$" $lbase.ent > ligand.pdb

# amino acids CHAINS in the receptor and ligand binding sites
touch siter.txt
touch sitel.txt

ln -s $cmd/hex.mac

#hex < hex.mac >& hex.log
hex < hex.mac
#hex 

touch DONEHD

fi


# check if further refinement with FireDock is needed
if [ "$REFINE" == "no" ] ; then exit ; fi


# Do FireDock refinement

if [ "$USE_FIRST" == "yes" ] ; then
    fddir=fd-1st-${rbase}-${lbase}
else
    fddir=fd-top-${rbase}-${lbase}
fi
if [ ! -e $fddir/DONEFD ] ; then
    echo ""
    echo "Doing FireDock"
    echo ""
    # Do FireDock refinement if not done yet or not completed
    # NOTE: right now we do not check for erroneous termination

    if [ ! -d $fddir ] ; then mkdir $fddir ; fi
    cd $fddir


    if [ ! -e model_l.pdb ] ; then ln -s ../ligand.pdb ./model_l.pdb ; fi
    if [ ! -e model_r.pdb ] ; then ln -s ../receptor.pdb ./model_r.pdb ; fi
    if [ ! -e transform.hex ] ; then ln -s ../hex-transform.hex ./transform.hex ; fi
    if [ ! -e sitel.txt ] ; then ln -s ../sitel.txt . ; fi
    if [ ! -e siter.txt ] ; then ln -s ../siter.txt . ; fi

    echo ""
    echo "Preparing files for firedock"
    echo ""
    # Prepare PDB files for refinement
    $FIRE_DOCK/preparePDBs.pl model_r.pdb model_l.pdb All
    

    $FIRE_DOCK/addHydrogens.pl model_r.pdb model_l.pdb

    # Translate Hex output to FireDock input
    # HEX format is
    # Format: Cluster Solution RMS Etotal x y z alpha beta gamma
    # i.e. solution number is in second column, and results are sorted by
    # cluster size (and hopefully significance).
    # FireDock wants the results as
    #
    grep "^[[:digit:]]" transform.hex \
    | while read cl sol rms etot x y z a b g ; do
	#echo $sol $a $b $g $x $y $z
        # angles are in radians
        #echo "$cl $a $b $g $x $y $z"
        echo "$cl $g $b $a $z $y $x"
    done > output.trans

    # select first 500    
    if [ "$USE_FIRST" == "yes" ] ; then
        # NOTE here we assume that output is sorted in relevance order!!!
        #	Actually, it is sorted by cluster, so we are OK
        cat output.trans | head -n 500 > output.500.trans
    else
        # We could try to sort by other score (e.g. 3 RMS or 4 Etotal)...
        # For now, we'll stick to cluster, which is already
        # sorted
        cat output.trans | head -n 500 > output.500.trans
    fi

    echo ""
    echo "Doing FireDock coarse refinement"
    echo ""
    # run coarse refinement (RISCO, 50 cycles of RBO and radiiScale=0.8)
    #	Prepare initial configuration file
    if [ ! -e coarse.txt ] ; then
        $FIRE_DOCK/buildFireDockParams.pl model_r.pdb.CHB.pdb model_l.pdb.CHB.pdb \
    	    U U Default output.500.trans coarse 0 100 0.8 1 coarse.txt

        #	add constraints
        echo "# known interacting amino acids" >> coarse.txt
        echo "receptorFixedResiduesFile siter.txt" >> coarse.txt
        echo "ligandFixedResiduesFile sitel.txt" >> coarse.txt 
    fi
    
    #	do it
    if [ ! -e coarse.ref ] ; then
        $FIRE_DOCK/runFireDock.pl coarse.txt &> coarse.log
	if [ "$USE_FIRST" == "yes" ] ; then
            mkdir coarse-1st
            mv coarse*pdb coarse-1st/
        else
            mkdir coarse-top
            mv coarse*pdb coarse-top/
        fi
    fi

    # select 50 structures to refine further
    if [ "$USE_FIRST" == "yes" ] ; then
        # Convert coarse.ref to firedock "trans" format
        $FIRE_DOCK/PatchDockOut2Trans.pl coarse.ref > coarse.trans
        head -n 50 coarse.trans > coarse.50.trans
    else
        # select best 50
        #	according to FireDock README, we sort the best poses
        #	using field 6 in output.ref (global score) using
        grep    "Sol #" coarse.ref > coarse.sort.ref
        grep -v "Sol #" coarse.ref | grep "|" | sort -nk6 -t"|" >> coarse.sort.ref
        $FIRE_DOCK/PatchDockOut2Trans.pl coarse.sort.ref > coarse.sort.trans
        head -n 50 coarse.sort.trans > coarse.50.trans
    fi
    
    
    # run the full refinement stage (FISCO, 50 cycles of RBO and radiiScale=0.85)
    echo ""
    echo "Doing FireDock full refinement"
    echo ""
    # 	Prepare parameters
    if [ ! -e refined.txt ] ; then
        $FIRE_DOCK/buildFireDockParams.pl model_r.pdb.CHB.pdb model_l.pdb.CHB.pdb \
    	    U U Default coarse.50.trans refined 1 50 0.85 1 refined.txt

        echo "# known interacting amino acids" >> refined.txt
        echo "receptorFixedResiduesFile siter.txt" >> refined.txt
        echo "ligandFixedResiduesFile sitel.txt" >> refined.txt 
    fi

    if [ ! -e refined.ref ] ; then
        $FIRE_DOCK/runFireDock.pl refined.txt &> refined.log
	if [ "$USE_FIRST" == "yes" ] ; then
            mkdir refined-1st
            mv refined*pdb refined-1st/
	else
            mkdir refined-top
            mv refined*pdb refined-top/
        fi
    fi

    # select 10 structures to refine further
    if [ "$USE_FIRST" == "yes" ] ; then
        # Convert refined.ref to firedock "trans" format
        $FIRE_DOCK/PatchDockOut2Trans.pl refined.ref > refined.trans
        head -n 10 refined.trans > refined.10.trans
    else
        # select best 10
        #	according to FireDock README, we sort the best poses
        #	using field 6 in output.ref (global score) using
        grep    "Sol #" refined.ref > refined.sort.ref
        grep -v "Sol #" refined.ref | grep "|" | sort -nk6 -t"|" >> refined.sort.ref
        $FIRE_DOCK/PatchDockOut2Trans.pl refined.sort.ref > refined.sort.trans
        head -n 10 refined.sort.trans > refined.10.trans
    fi


    # run full side-chain optimization again, without RBO) and print the complexes
    echo ""
    echo "Doing FireDock final refinement"
    echo ""
    #	Prepare input parameters
    if [ ! -e final.txt ] ; then
        $FIRE_DOCK/buildFireDockParams.pl model_r.pdb.CHB.pdb model_l.pdb.CHB.pdb \
    	    U U Default refined.10.trans solution 1 0 0.85 1 final.txt

        echo "# known interacting amino acids" >> final.txt
        echo "receptorFixedResiduesFile siter.txt" >> final.txt
        echo "ligandFixedResiduesFile sitel.txt" >> final.txt 
    fi

    if [ ! -e solution.ref ] ; then
        $FIRE_DOCK/runFireDock.pl final.txt &> final.log
	if [ "$USE_FIRST" == "yes" ] ; then
            mkdir solution-1st
            mv solution*pdb solution-1st
	else
            mkdir solution-top
            mv solution*pdb solution-top
        fi
    fi
    touch DONEFD

    cd ..

fi

ln -s $fddir/solution-* .

cd ..
touch DONE
