#!/bin/bash
#
# NAME
#	gmx_xtc_struct_at - get structure at time t from trajectory name.xtc
#
# SYNOPSIS
#	gmx_xtc_struct_at [name] [t]
#
# DESCRIPTION
#	Given a XTC trajectory and its corresponding .tpr file, extract 
# the frame at time t. 
#	A time of -1 will be interpreted as the last frame, and a time 
# of 0 as the first frame.
#
# ARGUMENTS
#	name	- trajectory name WITHOUT extension
#	t	- time to extract
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


GMX_XTC_STRUCT_AT="GMX_XTC_STRUCT_AT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash

function gmx_xtc_struct_at() {
    if ! funusage $# [md_name] [time] ; then return $ERROR ; fi 
    notecont "$*"

    md="${1:-md}"
    t="$2"
    tn="$t"			# save so we later know if we were asked for last

    if [ ! -e "${md}.xtc" ] ; then return 1 ; fi
    if [ ! -e "${md}.tpr" ] ; then return 2 ; fi
    if [ ! -e "${md}.ndx" ] ; then 
	echo q | $make_ndx  -f "${md}.tpr" -o "${md}.ndx" ; 
    fi
    if [ "$t" = "-1" ] ; then
        # use last saved time
	#	try to avoid potentially long calculations
	if [ -e "$md.lastt" ] ; then
	    t=`cat "$md.lastt"`
            t=`echo "$t" | sed -e 's/ //g'`		# remove space
	    #echo "t=[$t]"
        else
	    # get last time recorded in the trajectory
	    t=`$g_check -f "$md.xtc" |& grep "Reading frame" \
               | tail -n 1 | sed -e 's/.* time//g' -e 's/ //g'`
        fi
    fi
    if [ "$t" = "" ] ; then t=0 ; fi

    # do the extraction
    boldblue " Getting t=$t configuration from $md.xtc"
    echo "System" | $trjconv -f "$md.xtc" -s "$md.tpr" -n "$md.ndx" \
        	-o "${md}_${t}.gro" -dump "$t"
			
    if [ "${tn}" =  "0" ] ; then ln "${md}_${t}.gro" "${md}_init.gro" ; fi
    if [ "${tn}" = "-1" ] ; then ln "${md}_${t}.gro" "${md}_last.gro" ; fi
    return 0

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

    gmx_xtc_struct_at $*
else
    export GMX_XTC_STRUCT_AT
fi
