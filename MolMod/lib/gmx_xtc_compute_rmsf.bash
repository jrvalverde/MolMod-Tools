#!/bin/bash
#
# NAME
#	gmx_xtc_compute_rmsf - desc
#
# SYNOPSIS
#	gmx_xtc_compute_rmsf [arg] [arg]
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


GMX_XTC_COMPUTE_RMSF="GMX_XTC_COMPUTE_RMSF"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include fs_funcs.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash
include gmx_fix_multichain_xvg.bash



function gmx_xtc_compute_rmsf() {
    if ! funusage $# [md_name] [delta_ps] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
	local trj=""
	
	local name="${md%.*}"
	local ext="${md##*.}"
	local out="${name}_rmsf"
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
	
    boldblue "Computing RMSF from '$name'"
    mkdir -p "$out"
	#	backbone
    if [ ! -e "$out/${name}_rmsf_bb.xvg" ] ; then
    	boldblue "    backbone"
        echo "Backbone"  | $g_rmsf -s ${name}.tpr -f $trj \
                                   -o $out/${name}_rmsf_bb.xvg \
                                   -oq $out/${name}_rmsf_bb.pdb \
                                    -res

        gmx_xvg_plot_running_average $out/${name}_rmsf_bb.xvg SVG 
        gmx_xvg_plot_running_average $out/${name}_rmsf_bb.xvg PNG 
		fgp_xvg_plot $out/${name}_rmsf_bb.xvg
    fi
    if [ ! -e "$out/${name}_rmsf_bb.mc.xvg" ] ; then
        boldblue "    backbone (multichain) of $name"
	    # attempt to fix multichain plots
	    gmx_fix_multichain_xvg ${name}_rmsf/${name}_rmsf_bb.xvg
        gmx_xvg_plot $out/${name}_rmsf_bb.mc.xvg SVG
        gmx_xvg_plot $out/${name}_rmsf_bb.mc.xvg PNG
		fgp_xvg_plot $out/${name}_rmsf_bb.mc.xvg
    fi    
    #	side chains
    if [ ! -e "${name}_rmsf/${name}_rmsf_sc.xvg" ] ; then
    	boldblue "    sidechains"
        echo "SideChain" | $g_rmsf -s ${name}.tpr \
				-f $trj \
				-o $out/${name}_rmsf_sc.xvg \
				-oq $out/${name}_rmsf_sc.pdb

        gmx_xvg_plot_running_average $out/${name}_rmsf_sc.xvg SVG
        gmx_xvg_plot_running_average $out/${name}_rmsf_sc.xvg PNG
		fgp_xvg_plot $out/${name}_rmsf_sc.xvg

    fi
    #	non-protein (ligands)
    if [ -s Ligands.pdb ] ; then
    	boldblue "    ligands"
        echo "non-Protein" | $g_rmsf \
		              -s ${name}.tpr \
					  -f $trj \
					  -o $out/${name}_rmsf_np.xvg \
					  -oq $out/${name}_rmsf_np.pdb
        gmx_xvg_plot_running_average $out/${name}_np_rmsf.xvg SVG
        gmx_xvg_plot_running_average $out/${name}_np_rmsf.xvg PNG
	fgp_xvg_plot $out/${name}_np_rmsf.xvg
    fi
	
	# just in case we forgot something
	if [ `nfiles "*_rmsf*.*"` -gt 0 ] ; then
        mv *_rmsf*.* "$out"
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
    include gmx_fix_multichain_xvg.bash

    gmx_xtc_compute_rmsf $*
else
    export GMX_XTC_COMPUTE_RMSF
fi
