#!/bin/bash
#
#	Utility functions
#
#
# AUTHOR(S)
#	'banner' is based on the bash/ksh93 version of 'banner' by jlliagre
#		Apr 15 '12 at 11:52
#		http://stackoverflow.com/questions/652517/whats-the-deal-with-the-banner-command
#
#	All other code is
#		(C) Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#	and
#		Licensed under (at your option) either GNU/GPL or EUPL
#
# LICENSE:
#
#	Copyright 2014 JOSE R VALVERDE, CNB/CSIC.
#
#	EUPL
#
#       Licensed under the EUPL, Version 1.1 or \u2013 as soon they
#       will be approved by the European Commission - subsequent
#       versions of the EUPL (the "Licence");
#       You may not use this work except in compliance with the
#       Licence.
#       You may obtain a copy of the Licence at:
#
#       http://ec.europa.eu/idabc/eupl
#
#       Unless required by applicable law or agreed to in
#       writing, software distributed under the Licence is
#       distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#       express or implied.
#       See the Licence for the specific language governing
#       permissions and limitations under the Licence.
#
#	GNU/GPL
#
#       This program is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 3 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# NAME
#	make_ligand_topologies
#
# SYNOPSIS
#	make_ligand_topologies ligand.pdb charge
#
# DESCRIPTION
#	Create a topology for a ligand PDB file using various methods.
#
#	By default we assume a charge of 0 if not specified.
#
#	Ligand topologies will be built using topolgen (for OPLS/AA),
#	topolbuild (OPLS-AA), mktop (AMBER and OPLS-AA) and 
#	acpype (for all other force fields, plus a temptative OPLS/AA topology).
#
#	If a ligand.mol2 file already exists, in addition to the PDB file,
#	it will be assumed to contain the atomic point charges, and use
#	to build the topology.
#
#	If a ligand.mol2 file does not already exist, or building the
#	topology with the provided one fails, then it will attempt to
#	crate one using UCSF Chimera and AM1-BCC to compute charges.
#
#	If a ligand.mol2 file does not exist, and Chimera failed to build
#	one, then we will first try to compute charges using Semi-empirical
#	Quantum Mechanics implementation in Antechamber (sqm)
#
#	if that also fails, we will try other models using babel to
#	generate a new mol2 file to use as template. The various methods
#	available in babel will be tried in the following hardcoded order
#
#		QTPIE QEq EEM MMFF94 Gasteiger
#
#	If even that fails, we will resort to using less accurate Gasteiger
#	charges using Antechamber.
#
#	If that also fails, then we give up.
#
#	Output files are:
#		lig.oplsaa.itp	- OPLS/AA tology built by topolgen, with
#			charges corrected by .mol2 if it exists.
#		lig.acpype/*	- toplogies for a variety of force fields
#			and systems built by acpype, with charges corrected
#			according to the fallback protocol described above.
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
function make_ligand_topologies {
    # Take a ligand PDB file (or optionally an existing ligand.mol2 file)
    # and generate a topology using ACPYPE assuming the specified charge
    #
    #	The user can request that only a specific topology be generated,
    #   or all, or none at all.
    #
    #	By default, all topologies are generated. Currently, we support
    #	mktop, topolbuild, topolgen and acpype
    #
    
    local pdb=$1
    local charge=${2:-"0"}
    local chargeModel=${3:-default}
    local topol=${4:-"all"}
    
    local chimera=${chimera:-`which chimera`}
    local babel=${babel:-`which babel`}
    local topolgen=${topolgen:-`which topolgen.pl`}
    local topolbuild=${topolbuild:-`which topolbuild`-}
    local openmopac=${openmopac:-'~/contrib/mopac/MOPAC2009'}
    local mktop=${mktop:-`which mktop_2.2.1.pl`}

    echo ""
    echo ">>> make_ligand_topologies: $lig ($charge) using $topology"
    echo ""

    # check arguments
    if [ "$topology" = "none" ] ; then return $OK ; fi

    local dir=`dirname $pdb`
    local fin="${pdb##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    if [ ! "$ext" = "pdb" -a ! "$ext" = "brk" -a ! "$ext" = 'mol2' ] ; then
        echo "make_ligand_topologies ERROR: Input file must be a PDB or mol2 file."
        return $ERROR
    fi
    if [ ! -e $pdb ] ; then
    	echo "make_ligand_topologies ERROR: $pdb does not exist"
	return $ERROR
    fi
    
    pushd `pwd`		# remember our current directory so go can
    cd $dir		# later return to it on end.
    
    # do not repeat calculation if already done
    if [ -s $lig.itp ] ; then 
        echo "make_ligand_topologies: using $lig.itp from previous run"
        return $OK
    fi

    # make sure we have a PDB file named $lig.pdb
    if [ "$ext" = "brk" ] ; then
        cp $lig.$ext $lig.pdb
    elif [ "$ext" = "mol2" -a ! -e $lig.pdb ] ; then
        $babel -imol2 $lig.mol2 -opdb $lig.pdb
    fi

    #
    # First we will try to make a .mol2 file if none was provided
    #
    #	NOTE that $charge is only used by OpenMopac, and that it is
    #	recomputed by Chimera, and hopefully by babel.
    #
    #	NOTE that this will try to generate a number of alternate
    #	.mol2 files in $lig.mmooll22 with various methods and try 
    #	to chose the most accurate one (but you still have the others
    #	in case you prefer to use a different one).
    #
    if [ ! -s $lig.mol2 ] ; then
        pdb2mol2 $lig.pdb $charge $chargeModel
        # this should generate $lig.mol2 and update $lig.pdb to match
    else
        echo "Using existing $lig.mol2 file to assign topology charges"
    fi
    # if we still haven't one, let the user know
    if [ ! -s $lig.mol2 ] ; then
        echo "make_ligand_topologies: no MOL2 file for guiding charges is available"
    fi

    #
    # Second we'll make a number of alternative topologies for the user
    #	to select his/her preferred one,
    #

    # Make a topology using topolbuild
    #	We can only use topolbuild on a mol2 file (which already contains
    #	charges)
    if [ -s $lig.mol2 ] ; then
        make_topolbuild_topology $lig.mol2
    fi
    
    # Make ligand topology using topolgen
    #	We can only use topolgen with a PDB file
    #	But we shall correct charges with a mol2 file (if it exists)
    if [ -s $lig.pdb ] ; then
        make_topolgen_topology $lig.pdb
    fi
    
    # Make a topology using ACPYPE
    if [ -s $lig.pdb ] ; then
        make_acpype_topology $lig.pdb $charge
    fi
    # ligand topologies are in $lig.acpype/$lig_GMX*.itp and $lig.oplsaa.itp

    #
    # Make topologies using mktop
    #	mktop can create both amber and opls-aa topologies
    #	if CONECT records are available in the PDB it can use them
    #
    if [ -s $lig.pdb ] ; then
        make_mktop_topology $lig.pdb
    fi
    
    popd

}


# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    # -v variable is set? -z is zero-length string"
    [[ -v $SETUP_CMDS ]] && source $LIB/setup_cmds.bash
    [[ -z $UTIL_FUNCS ]] && source $LIB/util_funcs.bash
    source $LIB/gromacs_funcs.bash

    VERBOSE=0
    pdb=$1
    charge=${2:-"0"}
    chargeModel=${3:-default}
    topol=${4:-"all"}
    if [ "$UNIT_TEST" == "no" ] ; then
    	make_ligand_topologies $pdb $charge $chargeModel $topol
    else
	    make_ligand_topologies testfile.pdb
    fi
else
    export MAKE_LIGAND_TOPOLOGIES
fi
