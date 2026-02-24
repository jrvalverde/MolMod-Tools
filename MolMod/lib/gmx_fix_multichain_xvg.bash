#!/bin/bash
#
# NAME
#	gmx_fix_multichain_xvg - fix a multichain XVG file to get split chain plots
#
# SYNOPSIS
#	gmx_fix_multichain_xvg file.xvg
#
# DESCRIPTION
#	Fix a multichain XVG file so each separate chain is plotted
# independently (instead of all being connected end-to-start).
#
# ARGUMENTS
#	name		- the XVG file name (without extension)
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
GMX_FIX_MULTICHAIN_XVG="GMX_FIX_MULTICHAIN_XVG"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function gmx_fix_multichain_xvg() {
    # multichain XVG files have all chains one after another with no
    # separation which makes the plots join the end of one to the 
    # start of the next.
    #
    # This can be fixed detecting backward jumps in numeration and
    # inserting an '&' which means 'start a new plot in a new color'
    #
    # However, this may create a problem for very large (>99 999 atoms)
    # systems, because in this case numbers wrap-around and restart
    # from 0.
    #
    # We can exploit this 'feature' to our advantage detecting if the
    # wrap-around number is '0' or if the last atom seen was 99·999
    # and not changing color then.

    local xvgfile="${1:-out.xvg}"

    local name=${xvgfile%.xvg}

    local lastx="-99999"
    cat $name.xvg \
    | while read l ; do 
	if [[ ${l::1} == [\#@\&] ]] ; then
            echo "$l" 
	else
            read x y <<< "$l"
	    #if [ $x -lt $lastx ] ; then
	    if [ $x -ne $((lastx+1)) ] ; then
	        if [ "$lastx" -ne 99999 -a "$x" -eq 0 ] ; then
		    echo "&"
                fi
	    fi
	    echo "$x	$y	$lastx"
	    lastx=$x
	fi

    done > $name.mc.xvg

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

    gmx_fix_multichain_xvg $*
else
    export GMX_FIX_MULTICHAIN_XVG
fi
