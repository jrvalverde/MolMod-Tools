#!/bin/bash
#
#
# NAME
#	make_acpype_topology
#
# SYNOPSIS
#	make_acpype_topology ligand.pdb charge
#
# DESCRIPTION
#	Create a topology for a ligand PDB file using acpype.
#	If a mol2 file exists, it will be used to read the charges.
#	Results will be saved in directory $ligand.acpype
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
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
MAKE_ACEPYPE_TOPOLOGY='MAKE_ACEPYPE_TOPOLOGY'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


function make_acpype_topology {
    #if [ $# -ne 2 ] ; then errexit "mol charge" 
    #else notecont $* ; fi
    if ! funusage $# mol charge ; then return $ERROR ; fi
    notecont $*
    
    local mol=$1
    local charge=$2
    
    local dir=`dirname $mol`
    local fin="${mol##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    
    local acpype=${acpype:-`which acpype`}
    local babel=${babel:-`which babel`}
    
    if [ "$ext" != "pdb" -a "$ext" != "mol2" -a "$ext" != "mdl" ] ; then
        warncont "Input file should be a PDB file."
        return $ERROR
    fi
    if [ ! -e $mol ] ; then
    	warncont "$mol does not exist"
	return $ERROR
    fi
    
    # do not repeat if already done
    if [ -s $lig.acpype/${lig}_AC.prmtop ] ; then
    	echo "make_acpype_topology: Using existing topology in $lig.acpype"
        return $OK
    fi

    # 	compute multiplicity
    # HEURISTIC: assume all charges are due to e- that yield unpaired spin
    #	ignore minus sign (i.e. take absolute value)
    local mult=$(( ${charge#-} + 1 ))
    notecont "make_acpype_topology: $lig $charge $mult"

    export LD_LIBRARY_PATH=`dirname $acpype`/lib:$LD_LIBRARY_PATH

    # 	If a MOL2 file is available, assume it has charges and use them
    if [ -s $lig.mol2 ] ; then
        notecont "Generating parameters using $lig.mol2"
	#cp NAR.mol2 NAR_user_amber.mol2
        LD_LIBRARY_PATH=`dirname $acpype` \
	$acpype --input $lig.mol2 --basename $lig \
	    --net_charge $charge --multiplicity $mult --charge_method 'user' \
	    --atom_type amber \
	    --gmx45 --sorted
    fi
    if [ -s $lig.acpype/${lig}_AC.prmtop ] ; then
        return $OK
    fi

    #
    # the user didn't supply a mol2 file or we couldn't use the one available.
    # compute charges using SQM from Antechamber
    notecont "could not use charges from mol2 file, trying SQM"
    $acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a amber -c bcc
    if [ -s $lig.acpype/${lig}_AC.prmtop ] ; then
        return $OK
    fi
    
    # if SQM failed, then resort to using babel to compute charges
    # iterating over known babel methods and re-run acpype
    if [ -x "$babel" ] ; then
        notecont "COULD NOT USE SQM CHARGES."
        # try successively with each of babel -L charges methods
	for i in qtpie qeq eem mmff94 gasteiger ; do
            notecont "assigning charges using babel $i"
            $babel -ipdb $lig.pdb --partialcharge $i -omol2 $lig.$i.mol2
            $acpype -i $lig.$i.mol2 -n $charge -m $mult -b $lig -r -l -a amber -c user
            if [ -s $lig.acpype/${lig}_AC.prmtop ] ; then
                return $OK
            fi
        done
    fi
        
    # if Babel charges failed, then try to use Antechamber Gasteiger charges
    notecont "COULD NOT USE BABEL. USING GASTEIGER CHARGES"
    $acpype -i $lig.$ext -n $charge -m $mult -b $lig -r -l -a amber -c gas
    if [ -s $lig.acpype/${lig}_AC.prmtop ] ; then
        return $OK
    fi
    
    # if everything failed, tell the user
    if [ ! -s $lig.acpype/${lig}_AC.prmtop ] ; then
	notecont "COULD NOT GENERATE ACPYPE TOPOLOGIES FOR $lig $charge $mult"
        return $ERROR
    fi
    
    # ligand topologies are in $lig.acpype/$lig_GMX*.itp and $lig.oplsaa.itp
    return $OK
}


#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash

    make_acpype_topology $*
fi
