#!/bin/bash

activate gromacs

md=${1:-step7}
if [ "$2" != "" ] ; then
    ref=$2
fi
if [ "$3" != "" ] ; then
    chainmatch="$3"
fi

TRUE=0
FALSE=1


function rmsd_vs_ref() {
    ref="$1"	# e.g. reference.pdb
    trj="$2"	# e.g. md_01.xtc
    match="$3"  # e.g. A=B,B=C,...

    declare -a ref_chains
    declare -a trj_chains

    local rf="${ref##*/}"	# filename with no dir
    local re="${ref##*.}"	# extension (pdb or gro)
    local rn="${rf%.*}"		# name
    if [ ! -e "$ref" ] ; then
        echo "rmsd_vs_ref: $ref not found!"
        return
    else
        # make a local copy
        if [ ! -e $rf ] ; then
            cp $ref $rf
        fi
    fi

    local tf="${trj##*/}"	# filename with no dir
    local te="${trj##*.}"	# extension (pdb or gro)
    local tn="${tf%.*}"		# name
    if [ ! -e "$trj" ] ; then
        echo "rmsd_vs_ref: $trj not found!"
        return
    else
        # make a local copy
        if [ ! -e $tf ] ; then
            cp $trj $tf
        fi
	if [ ! -e $tn.tpr ] ; then
            # this way we do not assume a specific trajectory type
            cp `echo $trj | sed -e "s/\.$te\$/\.tpr/g"` $tn.tpr
        fi
    fi
    
    # parse chain correspondence list of the form
    # A=A,B=C,...
    # where the left side of an equal refers to the chain-id in the
    # reference and the right side to the chain-id in the trajectory
    ref_chains=( `echo "$match" | sed -e 's/=.//g' -e 's/,/ /g'` )
    trj_chains=( `echo "$match" | sed -e 's/.=//g' -e 's/,/ /g'` )
    nrefch=${#ref_chains[@]}
    ntrjch=${#trj_chains[@]}
    if [ $nrefch -ne $ntrjch ] ; then
        echo "rmsd_vs_ref: invalid match sequence $match"
        return
    fi
    echo "rmsd_vs_ref: matching chains are $match"
    echo "rmsd_vs_ref: reference chains are ${ref_chains[@]}"
    echo "rmsd_vs_ref: trajectory chains are ${trj_chains[@]}"

    # set the reference structure
    if [ "$re" != "pdb" ] ; then
        if [ "$re" == "gro" ] ; then
            if [ -e "$rn.tpr" ] ; then
                gmx trjconv -f "$rf" -s "$rn.tpr" -o "$rn.pdb"
            else
                gmx editconf -f "$rf" -o "$rn.pdb"
            fi
        elif [ "$re" == ".brk" -o "$re" == "ent" ] ; then
            cp $rf $rn.pdb
        else
            echo "rmsd_vs_ref: unknown reference format (.$re)"
        fi
    fi
    # and index it
    $BASE/make_ext_index.sh $rn.pdb
    
    
    # obtain the first structure in the trajectory to ensure
    # that the reference used is superposed to the matched
    # structure at the beginning of the trajectory
    if [ ! -e $tn.0.pdb ] ; then
        echo System | gmx trjconv -f $tf -s $tn.tpr \
            -o $tn.0.pdb \
            -dump 0 -pbc mol -conect
    fi
    
    if [ ! -e reference.pdb ] ; then
        mkdir -p str-align
        # align the reference molecule to the first structure in the trajectory
        cp $rn.pdb   str-align
        cp $tn.0.pdb str-align

        cd str-align
        # superpose the structures
        theseus_align -o $tn.0.pdb -f $tn.0.pdb $rn.pdb \
            |& tee theseus.stdouterr

        # index the superposed structures
        $BASE/make_ext_index.sh theseus_$rn.pdb
        $BASE/make_ext_index.sh theseus_$tn.0.pdb
        cd ..
        cp str-align/theseus_$rn.pdb reference.pdb
    fi

    if [ ! -e ref_rmsd.xvg ] ; then
        # Obtain overall RMSD (which will include the PBMs)
        gmx rms -s reference.pdb \
                -f $tf \
                -o ref_rmsd.xvg \
                -tu ns \
                << END
C-alpha
C-alpha
END
    fi

    # make a PNG plot 1000x1000
    rm ref_rmsd.PNG 
    grace -hardcopy -hdevice PNG \
          -printfile ref_rmsd.PNG \
          ref_rmsd.xvg \
          -pexec 'runavg(S0,100)' \
          -fixed 1000 1000 
    #display ref_rmsd.PNG

    # Check if we have any chains to compare specifically
    if [ $nrefch -eq 0 ] ; then return ; fi

    # Create new groups to join the reference chains and extract their C-alpha
    (
        # build a group joining all reference chains
        # eg. chain A | chain B
        echo -n "chain ${ref_chains[0]}"
        #for i in $(seq 1 ${#ref_chains[*]}) ; do 
        for (( i=1; i<$nrefch; i++ )) ; do 
            echo -n " | chain ${ref_chains[$i]}"
        done
        echo ""
        # intersect reference chains with C-alpha
        # e.g. "chA_chB" | "C-alpha"
        echo -n "\"ch${ref_chains[0]}"
        for (( i=1; i<$nrefch; i++ )) ; do 
            echo -n "_ch${ref_chains[$i]}"
        done
        echo "\" & \"C-alpha\""
        # write index
        echo "q"
    ) |& gmx make_ndx -f reference.pdb -o reference.ndx 

    # Create new groups to join the match chains and extract their C-alpha
    (
        # build a group joining all reference chains
        # eg. chain A | chain B
        echo -n "chain ${trj_chains[0]}"
        #for i in $(seq 1 ${#trj_chains[*]}) ; do 
        for (( i=1; i<$ntrjch; i++ )) ; do 
            echo -n " | chain ${trj_chains[$i]}"
        done
        echo ""
        # intersect reference chains with C-alpha
        # e.g. "chA_chB" | "C-alpha"
        echo -n "\"ch${trj_chains[0]}"
        for (( i=1; i<$ntrjch; i++ )) ; do 
            echo -n "_ch${trj_chains[$i]}"
        done
        echo "\" & \"C-alpha\""
        # write index
        echo "q"
    ) | gmx make_ndx -f $tn.0.pdb -o $tn.0.ndx 

    # Compute RMSD using the md_01.0.ndx index so we can select the C-alpha
    # of the desired chains
    # first we need to build the comparison groups
    (
        # C-alpha in reference chains
        # e.g. chA_chB_&_C-alpha
        echo -n "ch${ref_chains[0]}"
        for (( i=1; i<$nrefch; i++ )) ; do 
            echo -n "_ch${ref_chains[$i]}"
        done
        echo "_&_C-alpha"
        
        # C-alpha in trajectory chains
        # e.g. chA_chC_&_C-alpha
        echo -n "ch${trj_chains[0]}"
        for (( i=1; i<$ntrjch; i++ )) ; do 
            echo -n "_ch${trj_chains[$i]}"
        done
        echo "_&_C-alpha"
    ) \
    | gmx rms -s reference.pdb \
            -f $tf \
            -o ref_rmsd_CA_$match.xvg \
            -tu ns \
            -n $tn.0.ndx 

    # make a PNG plot 1000x1000
    rm ref_rmsd_CA_$match.PNG 
    grace -hardcopy -hdevice PNG \
          -printfile ref_rmsd_CA_$match.PNG \
          ref_rmsd_CA_$match.xvg \
          -pexec 'runavg(S0,100)' \
          -fixed 1000 1000
    #display ref_rmsd_CA_$match.PNG

    return
}


if [ ! -s ${md}.trr -a ! -e ${md}.xtc ] ; then
    echo "MD trajectory $md.trr does not exist! Trying to build it..."
    echo "	We will use \${md}_\$no.trr for \$no=1 to n"

    # concat all sub-trajectories together
#    if [ ! -e ${md}.trr ] ; then
#	gmx trjcat -f ${md}_?.trr ${md}_10.trr -o ${md}.trr -cat 
#    fi
#    if [ ! -s ${md}.trr ] ; then
#        echo "MD trajectory $md.trr does not exist!"
#	exit
#    fi

    # use -conect to preserve bonds in coarse grained trajectories or when
    # including non-protein molecules when converting to PDB

    cmdtrr="gmx trjcat -cat -o ${md}.trr -f"
    cmdxtc="gmx trjcat -cat -o ${md}.xtc -f"
    cmdedr="gmx eneconv -o ${md}.edr -f"
    i=1
    while [ -e ${md}_$i.trr ] ; do    
        # prepare command to make trajectory
        cmdtrr="${cmdtrr} ${md}_${i}.trr"
	
	# prepare command to make compressed trajectory
	if [ ! -e  ${md}_${i}.xtc ] ; then
	    echo System | gmx trjconv -o ${md}_${i}.xtc \
	        -f ${md}_${i}.trr -s ${md}_${i}.tpr
	fi
        cmdxtc="${cmdxtc} ${md}_${i}.xtc"
	
        # prepare command to make energy file
	if [ -e ${md}_$i.edr ] ; then
	    cmdedr="${cmdedr} ${md}_${i}.edr"
        else
            echo "WARNING: ${md}_${i}.edr DOES NOTE EXIST!"
            echo "	Your ENERGY plots will be unreliable"
        fi
	
	# preserve the original topology
	if [ ! -e ${md}.tpr ] ; then
            # use the last topology available
	    #cp ${md}_${i}.tpr ${md}.tpr
	    # only use the first topology (next iterations will find that a
	    # topology does already exist
            cp ${md}_1.tpr ${md}.tpr

	fi

        # ensure last output structure is preserved
	cp ${md}_$i.gro ${md}.gro


        i=$((i + 1))
    done
    if [ $i -ne 1 ] ; then
        eval $cmdtrr
	eval $cmdxtc
        eval $cmdedr
    else
        echo "	No partial sub-trajectories ${md}_* found!"
        echo "	EXITING"
        exit
    fi
fi

if [ ! -e ${md}.edr ] ; then
    echo "ERROR: ${md}.edr FILE DOES NOT EXIST"
    echo "EXITING"
    exit
fi


# remove PBC
if [ ! -e ${md}.noPBC.xtc ] ; then
    echo System | gmx trjconv -f ${md}.xtc -s ${md}.tpr -o ${md}.noPBC.xtc \
    	-pbc mol -ur compact
fi

# ensure we do have a *full* PDB file of the last conformation saved
if [ ! -e ${md}.pdb ] ; then
    # convert last frame to pdb
    echo System | gmx trjconv -f ${md}.gro -s ${md}.tpr -o ${md}.pdb \
         -pbc mol -conect
fi

# ensure we have a reference initial structure (GRO and PDB)
#	This should allow us to define a reference structure for the RMSD
#	analysis.
#	But we should devise a system to carry out a selective RMSD
#	analysis against only some chains (not the whole system or the
#	whole protein) for the case when we want to track only some
#	molecules.
if [ ! -e ${md}.0.pdb ] ; then
    # save first frame
    echo System | gmx trjconv -f ${md}.xtc -s ${md}.tpr -o ${md}.0.gro \
         -dump 0 -pbc mol
    echo System | gmx trjconv -f ${md}.xtc -s ${md}.tpr -o ${md}.0.pdb \
         -dump 0 -pbc mol -conect
fi



# ----------------------
# DO THE ANALYSIS ITSELF
#-----------------------
BASE=`dirname $0`
$BASE/analyze_md_run.sh ${md} 2>&1 | tee ${md}_analyze.log

alias bold=`tput bold`
alias plain=`tput sgr0`
alias black=`tput setaf 0`
alias red=`tput setaf 1`
alias green=`tput setaf 2`
alias blue=`tput setaf 4`

if [ "$ref" != "" ] ; then
    cp $ref ${md}_analysis
    cd ${md}_analysis
    echo "$bold$blue Computing rmsd against $ref $chainmatch$black$plain"
    rmsd_vs_ref $ref ${md}.xtc $chainmatch
    cd ..
fi

# final cleanup to ensure all xvg files have been translated
# into PNG files, and in case some gro files have not been 
# converted to pdb, convert them
cd ${md}_analysis

for i in *.xvg ; do 
    grace -hardcopy -hdevice PNG \
    -printfile `basename $i xvg`png \
    -fixed 1000 1000 \
    $i 
    echo "$bold${green}Plotted $i $plain$black"
done


tpr=''
for i in *.gro ; do 
    n=`basename $i .gro`
    if [ ! -e $n.pdb ] ; then
        if [ -e $n.tpr ] ; then
	    tpr=$n.tpr
	else
	    # if there is no $n.tpr then we'll use the project's one
	    tpr=$md.tpr
	fi
	# editconf does not preserve the chain info (does not use 
        # any .tpr file)
        #gmx editconf -f $i -o $n.pdb -pbc mol
	# -conect adds conect records which is useful for coarse grained
	# simulations and models containing non-protein molecules
	echo "System" | gmx trjconv -f $i -s $tpr -o $n.pdb -pbc mol -conect
	#echo "TPR used is $tpr"
        echo "$bold${green}Converted $i $plain$black"
    fi
done
egrep -v '( SOL | WAT |TIP3| CLA | NA | POT )' ${md}_clustav.pdb > ${md}_clustav_nosol.pdb
egrep -v '( SOL | WAT |TIP3| CLA | NA | POT )' ${md}_clusters.pdb > ${md}_clusters_nosol.pdb
egrep -v '( SOL | WAT |TIP3| CLA | NA | POT |DPPC)' ${md}_clustav.pdb > ${md}_clustav_protein.pdb
egrep -v '( SOL | WAT |TIP3| CLA | NA | POT |DPPC)' ${md}_clusters.pdb > ${md}_clusters_protein.pdb

cd ..


pwd 
echo "$(tput setaf 4)DONE$(tput setaf 0)"

