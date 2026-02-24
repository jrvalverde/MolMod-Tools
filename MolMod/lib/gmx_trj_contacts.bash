#!/bin/bash
#
# NAME
#	gmx_trj_contacts - analyze H-bonds during a trajectory
#
# SYNOPSIS
#	gmx_trj_contacts [md_name] [subset1] [subset2]
#
# DESCRIPTION
#	Given a trajectory default filename, this will analyze it to count
# the number of contacts between two specified groups (as defined in the
# ndx file) at each frame and generate an XVG file.
#
# ARGUMENTS
#	md_name	- the MD trajectory deffnm
#	subset1 - the first subset (as per index file) 
#	subset2 - the second subset (as per index file)
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


GMX_TRJ_CONTACTS_H="GMX_TRJ_CONTACTS_H"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_trj_contacts() {
    if ! funusage $# [md_name] [subset1] [subset2] ; then return $ERROR ; fi 
    notecont "$*"

	local md=${1:-md}
	local subset1=${2:-Protein}
	local subset2=${3:-DNA}
	
	local trj=""
	local name="${md%.*}"
	local ext="${md##*.}"
	local out="${md}_contacts"
	if [ "$ext" = "xtc" -o "$ext" = "trr" ] ; then
	    trj="$md"
    elif [ -s "$name".xtc ] ; then
	    trj="$name".xtc
    elif [ -s "$name".trr ] ; then 
	    trj="$name.trr"
	else
        warncont "$md does not look like a trajectory"
		return 1
    fi


    if [ ! -e "$trj" ] ; then return 1 ; fi
	# find out TPR file availability
    if [ -s "${md}.tpr" ] ; then
        tpr="${md}.tpr"
    else
        warncont "no ${md}.tpr"
        return 2
    fi
	
	# see if there is any index file
    if [ -s "${md}".ndx ] ; then
        index="-n ${md}.ndx"
    else
        index=''
    fi
		
	mkdir -p $out

	# in old versions we may need the group number:
	#	find groups, number them starting at zero (like GROMACS), then
	# 	identify the group we want and get its number
	s1=`grep "^\[" ${md}.ndx | nl -v 0 | grep -w "$subset1" | sed -e 's/^ \+//g' -e 's/\t.*//g'`
    s2=`grep "^\[" ${md}.ndx | nl -v 0 | grep -w "$subset2" | sed -e 's/^ \+//g' -e 's/\t.*//g'`

    if [ ! -s $out/${md}_numcont_${subset1}-${subset2}.xvg ] ; then
    	#echo \
		gmx mindist \
			-f $trj \
			-s $tpr \
			$index \
			-od $out/${md}_mindist_${subset1}-${subset2}.xvg \
			-on $out/${md}_numcont_${subset1}-${subset2}.xvg \
			-or $out/${md}_mindistres_${subset1}-${subset2}.xvg \
			-pbc \
			< <( echo -e "${subset1}\n${subset2}" )

    	for i in $out/*xvg ; do
	    	gmx_xvg_plot $i PNG
			fgp_xvg_plot $i
    	done
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
    include gmx_setup_cmds.bash
    include gmx_xvg_plot.bash

    gmx_trj_contacts $*
else
    export GMX_TRJ_CONTACTS
fi
