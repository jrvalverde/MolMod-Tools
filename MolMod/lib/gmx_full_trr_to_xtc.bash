#!/bin/bash
#
# NAME
#	gmx_full_trr_to_xtc - convert a full TRR trajectory to XTC
#
# SYNOPSIS
#	gmx_extend_trj_ps [name]
#
# DESCRIPTION
#	Convert all frames of a TRR trajectory file to XTC format
#
# ARGUMENTS
#	name		- the trajectory base name (without .trr extension)
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


GMX_EFULL_TRR_TO_XTC="GMX_FULL_TRR_TO_XTC"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include setup_cmds.bash


# convert TRR to XTC file AND save last time in trajectory
function gmx_full_trr_to_xtc {
    md="${1:-md}"
    
    if [ ! -e "${md}.trr" ] ; then return 1 ; fi
    if [ ! -e "${md}.tpr" ] ; then return 2 ; fi
    if [ ! -e "${md}.ndx" ] ; then 
	echo q | $make_ndx  -f "${md}.tpr" -o "${md}.ndx" ; 
    fi
    if [ ! -e "${md}.xtc" ] ; then
        boldblue "Creating XTC file"
        # create a smaller low-res trajectory file
        echo "System" | $trjconv -f "$md.trr" \
		    -o "$md.xtc" \
			-s "$md.tpr" \
			-n "$md.ndx" \
		    -pbc mol 2>&1 \
			| tee "${md}.toxtc.log"
        # AND get last time in trajectory
        cat "${md}.toxtc.log" \
               | grep "Reading frame" \
               | tail -n 1 | sed -e 's/.* time //g' >  "${md}.lastt"
    	# clean up
		rm "${md}.toxtc.log"
		return 0
    fi
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
    include setup_cmds.bash

    gmx_full_trr_to_xtc $*
else
    export GMX_FULL_TRR_TO_XTC
fi
