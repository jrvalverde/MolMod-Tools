#!/bin/bash
#
# NAME
#	gmx_continue_md_from_checkpoint - continue an interrupted trajectory
#
# SYNOPSIS
#	gmx_continue_md_from_checkpoint [md_name]
#
# DESCRIPTION
#	Continue an interrupted Molecular Dynamics trajectory from the
# latest valid checkpoint. Only the trajectory name has to be provided.
# If a checkpoint with the name of the trajectory ($md_name.cpt) is found,
# it will be used, otherwise, a file named ${md_name}_prev.cpt is sought
# and, if found, used instead.
#
#	The trajectory is restarted from the checkpoint, discarding all
# data after the checkpoint, and new results are added at the end of the
# files from the interrupted trajectory.
#
# ARGUMENTS
#	md_name	- the name of the trajectory (without extension), optional,
#		defaults to 'md'
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


GMX_CONTINUE_MD_FROM_CHECKPOINT="GMX_CONTINUE_MD_FROM_CHECKPOINT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

#
# By default, GROMACS writes a checkpoint file of your system in the cpt format
# (md.cpt) every 15 minutes. It also automatically backs up the previous
# checkpoint as md_prev.cpt.
#
# The checkpoint files contain a complete description of the system storing the
# coordinates and velocities of the system at full precision. Therefore, you can
# always continue the simulation from the last checkpoint exactly as if the
# interruption never occurred.
# 
# To do that, you only need to pass it to the gmx mdrun with the -cpi flag. 
#
function gmx_continue_md_from_checkpoint() {

    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    local cpt="${1:-md}"		# gromacs default is state.cpt
    local v='-v'			# verbose mode ('' or '-v')
    local ERR=1
    
    if [ ! -s "$cpt".cpt -o ! -s "$cpt"_prev.cpt ] ; then
        warncont "$cpt.{cpt} or ${cpt}_prev.cpt does not exist"
        return $(( ERR ))
    fi

    if [ ! -s "${cpt}".tpr ] ; then
        warncont "no ${name}.tpr"
        return  $(( ERR++ ))
    fi

    #gmx mdrun -cpi "$cpt".cpt -s "$cpt".tpr -noappend
    # this will require concatenating the new trajectory output
    # with the old one
    # NOTE: noappend should not be needed and then gromacs should
    # continue expanding the previous files!!!
    
    gmx mdrun -cpi "$cpt".cpt -deffnm "$cpt" $v
    #gmx mdrun -cpi "$cpt".cpt -s "$cpt".tpr -deffnm "$cpt" $v
    
    # this should append at the end and not require concatenation
    # the -deffnm is required so that gromacs uses the prefix to
    # find all the proper input and output files
    # we might optionally change the frequency of checkpointing
    # (in minutes) with '-cpi $time_min'
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

    gmx_continue_md_from_checkpoint $*
else
    export GMX_CONTINUE_MD_FROM_CHECKPOINT
fi
