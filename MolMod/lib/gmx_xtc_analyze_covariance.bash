#!/bin/bash
#
# NAME
#	gmx_xtc_analyze_covariance - analyze trajectory covariance
#
# SYNOPSIS
#	gmx_xtc_analyze_covariance [name]
#
# DESCRIPTION
#	analyze trajectory covariance
#
#
# ARGUMENTS
#	name	- trajectory name without .xtc extension
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


GMX_XTC_ANALYZE_COVARIANCE="GMX_XTC_ANALYZE_COVARIANCE"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash

convert=convert			# ImageMagick
#convert="gm convert"	# GraphicsMagick

function gmx_xtc_analyze_covariance() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
	local trj=""
	
	name="${md%.*}"
	ext="${md##*.}"
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

    if [ ! -s "${trj}" ] ; then warncont "no $trj" ; return 1 ; fi
	if [ ! -s "$name.tpr" ] ; then warncont "no $name.tpr" ; return 2 ; fi
	if [ ! -s "$name.ndx" ] ; then
	    $make_ndx -f "$name.tpr" -o "$name.ndx" <<<q
	fi

    boldblue "Covariance analysis"
    mkdir -p "${name}_covariance"
    cd "${name}_covariance"
	symlink "../$trj" "$trj"
	symlink "../$name.tpr" "$name.tpr"
	symlink "../$name.ndx" "$name.ndx"
	if [ ! -s "${name}_eigenvec.trr" ] ; then
        # we should choose a representative reference structure, e.g. a cluster
	    gmx covar -s "$name.tpr" -f "$trj" -n "$name.ndx" \
        	-xpm  "${name}_covar.xpm" \
			-xpma "${name}_covar_aa.xpm" \
	    	-o    "${name}_eigenval.xvg" \
			-av   "${name}_covar_average.pdb" \
	    	-v    "${name}_eigenvec.trr" \
	    	< <( echo -e "Backbone\nBackbone" )
        fi
	$convert "${name}_covar.xpm" "${name}_covar.png"
	$convert "${name}_covar_aa.xpm" "${name}_covar_aa.png"
    cd ..

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
    include gmx_setup_cmds.bash

    gmx_xtc_analyze_covariance $*
else
    export GMX_XTC_ANALYZE_COVARIANCE
fi
