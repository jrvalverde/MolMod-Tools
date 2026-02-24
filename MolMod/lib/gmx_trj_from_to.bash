#!/bin/bash
#
# NAME
#	gmx_trj_from_to - extract part of a trajectory between two times
#
# SYNOPSIS
#	gmx_trj_from_to [trj_name] [from_ps] [to_ps] [subset]
#
# DESCRIPTION
#	Extract part of a trajectory between a specified start time in
# picoseconds and a given end time in picoseconds. It can optionally
# select only part of the simulation system for output specified as a
# subset as described in the index file.
#
#	It expects that the trajectory name (if specified) has not extension.
# If no name is specified, 'md' will be used. It will first look for an XTC
# trajectory, if none is found, a TRR trajectory, named as $trj_name.{xtrc|trr}.
# There should be an accompanying run input file named $trj_name.tpr.
# If an accompanying index file $trj_name.ndx is found, it
# will also be used, otherwise it will use the default index.
#
#	The start and end times may be specified as time in picoseconds. Their
# default values are 0 and 1000 respectively. Frames between these times will
# be selected for output.
#
#	An optional subset can also be specified to output only part of the
# simulation system. It must correspond to a valid subset in the index.
#
# ARGUMENTS
#	trj_name	- the trajectory name without extension, optional,
#			defaults to 'md'
#	from		- the starting time in picoseconds, optional, 
#			defaults to 0
#	to		- the end time in picoseconds, optional, defaults 
#			to 1000
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

GMX_TRJ_FROM_TO="GMX_TRJ_FROM_TO"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include util_funcs.bash

function gmx_trj_from_to() {
    if ! funusage $# [trajectory] [from_ps] [to_ps] [subset] ; then return $ERROR ; fi 
    notecont "$*"
    
    local trj_name="${1:-md}"
    local from=${2:-0}		# start timme in ps
    local to=${3:-1000}		# end time in ps
    local subset="${4:-System}"

    local trj=''
    local tpr=''
    local index=''
    local ext=''
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
        tpr=$"{trj_name}".tpr
    else
        warncont "no ${trj_name}.tpr"
        return $(( ERR++ ))
    fi
    
    
    if [ -s "${trj_name}".ndx ] ; then
        index="-n '${trj_name}ndx'"
    else
        index=''
    fi
    
    if [ $from -gt $to ] ; then
        warncont "$from greater than $to"
        return $(( ERR++ ))
    fi
    if [ $from -eq $to ] ; then
        ext=gro		# we only want a single frame, output structure file
    else
        ext="xtc"
    fi

    if [ "$subset" = "System" ] ; then
        out="${trj_name}_${from}-${to}.${ext}"
    else
        out="${trj_name}_${subset}_${from}-${to}.${ext}"
    fi
    
    if [ -s "$out" ] ; then
        warncont "$out already exists"
        return $(( ERR++ ))
    fi
    

    echo "$subset" \
    | gmx trjconv \
        -f $trj \
        -s $tpr \
        -b $from \
        -e $to \
        -o "$out" \
        $index

    # Call the program with gmx
    # Select the trjconv command
    # Select the -f flag and provide the starting trajectory in the 
    #    preferred format (system.xtc)
    # Choose the -s flag and enter the .tpr file (system.tpr)
    # The -b flag signals the starting frame for the new trajectory (0 ps)
    # The -e flag tells the program the final frame (100 ps)
    # Call the -o flag and decide the name of the output file 

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

    gmx_trj_from_to $*
else
    export GMX_TRJ_FROM_TO
fi
