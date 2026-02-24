#!/bin/bash
#
# NAME
#	gmx_xtc_fix_pbc - fix periodic boundary conditions of an XTC trajectory
#
# SYNOPSIS
#	gmx_xtc_fix_pbc [name]
#
# DESCRIPTION
#	fix periodic boundary conditions of an XTC trajectory (with 
# corresponding TPR and NDX files
#
# ARGUMENTS
#	name	- XTC trajectory name (without .xtc extension)
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


GMX_XTC_FIX_PBC="GMX_XTC_FIX_PBC"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include fs_funcs.bash
include util_funcs.bash
include gmx_setup_cmds.bash


function gmx_xtc_fix_pbc() {
    if ! funusage $# [name] [method] [center] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
    local method=${2:-mol}
    local center=${3:-Protein}
    local trj=""
	
    name="${md%.*}"
    ext="${md##*.}"
    if [ "$ext" = "xtc" -o "$ext" = "trr" ] ; then
        trj="$md"
    elif [ -s "$name".xtc ] ; then
        trj="$name".xtc
    elif [ -s "$name".trr ] ; then 
        trj="$name.trr"
    else
        warncont "$md does not look like a trajectory"
        return 1
    fi

    boldblue "Correcting trajectory $trj for PBC"
    if [ ! -s "${trj}" ] ; then warncont "no $trj" ; return 1 ; fi
    if [ ! -e "$name.tpr" ] ; then warncont "no $name.tpr" ; return 2 ; fi
    if [ ! -e ${name}_${method}.xtc ] ; then
        # center on Protein and save System
        echo -e "$center\nSystem\n\n" \
	| $trjconv \
		   -s "$name.tpr" \
		   -f "$trj" \
        	   -o "${name}_${method}.xtc" \
		   -center \
		   -pbc ${method} \
		   -ur compact
        cp "$name.tpr" "${name}_${method}.tpr"
        cp "$name.top" "${name}_${method}.top"
        cp "$name.ndx" "${name}_${method}.ndx"
        symlink "${name}_${method}.xtc" "${name}_PBC.xtc"
        symlink "${name}.tpr" "${name}_PBC.tpr"
        symlink "${name}.top" "${name}_PBC.top"
        symlink "${name}.ndx" "${name}_PBC.ndx"
        # get first and last structures
        gmx_xtc_struct_at "${name}_PBC" 0
        gmx_xtc_struct_at "${name}_PBC" -1
    fi
    # make a (1/10) sparse trajectory for quick visualization
    if [ ! -e ${name}_${method}_sparse.xtc ] ; then
        echo "System" | $trjcat \
				-f "${name}_${method}.xtc" \
				-o "${name}_${method}_sparse.xtc" \
	    		-dt 10
        cp "$name.tpr" "${name}_${method}_sparse.tpr"
        cp "$name.top" "${name}_${method}_sparse.top"
        cp "$name.ndx" "${name}_${method}_sparse.ndx"
    fi

    return 0
    
    # these should be removed eventually
    if [ ! -e ${name}_PBC.xtc ] ; then
        echo -e "$center\nSystem\n\n" \
	| $trjconv \
		   -s "$name.tpr" \
		   -f "$trj" \
        	   -o "${name}_PBC.xtc" \
		   -center \
		   -pbc mol \
		   -ur compact
        cp "$name.tpr" "${name}_PBC.tpr"
        cp "$name.top" "${name}_PBC.top"
        cp "$name.ndx" "${name}_PBC.ndx"
    fi
	
    # make another version with no jumps to compare
    if [ ! -e ${name}_nojump.xtc ] ; then
        echo -e "$center\nSystem\n\n" | $trjconv \
		        -s "$name.tpr" \
			-f "$trj" \
        		-o "${name}_noJump.xtc" \
			-center \
			-pbc nojump \
			-ur compact
        cp "$name.tpr" "${name}_noJump.tpr"
        cp "$name.top" "${name}_noJump.top"
        cp "$name.ndx" "${name}_noJump.ndx"
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

    gmx_xtc_fix_pbc $*
else
    export GMX_XTC_FIX_PBC
fi
