#!/bin/bash
#
# NAME
#	make_mktop_topology
#
# SYNOPSIS
#	make_mktop_topology ligand.pdb charge
#
# DESCRIPTION
#	Create a topology for a ligand PDB file using mktop.
#	If a mol2 file exists, it will be used to read the charges.
#	Results will be saved in directory $ligand.mktop
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
#	Licensed under (at your option) either GNU/GPL or EUPL
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
MAKE_MKTOP_TOPOLOFY='MAKE_MKTOP_TOPOLOGY'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


function make_mktop_topology {
    #if [ $# -ne 1 ] ; then errexit "mol" 
    #else notecont $* ; fi
    if ! funusage $# mol ; then return $ERROR ; fi
    notecont $*
    
    local mol=$1
    
    local dir=`dirname $mol`
    local fin="${mol##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    
    local babel=${babel:-`which babel`}
    local mktop=${mktop:-`which mktop_2.2.1.pl`}

    if [ ! "$ext" = "pdb" ] ; then
        warncont "Input file must be a PDB file."
        return $ERROR
    fi
    if [ ! -e $mol ] ; then
    	warncont "$mol does not exist"
	return $ERROR
    fi
    
    if [ ! -e $lig.mktop/$lig.opls.itp -a -x "$mktop" ] ; then
        echo ""
        notecont "making AMBER and OPLS topologies for $lig using mktop"
        echo ""
        mkdir -p $lig.mktop
        cp $lig.pdb $lig.mktop
        if [ ! -s $lig.mol2 ] ; then
            echo ""
            warncont "no $lig.mol2 file exists"
            warncont "	a charge of 0 will be used for all atoms!"
            echo ""
            #touch $lig.mktop/$lig.mol2
	    $babel -ipdb $lig.pdb -omol2 $lig.mktop/$lig.mol2
        else
            cp $lig.mol2 $lig.mktop
        fi
        cd $lig.mktop
        # create charges file from mol2
        #	ectract ATOM section and output the corresponding fields
        #	NOTE:
        #	ATOMS IN THE MOL2 FILE MUST CORRESPOND NUMERICALLY WITH
        #	THE ATOMS IN THE PDB FILE!
        sed -n '/@<TRIPOS>ATOM/,/@<TRIPOS>/{/@<TRIPOS>ATOM/d; /@<TRIPOS>/d;p}' \
        	$lig.mol2 | \
                while read num atom x y z atyp resno res chg ; do 
                    echo "$num $chg" 
                done > $lig.charges
        # MAKE AMBER TOPOLOGY
	$mktop -i $lig.pdb -c $lig.charges -ff amber -o $lig.amber.top -conect yes
        if [ ! -s $lig.mktop/$lig.amber.top ] ; then
            # something went wrong. Just in case, sometimes there may
            # be missing CONECT records for one or more atoms (go figure)
            $mktop -i $lig.pdb -c $lig.charges -ff amber -o $lig.amber.top -conect no
	fi
        if [ -s $lig.amber.top ] ; then
            sed -e '/\[ system \]/,//d' $lig.amber.top > $lig.amber.itp
        fi
	
	# MAKE OPLS-AA TOPOLOGY
	$mktop -i $lig.pdb -c $lig.charges -ff opls -o $lig.opls.top -conect yes
        if [ ! -s $lig.mktop/$lig.opls.top ] ; then
            # something went wrong. Just in case, sometimes there may
            # be missing CONECT records for one or more atoms (go figure)
            $mktop -i $lig.pdb -c $lig.charges -ff opls -o $lig.opls.top -conect no
	fi
        if [ -s $lig.opls.top ] ; then
            sed -e '/\[ system \]/,//d' $lig.opls.top > $lig.opls.itp
        fi
        cd -
    fi

    return 0
}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash

    make_mktop_topology $*
fi
