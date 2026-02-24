#!/bin/bash


function gmx_trj_rmsd_vs_ref() {
    local ref="${1}"	# e.g. reference.pdb
    local trj="$2}"	# e.g. md_01.xtc
    local match="$3"  # e.g. A=B,B=C,...

    local declare -a ref_chains
    local declare -a trj_chains

    local rf="${ref##*/}"	# filename with no path
    local re="${ref##*.}"	# extension (pdb or gro)
    local rn="${rf%.*}"		# name
    
    if [ ! -e "$ref" ] ; then
        notecont "$ref not found!"
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
        notecont "$trj not found!"
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
        notecont "invalid match sequence $match"
        return
    fi
    notecont "matching chains are $match"
    notecont "reference chains are ${ref_chains[@]}"
    notecont "trajectory chains are ${trj_chains[@]}"

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
            notecont "unknown reference format (.$re)"
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
