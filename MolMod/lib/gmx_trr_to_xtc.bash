#!/bin/bash
#
# NAME
#    gmx_trr_to_xtc - convert trr trajectory to xtc (and optionally subselect)
#
# SYNOPSIS
#    gmx_trr_to_xtc [trajectory] [step_ps] [subset]
#
# DESCRIPTION
#	Convert a GROMACS trajectory from TRR format to XTC format. The
# name of the trajectory (without extension) must be provided. If no
# name is provided, then the default "md" will be used. It can
# optionally subsample the trajectory taking one frame each $step_ps
# picoseconds. If no 'step_ps' is given or it is an empty value ('') or iff 0 
# is specified, then all frames will be output. It can also optionally
# export only part of the simulation system if subset is specified with
# the name or number of the desired subset in the corresponding (or the
# default) index.
#
# ARGUMENTS
#	trajectory	- the trajectory name (without extension), optional,
#			defaults to 'md'
#	step_ps		- a time in ps to use for subsampling, optional,
#			defaults to 0 (i.e. output all frames)
#	subset		- the part of the system (as specified in the index
#			file) to select for output, defaults to 'System'
#			(i.e. output the whole simulation system)
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

GMX_TRR_TO_XTC="GMX_TRR_TO_XTC"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function gmx_trr_to_xtc() {
    if ! funusage $# [trajectory] [step_ps] [subset] ; then return $ERROR ; fi 
    notecont "$*"

    local trj_name="${1:-md}"
    local step_ps=${2:-0}		# save frames every $step_ps picoseconds
    local subset="${3:-System}"		# subset of the system to save (default all)

    local trr=''
    local tpr=''
    local index=''
    local out=''
    local ERR=1
    
    if [ -s "${trj_name}".trr ] ; then
        trr="${trj_name}".trr
    else
        warncont "${trj_name}.trr does not exist"
        return $(( ERR++ ))
    fi

    if [ -s "${trj_name}".tpr ] ; then
        tpr="${trj_name}".tpr
    else
        warncont "no ${trj_name}.tpr"
        return $(( ERR++ ))
    fi
    
    if [ -s "${trj_name}_${subset}".xtc ] ; then
        warncont "${trj_name}_${subset}.xtc already exists, not converting"
        return $(( ERR++ ))
    else
        out="${trj_name}_${subset}".xtc
    fi
    
    if [ -s "${trj_name}".ndx ] ; then
        index="-n ${trj_name}.ndx"
    else
        index=''
    fi

    if [ "$step_ps" -eq 0 ] ; then
        $step='' 
        out="${trj_name}".xtc
    else
        $step="-d $step_ps"
        if [ "$subset" = "System" ] ; then
            out="${trj_name}_each_${step_ps}ps".xtc
        else
            out="${trj_name}_${subset}_every_${step_ps}ps".xtc
        fi
    fi

    if [ -s "$out" ] ; then
        warncont "$out already exists"
        return $(( ERR++ ))
    fi
    
    echo "$subset" \
    | gmx trjconv \
        -f $trr \
        -s $tpr \
        -o $out \
        $step \
        $index

    # Call the program with gmx
    # Select the trjconv command
    # Select the -f flag and provide the starting trajectory in the trr format
    # Choose the -s flag and enter the .tpr file
    # Call the -o flag and decide how you want to name the resulting trajectory
    #     file in the xtc format (system.xtc)
    # You can also use the -dt flag to reduce the number of frames in the
    #     output as already explained.
    # Also in this case, you may be interested in including an index file you
    #    previously created (index.ndx) via the -n flag.

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

    gmx_trr_to_xtc $*
else
    export GMX_TRR_TO_XTC
fi
