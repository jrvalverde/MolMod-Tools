#!/bin/bash

export ZDOCK=$HOME/contrib/zdock
export FIRE_DOCK=~/contrib/FireDock
export LD_LIBRARY_PATH=$FIRE_DOCK/lib:$LD_LIBRARY_PATH


REFINE="yes"		# whether to do additional FireDock refinement
USE_FIRST="no"		# use best poses at each stage instead of first poses
ADDH="no"		# add H to the input structures for zdock
startn=500		# number of poses to refine with firedock

r=`basename $1`
l=`basename $2`
base=`dirname $1`
baser=`basename $1 .pdb`
basel=`basename $2 .pdb`

zdir=zdock-${baser}-${basel}

function backup_file {
    local f=$1
    i=0
    if [ ! -d bck ] ; then mkdir -p bck ; fi
    while [ -e bck/$f.`printf %03d $i` ] ; do
        i=$((i + 1))
    done
    echo saving $f as bck/$f.`printf %03d $i`
    cp $f bck/$f.`printf %03d $i`
}


# Change to working directory and set up link to model data file
if [ ! -d "$base" ] ; then mkdir "$base" ; fi
cd $base

if [ ! -d $zdir ] ; then mkdir $zdir ; fi
cd $zdir

# Save all output to a log file
log=zyglog.outerr
if [ -e $log ] ; then
    backup_file $log
fi
# Tee output and error to a log file
#appendlog='-a'
appendlog=''
exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")
# ... or to two separate files without screen output
#stdout=./$name/log.$myname.out
#stderr=./$name/log.$myname.err
#exec > $stdout 2> $stderr


# Don't repeat zdock if already done
if [ ! -e DONEZD ] ; then

    if [ ! -e uniCHARMM ] ; then
        ln -s $ZDOCK/uniCHARMM .
    fi

#cat ZINC03075225.mol2 | sed -e 's/ \([A-Z]\+\)[0-9]\+ / \1 /g' > kk.mol2

    # use these instead if we want to use any included H
    #ln -s ../$baser.pdb model_r.pdb
    #ln -s ../$basel.pdb model_l.pdb
    if [ ! -e $baser.ent ] ; then
       ln -s ../$baser.pdb $baser.ent
    fi
    if [ ! -e $basel.ent ] ; then
       ln -s ../$basel.pdb $basel.ent
    fi
    # remove H atoms
    if [ ! -e model_r.pdb ] ; then
        grep -v " H$" $baser.ent > model_r.pdb
    fi
    if [ ! -e model_l.pdb ] ; then
        grep -v " H$" $basel.ent > model_l.pdb
    fi
    
    # prepare proteins
    if [ "$ADDH" == "yes" ] ; then
        echo "Adding H"
        echo ""
        echo "        $FIRE_DOCK/addHydrogens.pl model_r.pdb model_l.pdb    
	"
        $FIRE_DOCK/addHydrogens.pl model_r.pdb model_l.pdb    
        $ZDOCK/mark_sur model_r.pdb.HB rec_z.pdb
        $ZDOCK/mark_sur model_l.pdb.HB lig_z.pdb
    else
        if [ ! -s rec_z.pdb ] ; then
            $ZDOCK/mark_sur model_r.pdb rec_z.pdb
        fi
	if [ ! -s lig_z.pdb ] ; then
            $ZDOCK/mark_sur model_l.pdb lig_z.pdb
	fi
    fi
    
    # Prepare empty binding sites
    touch sitel.txt siter.txt
    #	zdock takes a list of non-binding a.a. instead of a list of binding a.a.
    #	Thus, we would need to complement the list of a.a. for each chain
    #	run block.pl on the list of non-binding a.a. for each chain
    #	to set the ACE type of non-binding a.a. to 19
    #	reconstitute the models from its processed chains
    #	and then use them

    if [ ! -s zdock.out ] ; then
        echo ""
        echo "Running ZDOCK"
        echo ""
        echo "    $ZDOCK/zdock -R rec_z.pdb -L lig_z.pdb -o zdock.out
        "
        $ZDOCK/zdock -R rec_z.pdb -L lig_z.pdb -o zdock.out
    fi
    # Default is to produce 2000 poses, take the first $startn
    lines=$((startn + 4))
    head -n$lines zdock.out > zdock.$startn.out

    if [ ! -d complexes ] ; then
        mkdir -p complexes
    fi
    cd complexes
      if [ ! -e complex.1.pdb ] ; then
          ln -s $ZDOCK/create_lig .
          ln -s ../*pdb .
          ln -s ../*.out .
          perl $ZDOCK/create.pl zdock.$startn.out
          # this generates files complex.1 ... complex.n
          # rename to .pdb
          for i in complex* ; do mv $i $i.pdb ; done
      fi
      # remove extra information (chimera chokes on it, but not rasmol or pymol)
      # and rename as .ent
      # complex.1.pdb --> complex-001.ent
      # ...
      # complex.10.pdb -> complex-010.ent
      # ...
      # complex.499.pdb -> complex-499.ent
      for i in $(seq 1 $startn) ; do
      #for i in {1..$startn} ; do
      #for {{ i=1; i <=500; i++}} ; do
          n=`printf %02d $i`
          if [ -e complex-$n.ent ] ; then continue ; fi
          if [ -e complex.$i.pdb ] ; then
	      cat complex.$i.pdb | cut -b 1-63 > complex-$n.ent
          fi
      done
    cd ..	# out of complexes

    # we are now in $zdir
    touch DONEZD
fi


# check if further refinement with FireDock is needed
if [ "$REFINE" == "no" ] ; then exit ; fi


# Do FireDock refinement

if [ "$USE_FIRST" == "yes" ] ; then
    fddir=fd-1st-${baser}-${basel}
else
    fddir=fd-top-${baser}-${basel}
fi
if [ ! -e $fddir/DONEFD ] ; then
    echo ""
    echo "Doing FireDock"
    echo ""
    # Do FireDock refinement if not done yet or not completed
    # NOTE: right now we do not check for erroneous termination

    if [ ! -d $fddir ] ; then mkdir $fddir ; fi
    cd $fddir


    if [ ! -e model_l.pdb ] ; then ln -s ../model_l.pdb . ; fi
    if [ ! -e model_r.pdb ] ; then ln -s ../model_r.pdb . ; fi
    if [ ! -e output.zd.ref ] ; then ln -s ../zdock.out ./output.zd.ref ; fi
    if [ ! -e sitel.txt ] ; then ln -s ../sitel.txt . ; fi
    if [ ! -e siter.txt ] ; then ln -s ../siter.txt . ; fi

    echo ""
    echo "Preparing files for firedock"
    echo ""
    # Prepare PDB files for refinement
    $FIRE_DOCK/preparePDBs.pl model_r.pdb model_l.pdb All
    

    $FIRE_DOCK/addHydrogens.pl model_r.pdb model_l.pdb

    # Translate PatchDock output to FireDock input
    #$FIRE_DOCK/PatchDockOut2Trans.pl output.zd.ref > output.trans
    #	for zdock
    $FIRE_DOCK/ZDOCKOut2Trans.pl output.zd.ref > output.trans

    # select first 500    
    if [ "$USE_FIRST" == "yes" ] ; then
        # NOTE here we assume that output is sorted in relevance order!!!
        cat output.trans | head -n 500 > output.500.trans
    else
        # We could try to use other score (but it would require more work
        # to process the output file of zdock)... 
        # For now, we'll stick to the default order
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
