#!/bin/bash
#
# NAME
#	gmx_xtc_remove_solvent - Remove solvent from an XTC trajectory
#
# SYNOPSIS
#	gmx_xtc_remove_solvent [name]
#
# DESCRIPTION
#	Remove solvent from an XTC trajectory (the corresponding TPR must
# exist. If a derived trajectory without PBC exist, it is preferred to
# generate the ${name}_complex.* files If no NDX file exists, one is made.
# This will generate all _complex.* files, including init and last GRO
# structrures.
#
#
# ARGUMENTS
#	name	- the trajectory name without extension or ending in xtc or trr
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


GMX_XTC_REMOVE_SOLVENT="GMX_XTC_REMOVE_SOLVENT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_trr_to_xtc.bash
include gmx_xtc_struct_at.bash


function gmx_xtc_remove_solvent() {
    if ! funusage $# [trajectory] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
	local trj=""

    local ext=${md##*.}
    local name=${md%.*}
    if [ "$name" = "$ext" ] ; then ext='' ; fi
    if [ "$ext" = "xtc" -o "$ext" = "trr" ] ; then
	trj="$md"
    elif [ -s "$name".xtc ] ; then
	    trj="$name".xtc
            ext=xtc
    elif [ -s "$name".trr ] ; then 
	    trj="$name.trr"
            ext=trr
    else
        warncont "$md does not look like a trajectory"
	return 1
    fi

    if [ ! -s "${trj}" ] ; then warncont "No ${trj} found" ; return 1 ; fi
    if [ ! -e "${name}.tpr" ] ; then warncont "No ${name}.tpr" ; return 2 ; fi
    if [ ! -e "${name}.ndx" ] ; then 
        notecont "Creating index for $trj ($name.ndx)"
        echo q | $make_ndx  -f "${name}.tpr" -o "${name}.ndx" ; 
    fi

    if [ ! -s "${name}_complex.xtc" ] ; then
	# Remove solvent
	notecont "Removing solvent:"
	# prepare selection
	if grep -q "^\[ Solute \]" "$name.ndx" ; then
            # first check if there is a Solute group
	    selection='"Solute"'
	elif grep -q "^\[ SOL_ION \]" "$name.ndx" ; then
	    # or maybe it was solvent+ions
 	    selection='!"SOL_ION"'
	elif grep -q "^\[ Water_and_ions \]" "$name.ndx" ; then
	    # try water+ions
	    selection='!"Water_and_ions"'
	elif grep -q "^\[ Solvent \]" "$name.ndx" ; then
	    # if there is no solute defined, check if there is a SOLVENT group
	    selection='!"Solvent"'
	elif grep -q "^\[ SOL \]" "$name.ndx" ; then
	    # or maybe it is only solvent
 	    selection='!"SOL"'
	elif grep -q "^\[ Water \]" "$name.ndx" ; then
	    # maybe there is only water and no ions
	    selection='!"Water"'
	else
	    # nothing to remove that we know of (maybe it was in vacuo)
	    selection=""
	fi
# We would need an array to be able to combine the elements afterwards
# so that if the number of elements is more than one, we combine them
# with ' | '
#           if grep "^\[ Protein \]" md.ndx ; then 
#           	selection="${selection}"Protein""
#           fi
#           if grep -e "^\[ RNA\]" ; then
#               selection="${selection}RNA\n"
#           fi
#           if grep -e "^\[ DNA\]" ; then
#               selection="${selection}DNA\n"
#           fi
#           if grep -e "^[ LIG \]" ; then
#               selection="${selection}LIG\n"
#           fi
        local n=`grep -c "^\[" "${name}.ndx"`	# get number of groups
        # since groups are zero-offset this will be the no. of the new
        # group
        notecont ">>> selection = $selection ($n)"
        if [ "$selection" != "" ] ; then
	    # add group Complex to to NDX file so we can use it
	    if ! grep -q '^\[ Complex \]' "$name.ndx" ; then
	        notecont ">>> Fixing NDX file $trj.ndx"
	        echo -e "$selection\nname $n Complex\nq" \
	        | $make_ndx -f "$name.tpr" -n "$name.ndx" -o "$name.ndx"
	    fi
	    # fix selection for subsequent use (remove ")
            #selection=`echo "$selection" | tr -d '"'`
	    notecont ">>> Extracting $selection from $trj.xtc"
            if [ ! -e "${md}_complex.xtc" ] ; then
	        # create trajectory without solvent
                $trjconv -f "${trj}" \
                        -s "$name.tpr" \
	                -n "$name.ndx" \
        	        -o "${name}_complex.xtc" \
		    < <( echo -e "Complex\n" )
	    fi
	    # create topology TPR file without solvent
            ## NOTE: tpbconv seems to be deprecated,
            ## we use instead 'gmx convert-tpr'
	    if [ ! -e "${name}_complex.tpr" ] ; then
                $tpbconv -s "$name.tpr" \
        		-n "$name.ndx" \
		        -o "${name}_complex.tpr" \
				< <( echo -e "Complex\n" )
	    fi
    	else
            echo ">>> nothing to remove!"
	    # likely a simulation in vacuo, no need to waste space
            #ln -s $md.xtc ${md}_complex.xtc
            # prefer to work without PBC
            ln -s "$trj" "${name}_complex.$ext"
            ln -s "$name.tpr" "${name}_complex.tpr"
            ln -s "$name.ndx" "${name}_complex.ndx"
	    if [ -s "${name}_init.gro" ] ; then
		ln "${name}_init.gro" "${name}_complex_init.gro"
	    fi
	    if [ -s "${name}_init.pdb" ] ; then
		ln "${name}_init.pdb" "${name}_complex_init.pdb"
	    fi
	    if [ -s "${name}_last.gro" ] ; then
		ln "${name}_last.gro" "${name}_complex_last.gro"
	    fi
	    if [ -s "${name}_last.pdb" ] ; then
		ln "${name}_last.pdb" "${name}_complex_last.pdb"
	    fi
    	fi
    fi
	
    # save initial and last configurations
    if [ ! -e "${name}_complex_init.gro" ] ; then
    	# dump initial (first, number 0) frame from the trajectory
        gmx_xtc_struct_at  "${name}_complex" 0
    fi
    if [ ! -e "${name}_complex_last.gro" ] ; then
    	# dump last frame from the trajectory
        gmx_xtc_struct_at "${name}_complex" -1
    fi
    if [ ! -e "${name}_complex.ndx" ] ; then
        symlink "${name}_complex_last.pdb" "${name}_complex.pdb"
        gmx_make_ext_index "${name}_complex.pdb"
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
    include gmx_xtc_struct_at.bash

    gmx_xtc_remove_solvent $*
else
    export GMX_XTC_REMOVE_SOLVENT
fi
