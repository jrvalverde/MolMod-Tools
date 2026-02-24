#!/bin/bash
#
# NAME
#	gmx_xtc_compute_gyr_acf - desc
#
# SYNOPSIS
#	gmx_xtc_compute_gyr_acf [arg] [arg]
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


GMX_XTC_COMPUTE_GYR_ACF="GMX_XTC_COMPUTE_GYR_ACF"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_xtc_compute_gyr_acf() {
    if ! funusage $# [md_name] [delta_ps] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
	local trj=""
	
	name="${md%.*}"
	ext="${md##*.}"
	out="${name}_gyr_acf"
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

    if [ ! -e "${trj}" ] ; then notecont "no $trj" ; return 1 ; fi
    if [ ! -e "${name}.tpr" ] ; then notecont "no $name.tpr" ; return 2 ; fi

    boldblue "Computing radius of gyration"
    mkdir -p "${out}"
    # ACF is the angular correlation function.
    #
    if [ ! -e "$out/${name}_gyr.xvg" ] ; then
        echo "Backbone" | $g_gyrate \
		              -s ${name}.tpr \
                      -f ${trj} \
					  -o $out/${name}_gyr.xvg \
		      		  #-acf $out/${name}_acf.xvg	# obsoleted
        # this plot contains "N" xy plots
        # s0..n are the legends for each xy plot to superpose
        # in this case:
        #   s0 legend "Rg"
        #   s1 legend "Rg/sX/N"
        #   s2 legend "Rg/sY/N"
        #   s3 legend "Rg/sZ/N"
        gmx_xvg_plot_nxy $out/${name}_gyr.xvg SVG
        gmx_xvg_plot_nxy $out/${name}_gyr.xvg PNG
		fgp_xvg_plot                 $out/${name}_gyr.xvg
    fi
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
    include gmx_xvg_plot.bash

    gmx_xtc_compute_gyr_acf $*
else
    export GMX_XTC_COMPUTE_GYR_ACF
fi
