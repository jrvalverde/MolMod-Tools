#!/bin/bash
# NAME
#	gmx_trj_fame - extract a frame from a trajectory
#
# SYNOPSIS
#	gmx_trj_frame [trj_name] [time_ps] [subset]
#
# DESCRIPTION
#	Extract the frame closest to the specified time from a trajectory.
# The time must be comprised in the trajectory or be -1 to specify the last
# frame (may be very slow) and is indicated in picoseconds. Optionally a
# subset of the system may be specified as well.
#
# ARGUMENTS
#	trj_name	- the name of the trajectory without extension
#			defaults to 'md'
#	time_ps		- the time in ps at which we want to get a frame
#			defaults to 0 (first frame), -1 means last frame
#	subset		- an optional subset of the coordinates to retrieve
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


GMX_TRJ_FRAME="GMX_TRJ_FRAME"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function gmx_trj_frame() {
    if ! funusage $# [trj_name] [time_ps] [subset] ; then return $ERROR ; fi 
    notecont "$*"

    local md=${1:-md}
    local ps=${2:-0}	# default to first frame (0ps)
    local subset=${3:-System}

    local l
    local frame
    local t
    local trr
    local tpr
    local out

    if [ -s "${md}".xtc ] ; then
        trj="${md}".xtc
    elif [ -s "${md}".trr ] ; then
        trj="${md}".trr
    else
        warncont "${md}.xtc/trr does not exist"
        return $(( ERR++ ))
    fi
    
    if [ "$ps" = '-1' -o "$ps" = "last" ] ; then
        # find last frame
	# we need first to identify it, this may potentially take very long
	read l frame t ps <<< `gmx check -f "$trj" |& grep Last \
	| sed -e 's/.*time //g'`
    echo "[$t] [$ps]"
    fi
    
    if [ -s "${md}.tpr" ] ; then
        tpr="${md}".tpr
    else
        warncont "no ${md}.tpr"
        return $(( ERR++ ))
    fi

    if [ -s "${trj_name}".ndx ] ; then
        index="-n '${md}.ndx'"
    else
        index=''
    fi
    
    out="$md"
    if [ "$subset" != "System" ] ; then
        out="${out}_$subset"
    fi
    out="${out}.$ps"
    
    if [ -s "$out.gro" ] ; then
        notecont "$out.gro already exists, not saving"
    else
	# save desired frame (0 is the first frame)
	echo System | gmx trjconv -f ${trj} -s ${tpr} $index \
	     -o "${out}.gro" \
             -dump $ps -pbc mol
    fi
    if [ -s "$out.pdb" ] ; then
        notecont "$out.pdb already exists, not saving"
    else
	echo System | gmx trjconv -f ${trj} -s ${tpr} $index \
	     -o ${out}.pdb \
             -dump $ps -pbc mol -conect
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

    gmx_trj_frame $*
else
    export GMX_TRJ_FRAME
fi
