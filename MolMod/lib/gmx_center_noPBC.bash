#!/bin/bash
#
# NAME
#	gmx_center_noPBC - remove PBC and center part of a structure
#
# SYNOPSIS
#	gmx_center_noPBC [struct] [center] [subset]
#
# DESCRIPTION
#	Take an structure (GRO, PDB, XTC, TRR) and center around a
# simulation group, optionally saving only part of the simulation system.
#
#	'struct' must be a structure file name with extension or not. The name
# will be used to search for a suitable tructure, in order of priority,
# ending in .gro .pdb .xtc or .trr it it lacks a valid extension or it is
# not directly found.
#
#	There should be a run input file named $struct.tpr,
# If an accompanying index file $trj_name.ndx is found, it will also be 
# used, otherwise it will use the default index.
#
#	If a center group is not specified, 'System' will be used and only
# PBC removal will take place, otherwise, the center group (which must be
# defined in the index) will be used to center the system around it.
#
#	An optional subset can also be specified to output only part of the
# simulation system. It must correspond to a valid subset in the index.
#
# ARGUMENTS
#	structure	- the name (without extension) of the structure,
#			optional, defaults to 'system'
#	center		- optional, the name of a valid group in the index
#			to center around
#	subset		- optional, the name of a valid group in the index
#			to select for output
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

GMX_CENTER_NOPBC="GMX_CENTER_NOPBC"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#echo $LIB
source $LIB/include.bash
include util_funcs.bash
VERBOSE=1

function gmx_center_noPBC() {
    if ! funusage $# [structure] [center] [subset] ; then return $ERROR ; fi 
    notecont "$*"
    
    local name=${1:-system}
    local center=${2:-Protein}		# group to center
    local subset=${3:-System}		# group to output

    local struct=''
    local ext=''
    local tpr=''
    local index=''
    local out=''
    local ERR=1

    ext=${name##*.}			# remove all until the last dot
    if [[ " gro pdb xtc trr g96 tng " == *" $ext "* ]] ; then
        # it is a valid extension, check if the file exsist
        if [ -s "$name" ] ; then
            struct="$name"
	    name=${name%.*}	# strip extension from name for output 
	    ext=xtc		# for output
        fi
        # note that the following logic may work for 
        # "*.{gro|pdb|xtc|trr}.{gro|pdb|xtc|trr}
        # which is an anomaly
        # may be we should return here?
    fi
    if [ $struct = "" ] ; then
        # check $name with various extensions
        if [ -s "${name}".gro ] ; then
            struct="${name}".gro
            ext="gro"
        elif [ -s "${name}".pdb ] ; then
            struct="${name}".pdb
            ext="pdb"
        elif [ -s "${name}".xtc ] ; then
            struct="${name}".xtc
            ext="xtc"
        elif [ -s "${name}".trr ] ; then
            struct="${name}".trr
            ext="xtc"
        else
            echo "Error: no $name.{gro|pdb|trr|xtc} found"
            return  $(( ERR++ ))	# this returns the current value of $ERR
	    				# (1) and increases it by 1 (setting it
					# to 2) for the next error
        fi
    fi

    if [ -s "${name}".tpr ] ; then
        tpr="${name}".tpr
    else
        echo "Error: no ${trj_name}.tpr"
        return $(( ERR++ ))
    fi

    if [ -s "${name}".ndx ] ; then
        index="-n ${name}.ndx"
    else
        index=''
    fi

    if [ "$subset" = "System" ] ; then
        out="${name}_center_${center}_noPBC.$ext"
    else
        out="${name}_${subset}_center_${center}_noPBC.$ext"
    fi
    
    if [ -s "$out" ] ; then
        warncont "$out already exists"
	return $(( ERR++ ))
    fi

    if [ "$center" = "ask" ] ; then
        selcenter='echo -'
    else
        selcenter="echo $center"
    fi
    if [ "$subset" = "ask" ] ; then
        selsubset=''
    else
        selsubset="echo $subset"
    fi
    
    (echo "$center" ; echo "$subset") \
    | gmx trjconv \
        -f $struct \
        -s $tpr \
        -pbc mol \
        -center \
        -ur compact \
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

    gmx_center_noPBC $*
else
    export GMX_CENTER_NOPBC
fi
