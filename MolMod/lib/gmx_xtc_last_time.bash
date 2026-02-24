#!/bin/bash
#
# NAME
#	gmx_xtc_last_time - find last time in a trajectory
#
# SYNOPSIS
#	gmx_xtc_last_time [xtc-traj-name]
#
# DESCRIPTION
#	Get last time stored in an XTC trajectory file
#
# ARGUMENTS
#	xtc-traj-name	- XTC trajectory file WITHOUT the .xtc extension
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


GMX_XTC_LAST_TIME="GMX_XTC_LAST_TIME"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash


function gmx_xtc_last_time() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"
    
    local md="$1"
    
    if [ ! -e "${md}.xtc" ] ; then return 1 ; fi
    
    boldblue "Finding last time in trajectory"
    
    # find out last time in the trajectory from stderr of gmx check
    #lastt=`$g_check -f $md.xtc |& grep "Last frame" \
    #       | sed -e 's/.* time//g'`
    lastt=`$g_check -f $md.xtc |& grep "Reading frame" \
           | tail -n 1 | sed -e 's/.* time//g'`

    if [ "$lastt" == "" ] ; then 
        boldred "NO LAST FRAME!" 
        return 0; 
    fi
    echo "LAST TIME =" $lastt 
    echo "$lastt" | tr -d ' '> "${md}.lastt"
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
    
    gmx_xtc_last_time $*
else
    export GMX_XTC_LAST_TIME
fi
