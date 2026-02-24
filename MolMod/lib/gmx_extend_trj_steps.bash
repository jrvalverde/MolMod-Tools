#!/bin/bash
#
# NAME
#	gmx_append_trj_steps - append to a trajectory a number of steps 
#                              to new files
#
# SYNOPSIS
#	gmx_extend_trj_steps [name] [steps]
#
# DESCRIPTION
#	Given a terminated trajectory, with its corresponding input run 
# .tpr and checkpoint .cpt files, create a new extension trajectory for
# the specified number of steps.
#
#	The new trajectory will start from the last checkpoint of the
# previous one.
#
# ARGUMENTS
#	name	- the trajectory base name (without extension)
#	steps	- the number of steps to add to the previous trajectory
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


GMX_EXTEND_TRJ_STEPS="GMX_EXTEND_TRJ_STEPS"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function gmx_extend_trj_steps() {
    if ! funusage $# [md_name] [steps] ; then return $ERROR ; fi 
    notecont "$*"

    local name=${1:-md}
    local step=${2:1000}

    local previous=''
    local next=''
    local ERR=1
    
    # In some cases, you may run a simulation for a certain period of time but once
    # it finishes you decide that you want to proceed further. To accomplish this 
    # you can use the built-in gmx convert-tpr module.
    # 
    # This module allows you to edit the tpr files you assembled via the gmx grompp
    # module in various ways. Among others, we can decide to extend the duration of
    # the simulation for a certain tpr file.
    # 
    # This procedure involves two steps:
    # 
    #     First you need to extend the duration of the simulation. We will do this
    # with the gmx convert-tpr module that will generate a new tpr file with
    # additional time.
    # 
    #     In the second step you will only need to run the new tpr file starting 
    # from the last checkpoint (as explained above).
    # 
    previous="$name"
    next="${previous}+${step}steps}"
    
    if [ ! -s "$previous".tpr ] ; then
        warncont "no $previous.tpr"
	return $(( END++ ))
    fi
    if [ ! -s "$previous".cpt ] ; then
        warncont "no $previous.cpt"
	return $(( END++ ))
    fi
    
    gmx convert-tpr -s "$previous.tpr" -nsteps $steps -o "$next.tpr"

    # now run the next tpr file starting from the last checkpoint
    # we need the -noappend because we use new output file names (-deffnm)
    gmx mdrun -s "$next.tpr" -cpi "$previous.cpt" -deffnm "$next" -noappend -v
    
    # we could extend the previous trajectory to the same files by making
    # a new tpr and continuing as if it had broken midway through the
    # calculation.

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

    gmx_extend_trj_to_ps $*
else
    export GMX_EXTEND_TRJ_STEPS
fi
