#!/bin/bash
#
#set -x
#
#export PATCH_DOCK=/opt/structure/PatchDock
#export FIRE_DOCK=/opt/structure/FireDock
export PATCH_DOCK=~/contrib/PatchDock
export FIRE_DOCK=~/contrib/FireDock
babel=obabel


REFINE="yes"		# whether to do additional FireDock refinement
USE_FIRST="no"		# no=use best poses at each stage instead of first poses
TYPE="drug"		# The types of docking available are: 
			#    EI:enzyme/inhibitor, 
			#    AA:antibody/antigen, 
			#    drug:protein/drug, 
			#    default

if [ $# -lt 2 ] ; then
    echo "Usage $0 receptor.pdb ligand.{pdb|mol2}"
    exit
fi

function abspath() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
        # dir
        (cd "$1"; pwd)
    elif [ -f "$1" ]; then
        # file
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
	return $OK
    else
        #echo "/dev/null"
        echo "abspath: ---FILE-DOES-NOT-EXIST---"
	return $ERROR
    fi
}

#     # dissect input file names
rec=`abspath $1`
rdir=`dirname $rec`
rfin="${rec##*/}"
rext="${rfin##*.}"
rnam="${rfin%.*}"
if [ ! "$rext" == "pdb" -a ! "$rext" == "brk" -a ! "$rext" == "ent" ] ; then
    echo "patchdock ERROR: Receptor file must be a PDB file."
    exit 1
fi

lig=`abspath $2`
ldir=`dirname $lig`
lfin="${lig##*/}"
lext="${lfin##*.}"
lnam="${lfin%.*}"
if [ ! "$lext" == "pdb" -a ! "$lext" == "brk" -a ! "$lext" == "ent" \
   -a ! "$lext" == "mol2" ] ; then
    echo "patchdock ERROR: Ligand file must be a PDB or MOL2 file."
    exit 2
fi
lll="$lnam   "    # ensure lll has length at least 3 spaces
lll=${lll:0:3}		# extract first three letters of ligand name
lll=`echo $lll | tr [:lower:] [:upper:]`	# and make uppercase


r=$rec
l=$lig
baser=$rnam
basel=$lnam


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


cd `dirname $1`

if [ -e pd-${baser}-${basel}/DONE ] ; then exit ; fi

if [ ! -d pd-${baser}-${basel} ] ; then mkdir pd-${baser}-${basel} ; fi

cd pd-${baser}-${basel}

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



if [ ! -e DONEPD ] ; then
    # use these instead if we want to use any included H
    #if [ ! -e model_l.pdb ] ; then ln -s ../$l model_l.pdb ; fi
    #if [ ! -e model_r.pdb ] ; then ln -s ../$r model_r.pdb ; fi
    ln -s $rec $baser.ent
    # prepare initial PDB ligand file
    if [ "$lext" != "mol2" ] ; then
        ln -s $lig $basel.ent
    else
        $babel -imol2 $lig -opdb \
	| sed -e "s/^ATOM  /HETATM/g" -e "s/^\(.\{17\}\).../\1${lll}/g" \
	| grep -v "^CONECT" \
	> $basel.ent
    fi
    # remove H atoms
    grep -v " H$" $baser.ent > model_r.pdb
    grep -v " H$" $basel.ent > model_l.pdb


    # Do PtachDock docking if not done yet (or not completed)
    # NOTE: right now we do not check for erroneous termination

    # Create parameter file
    $PATCH_DOCK/buildParams.pl model_r.pdb model_l.pdb 4.0 $TYPE

    # Create molecular surfaces
    $PATCH_DOCK/buildMS.pl model_r.pdb model_l.pdb 

#    # Add our own known constrains ("active site" residues)
    cat > siter.txt <<END
END
#50 A
#203 A
#END
    cat > sitel.txt <<END
END

    echo "# known interacting amino acids " >> params.txt
    echo "receptorActiveSite siter.txt" >> params.txt
    echo "ligandActiveSite sitel.txt" >> params.txt

    # Dock
    echo ""
    echo "Doing PatchDock"
    echo ""
    $PATCH_DOCK/patch_dock.Linux params.txt output > patch_dock_std.log 2>&1

    # Generate models
    echo ""
    echo "Generating PatchDock models"
    echo ""
    $PATCH_DOCK/transOutput.pl output 1 100
    
    mkdir models
    for i in {1..100} ; do 
        if [ -e output.$i.pdb ] ; then 
            mv output.$i.pdb models/output-`printf %03d $i`.pdb
        fi
    done

    touch DONEPD
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
    if [ ! -e output.pd.ref ] ; then ln -s ../output ./output.pd.ref ; fi
    if [ ! -e sitel.txt ] ; then ln -s ../sitel.txt . ; fi
    if [ ! -e siter.txt ] ; then ln -s ../siter.txt . ; fi

    export LD_LIBRARY_PATH=$FIRE_DOCK/lib:$LD_LIBRARY_PATH

    echo ""
    echo "Preparing files for firedock"
    echo ""
    # Prepare PDB files for refinement
    $FIRE_DOCK/preparePDBs.pl model_r.pdb model_l.pdb All
    

    $FIRE_DOCK/addHydrogens.pl model_r.pdb model_l.pdb

    # Translate PatchDock output to FireDock input
    $FIRE_DOCK/PatchDockOut2Trans.pl output.pd.ref > output.trans

    # select first 500    
    if [ "$USE_FIRST" == "yes" ] ; then
        # NOTE here we assume that output is sorted in relevance order!!!
        #	Actually, it is sorted by score, so we are OK
        cat output.trans | head -n 500 > output.500.trans
    else
        # We could try to use other score (e.g. 10 Energy, which is currently
        # unused, 4 Area (interface area), 8 ACE (atomic contact energy),
        # 9 hydroph. (hydrophobic contact area), 12 dist (closest distance 
        # constraint)... For now, we'll stick to score, which is already
        # sorted
        cat output.trans | head -n 500 > output.500.trans
	#	FOR NOW, SAME AS
        #grep    "| score |" output.pd.ref > output.500.ref
        #grep -v "| score |" | grep "|" | sort -rk2 -t "|" >> output.sort.ref
	#$FIRE_DOCK/PatchDockOut2Trans.pl output.sort.ref >> output.sort.trans 
        #head -n 500 output.sort.trans > output.500.trans
    fi

    echo ""
    echo "Doing FireDock coarse refinement"
    echo ""
    # run coarse refinement (RISCO, 50 cycles of RBO and radiiScale=0.8)
    #	Prepare initial configuration file
    if [ ! -e coarse.txt ] ; then
        $FIRE_DOCK/buildFireDockParams.pl \
	    model_r.pdb.CHB.pdb \
	    model_l.pdb.CHB.pdb \
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
