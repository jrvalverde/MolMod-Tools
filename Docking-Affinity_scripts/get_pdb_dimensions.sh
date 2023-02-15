#!/bin/bash
#

function get_pdb_dimensions() {
    if [ $# -lt 1 ] ; then errexit "pdbfile [min|max|size|all]" 
    else notecont $* ; fi
    pdb=${1:-input.pdb}
    dim=$2		# may be "min" "max" "size" or empty

    #echo $pdb $dim
    #ATOM/HETAM
    #COLUMNS        DATA  TYPE    FIELD        DEFINITION
    #-------------------------------------------------------------------------------------
    # 1 -  6        Record name   
    # 7 - 11        Integer       serial       Atom  serial number.
    #13 - 16        Atom          name         Atom name.
    #17             Character     altLoc       Alternate location indicator.
    #18 - 20        Residue name  resName      Residue name.
    #22             Character     chainID      Chain identifier.
    #23 - 26        Integer       resSeq       Residue sequence number.
    #27             AChar         iCode        Code for insertion of residues.
    #31 - 38        Real(8.3)     x            Orthogonal coordinates for X in Angstroms.
    #39 - 46        Real(8.3)     y            Orthogonal coordinates for Y in Angstroms.
    #47 - 54        Real(8.3)     z            Orthogonal coordinates for Z in Angstroms.
    #55 - 60        Real(6.2)     occupancy    Occupancy.
    #61 - 66        Real(6.2)     tempFactor   Temperature  factor.
    #77 - 78        LString(2)    element      Element symbol, right-justified.
    #79 - 80        LString(2)    charge       Charge  on the atom.
    #
    #

    xsrt=./~x~.srt
    cat $pdb \
    | grep '\(^ATOM  \|^HETATM\)' \
    | cut -c31-38 \
    | sort -g \
    > $xsrt
    xmin=`head -1 $xsrt`
    xmax=`tail -1 $xsrt`
    xsize=`echo "$xmax - $xmin" | bc -l`
    #echo "x	$xmin	$xmax	$xsize"
    rm $xsrt

    ysrt=./~y~.srt
    cat $pdb \
    | grep '\(^ATOM  \|^HETATM\)' \
    | cut -c39-46 \
    | sort -g \
    > $ysrt
    ymin=`head -1 $ysrt`
    ymax=`tail -1 $ysrt`
    ysize=`echo "$ymax - $ymin" | bc -l`
    #echo "y	$ymin	$ymax	$ysize"
    rm $ysrt

    zsrt=./~z~.srt
    cat $pdb \
    | grep '\(^ATOM  \|^HETATM\)' \
    | cut -c39-46 \
    | sort -g \
    > $zsrt
    zmin=`head -1 $zsrt`
    zmax=`tail -1 $zsrt`
    zsize=`echo "$zmax - $zmin" | bc -l`
    #echo "z	$zmin	$zmax	$zsize"
    rm $zsrt

    if [ "$dim" == "min" ] ; then
    echo "$xmin	$ymin	$zmin"
    elif [ "$dim" == "max" ] ; then
    echo "$xmax	$ymax	$zmax"
    elif [ "$dim" == "size" ] ; then
    echo "$xsize	$ysize	$zsize"
    else
    echo "x	$xmin	$xmax	$xsize"
    echo "y	$ymin	$ymax	$ysize"
    echo "z	$zmin	$zmax	$zsize"
    fi
}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    LIB=$HOME/work/bin/lib
    # -v variable is set? -z is zero-length string"
    [[ -v $SETUP_CMDS ]] && source $LIB/setup_cmds.bash
    [[ -z $UTIL_FUNCS ]] && source $LIB/util_funcs.bash

    VERBOSE=0
    get_pdb_dimensions $*
else
    export GET_PDB_DIMENSIONS
fi

