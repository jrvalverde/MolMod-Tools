#!/bin/bash
#
# NAME
#	gmx_xtc_compute_rmsd - Compute RMSD
#
# SYNOPSIS
#	gmx_xtc_compute_rmsd [name]
#
# DESCRIPTION
#	
#
#
# ARGUMENTS
#	name	- trajectory name without extension
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


GMX_XTC_COMPUTE_RMSD="GMX_XTC_COMPUTE_RMSD"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include fs_funcs.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_xtc_compute_rmsd() {
    if ! funusage $# [md_name] [delta_ps] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
    local trj=""

    local name="${md%.*}"
    local ext="${md##*.}"
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
    if [ ! -e "${name}.tpr" ] ; then return 2 ; fi

    boldblue "Computing RMSD from '$name'"
    mkdir -p "${name}_rmsd"
    if [ ! -e "${name}_rmsd/${name}_rmsd.xvg" ] ; then
        $g_rms -s ${name}.tpr -f ${name}.xtc \
		       -o ${name}_rmsd/${name}_rmsd.xvg -tu ns <<END
Backbone
Backbone
END
        # and make a graph with running averages (100 data points)
        gmx_xvg_plot_running_average ${name}_rmsd/${name}_rmsd.xvg SVG
        gmx_xvg_plot_running_average ${name}_rmsd/${name}_rmsd.xvg PNG
	fgp_xvg_plot                 ${name}_rmsd/${name}_rmsd.xvg
    fi
    # move any remaining output into a subdirectory
    if [ `nfiles "*_rmsd.*"` -gt 0 ] ; then
        mv *_rmsd.* "${name}_rmsd"
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
    include fs_funcs.bash
    include util_funcs.bash
    include gmx_setup_cmds.bash
    include gmx_xvg_plot.bash

    gmx_xtc_compute_rmsd $*
else
    export GMX_XTC_COMPUTE_RMSD
fi
