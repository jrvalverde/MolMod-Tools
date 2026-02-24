#!/bin/bash
#
# NAME
#	gmx_gro2pdb - desc
#
# SYNOPSIS
#	gmx_gro2pdb [arg] [arg]
#
# DESCRIPTION
#	
#
#
# ARGUMENTS
#	arg	- desc
#
# LICENSE:
#
#	Copyright 2023 JOSE R VALVERDE, CNB/CSIC.
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


GMX_GRO2PDB="GMX_GRO2PDB"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash


function gmx_gro2pdb() {
    if ! funusage $# [str.gro] [subset] [pbc] ; then return $ERROR ; fi 
    notecont "$*"

    local gro="${1:-struct.gro}"
    local subset="${2:-System}"
    local pbc="${3:-whole}"
    
    local gf="$gro"		    # gro file
    local gn="${gf%.*}"		# gro name
    local ge="${gf##*.}"	# gro extension
    local ndx=''		    # index
    
	if [ "$ge" = "" ] ; then
	    gro="$gro".gro
		ge="gro"
	elif [ "$ge" != "gro" ] ; then
	    warncont "$gro is not a GROMACS .gro file"
	    return 1
	fi
	
    if [ ! -s "$gro" ] ; then return 1 ; fi
    if [ -s "$gn.ndx" ] ; then ndx="-n $gn.ndx" ; fi

    if [ "$ge" == "gro" ] ; then
        if [ -s "$gn.tpr" ] ; then
            if [ "$subset" != "System" ] ; then on="${gn}_${subset}" ; else on="$gn" ; fi
            if [ -s "$on.pdb" ] ; then return 0 ; fi	# nothing to be done

			# first we center the selection, then we output it
	        echo -e "$subset\n$subset" \
            | $trjconv -f "$gf" -s "$gn.tpr" -o "$on.pdb" \
                -pbc "${pbc}" -center \
                ${comment# -pbc mol -center } \
                -ur compact -conect $ndx
                # -pbc whole: make broken molecules whole
                # -pbc mol: puts the center of mass of molecules in the box
                #			(may have limited effect in solvated boxes --check)
                # -pbc nojump: checks if atoms jump across the box and then 
                #			puts them back. This has the effect that all 
                #			molecules will remain whole (provided they were 
                #			whole in the initial conformation). Note that this 
                #			ensures a continuous trajectory but molecules may 
                #			diffuse out of the box
                # -pbc res	puts the center of mass of residues in the box.
                #
                # -ur sets the unit cell representation, 'compact' puts all 
                #			atoms at the closest distance from the center 
                #			of the box.
                #
                # -center	centers the system in the box (may have limited
                #			effect on solvated boxes --check)
        else
            # no way we can select a subset as we have no topology
            $editconf -f "$gf" -o "$gn.pdb" -pbc true
        fi
    elif [ "$ge" == "brk" -o "$ge" == "ent" ] ; then
        cp -n "$gf" "$gn".pdb
    else
        echo "gro2pdb: unknown structure format (.$ge)"
    fi

    return 0

}



if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    # [[ -v VAR ]] tests if a variable is set
    # [[ -z "$VAR" ]] tests if length of $VAR is zero
    LIB=`dirname $0`
    source $LIB/include.bash
    include util_funcs.bash
    include gmx_setup_cmds.bash

    gmx_gro2pdb $*
else
    export GMX_GRO2PDB
fi
