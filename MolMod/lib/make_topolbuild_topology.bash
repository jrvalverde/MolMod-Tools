#
# NAME
#	make_topolbuild_topology
#
# SYNOPSIS
#	make_topolbuild_topology ligand.pdb charge
#
# DESCRIPTION
#	Create an OPLS-AA topology for a ligand PDB file using topolbuild.
#	Results will be saved in directory $ligand.topolbuild
#
#	Planned for the future:
#
#	topolbuild can also generate gromacs gmx43a1 gmx43a2 gmx43b1
#	gmx45a3 gmx45a5 gmx53a5 and gmx53a6 topologies.
#
#	In addition it can also generate Tripos topologies, and Amber
#	gaff glycam04 glycam 04EP glycam_06c amber91 amber91X amber94
#	amber96 amber98 amber99 amber99EP amberAM1 and amberPM3 topologies 
#	which we could try to convert to gromacs format.
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
MAKE_TOPOLBUILD_TOPOLOGY='MAKE_TOPOLBUILD_TOPOLOGY'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


function make_topolbuild_topology {
    #if [ $# -lt 1 ] ; then errexit "ligand.mol2 [ff]" 
    #else notecont $* ; fi
    if ! funusage $# ligand.mol2 [ff] ; then return $ERROR ; fi
    notecont $*

    local mol=$1
    local ff=${2:-'oplsaa'}	# supports oplsaa and various gmx*
    
    local dir=`dirname $mol`
    local fin="${mol##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    
    # defaults for global variables
    local topolbuild=${topolbuild:-"$HOME/contrib/topolbuild1_3/bin/topolbuild"}
    local topolbuilddat=${topolbuilddat:-"$HOME/contrib/topolbuild1_3/dat"}

    if [[ "$ff" == "GROMOS"* ]] ; then $ff=`echo $ff | sed -e 's/GROMOS/gmx/g'` ; fi
    if [[ "$ff" != "opls"* && "$ff" != "gmx"* ]] ; then
        warncont "Topology must be one of oplsaa or gmx*"
	return
    fi

    if [ ! "$ext" = "mol2" ] ; then
        warncont "Input file must be a MOL2 file."
        return $ERROR
    fi
    if [ ! -e $mol ] ; then
    	warncont "$mol does not exist"
	return $ERROR
    fi

    if [ -s $lig.mol2 -a ! -e $lig.topolbuild/$lig.itp ] ; then
        notecont "making OPLS-AA topology with $topolbuild"
        mkdir -p $lig.topolbuild
        cp $lig.mol2 $lig.topolbuild
        cd $lig.topolbuild
	# topolbuild needs a SUBSTRUCTURE record
	if ! grep -q '@<TRIPOS>SUBSTRUCTURE' $lig.mol2 ; then
	    # add one
	    echo "@<TRIPOS>SUBSTRUCTURE" >> $lig.mol2
	    # format is
	    # substr_id name root_atom type dict-type chain chain-type interstructure-bonds status [comment]
	    echo "    1  $lig     1 RESIDUE           4 A      NAR     0 ROOT" \
	        >> $lig.mol2
	    # or we could use a minimal representation
            # echo "   1  $lig  1"
	fi
	
	$topolbuild -n $lig -ff $ff -dir $topolbuilddat/gromacs
        # generates
        #	$lig.log
        #	$lig.gro
        #	$ligMOL.mol2
        #	$lig.top
        #	posre$lif.itp
        #	ff$lig.itp
        sed -e "/; Include water topology/,//d" $lig.top > $lig.itp
        cp ff$lig.itp ff$lig.itp.orig
        sed -e "s%ffoplsaanb%oplsaa.ff/ffnonbonded%" \
            -e '/[ defaults ]/,/^ $/d' \
	    ff$lig.itp.orig \
	    > ff$lig.itp
        # update $lig.pdb file
        #	we need to because atom numbering and order have changed in .gro .top
        $editconf -f $lig.gro -o $lig.pdb
        cd -
    else
        echo ""
        notecont "using existing topology for $lig"
        echo ""
    fi
    return $OK
}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash

    make_topolbuild_topology $*
fi
