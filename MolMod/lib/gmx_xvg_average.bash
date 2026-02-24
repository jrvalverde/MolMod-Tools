#!/bin/bash
#
# NAME
#	gmx_gmx_xvg_average - desc
#
# SYNOPSIS
#	gmx_gmx_xvg_average [arg] [arg]
#
# DESCRIPTION
#	
#
#
# ARGUMENTS
#	arg	- desc
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


GMX_XVG_AVERAGE="GMX_XVG_AVERAGE"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function average() {
    file=${1:-data.txt}

    awk "{ total += \$1; count++ } END { print total/count }" $file
}

function gmx_xvg_average() {
    if ! funusage $# [xvg] [column] ; then return $ERROR ; fi 
    notecont "$*"

    xvg=${1:-md.xvg}		# XVG file with the data in columns
    col=${2:-1}				# column to average
    
    cat $xvg \
    | grep -v '[#@]' \
    | sed -e 's/^ \+//g' -e 's/ \+/\t/g' \
    | cut -f $col | average -
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

    gmx_xvg_average $*
else
    export GMX_XVG_AVERAGE
fi
