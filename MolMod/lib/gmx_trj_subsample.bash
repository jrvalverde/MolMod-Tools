#!/bin/bash
#
# NAME
#	gmx_trj_subsample - subsample a gromacs trajectory to extract
#		frames at a given period in picoseconds (and optionally
#		select a subset).
#
# SYNOPSIS
#	add_H input.pdb trajectory step_ps subset
#
# DESCRIPTION
#	Used to rduce the dimensions of a trajectory file.
#
# Sometimes you may generate a trajectory file that is too heavy (in the order
# of hundreds of GB).
#
# You can imagine that handling these types of files is not really practical.
# From time to time you may want to transfer the trajectories from one
# workstation to another, or to your local laptop.
#
# In such cases, it is useful to “lighten” the trajectory and make it less
# memory-consuming to facilitate data transfer.
#
# What we can do is create an additional xtc file with a lower number of
# frames (amd optionally containing only a subset of the simulation system).
#
# There should be a trajectory named "$trajectory.{xtc|trr}" and a run input
# file named "$trajectory.tpr" in the same folder. If an
# index file "$trajectory.ndx" also exists, then it will be used for the 
# selection of the subsystem to be saved. Otherwise the default index will
# be used.
#
# ARGUMENTS
#	trajectory	- optional, default "md", the trajectory to subsample
#	step_ps		- optional, default "1", time in picoseconds, we will
#			extract one frame every $step_ps picoseconds
#	subset		- optional, default "System", select only a specific 
#			part of the system you are interested in
#
# AUTHOR
#	José R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
#	Licensed under (at your option) either GNU/GPL or EUPL
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

GMX_TRJ_SUBSAMPLE="GMX_TRJ_SUBSAMPLE"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include util_funcs.bash

function gmx_trj_subsample() {
    if ! funusage $# [trajectory] [step_ps] [subset] ; then return $ERROR ; fi 
    notecont "$*"

    local trj_name="${1:-md}"		# trajectory base name
    local step_ps=${2:-1}		# save frames every $step_ps picoseconds
    local subset=$"{3:-System}"
    
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
    
    if [ -s "${trj_name}".ndx ] ; then
        index="-n '${trj_name}.ndx'"
    else
        index=''
    fi
    
    if [ "$subset" = "System" ] ; then
        out=${trj_name}_every_${step_ps}ps.xtc 
    else
        out=${trj_name}_${subset}_every_${step_ps}ps.xtc 
    fi
    if [ -s "$out" ] ; then
        warncont "$out already exists"
        return $(( ERR++ ))
    fi
    
    echo "$subset" \
    | gmx trjconv \
        -f $trj \
        -s $tpr \
        -dt $step_ps \
        -o "$out" \
        $index

    # Call the program with gmx
    # Select the trjconv command
    # Select the -f flag and provide the starting trajectory ($trj_name.xtc)
    # Choose the -s flag and enter the .tpr file
    # The -dt flag allows us to reduce the number of frames in the output. 
    #   In our case, we will write one frame every ${step_ps}ps in our 
    #   output file.
    # Call the -o flag and decide how you want to name the output file 
    #   (${trj_name}_${step_ps}ps.xtc)
    # You may also want to include an index file you previously created 
    #   ($trj_name.ndx) via the -n flag. In this way, you can cut the 
    #   trajectory and, at the same time, select only a specific part of 
    #   the system you are interested in. GROMACS will still provide you 
    #   with a default index file.

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

    gmx_trj_subsample $*
else
    export GMX_TRJ_SUBSAMPLE
fi
