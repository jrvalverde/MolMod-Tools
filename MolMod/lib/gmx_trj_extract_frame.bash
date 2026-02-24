#!/bin/bash
#
# NAME
#	gmx_trj_extract_frame - extract a frame from a trajectory at a given time
#
# SYNOPSIS
#	gmx_trj_extract_frame [trj_name] [time_ps] [subset]
#
# DESCRIPTION
#
#	Extract the frame closest to a given time from a trajectory
#
#	It expects that the trajectory name (if specified) has not extension.
# If no name is specified, 'md' will be used. It will first look for an XTC
# trajectory, if none is found, a TRR trajectory, named as $trj_name.{xtrc|trr}.
# There should be an accompanying run input file named $trj_name.tpr.
# If an accompanying index file $trj_name.ndx is found, it
# will also be used, otherwise it will use the default index.
#
#	The time may be specified as time in picoseconds. Its default
# is 0, meaning the first frame. The closest frame to the specified time
# will be output. It must be a valid time within the trajectory span. You
# can find valid times with 'gmx check' or 'gmx dump'.
#
#	An optional subset can also be specified to output only part of the
# simulation system. It must correspond to a valid subset in the index.
#
# ARGUMENTS
#	trj_name	- the trajectory name without extension, optional,
#			defaults to 'md'
#	time_ps		- the closest time in picoseconds to the frame, optional, 
#			defaults to 0 (i.e. start frame)
#	subset		- the part of the simulation system to select for
#			output, optional, defaults to 'System' (i.e. all)
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


GMX_TRJ_EXTRACT_FRAME="GMX_TRJ_EXTRACT_FRAME"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include util_funcs.bash

function gmx_trj_extract_frame() {
    if ! funusage $# [trajectory] [time_ps] [subset] ; then return $ERROR ; fi 
    notecont "$*"

    local trj_name="${1:-md}"
    local time_ps=${2:-0}
    local subset="${3:-System}"

    local trj=''
    local tpr=''
    local index=''
    local out=''
    local ERR=1
    
    if [ -s "${trj_name}".xtc ] ; then
        trj="${trj_name}".xtc
    elif [ -s "${trj_name}".trr ] ; then
        trj="${trj_name}".trr
    else
        warncont "${trj_name}.xtc/trr does not exist"
        return $(( ERR++ ))
    fi


    if [ -s "${trj_name}".tpr ] ; then
        tpr="${trj_name}".tpr
    else
        warncont "no ${trj_name}.tpr"
        return $(( ERR++ ))
    fi
    
    if [ -s "${trj_name}"_${subset}_${time_ps}ps.gro ] ; then
        warncont "$trj_name.gro already exists"
        return $(( ERR++ ))
    fi
    
    
    if [ -s "${trj_name}".ndx ] ; then
        index="-n '${trj_name}.ndx'"
    else
        index=''
    fi
    
    if [ "$subset" = "System" ] ; then
        out="${trj_name}_at_${time_ps}ps.gro"
    else
        out="${trj_name}_${subset}_at_${time_ps}ps.gro"
    fi

    if [ -s "$out" ] ; then
        warncont "$out already exists"
        return $(( ERR++ ))
    fi
    
    echo "$subset" \
    | gmx trjconv \
        -f "$trj" \
        -s "$tpr" \
        -dump $time_ps \
        -o "$out" \
        $index


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

    gmx_trj_extract_frame $*
else
    export GMX_TRJ_EXTRACT_FRAME
fi
