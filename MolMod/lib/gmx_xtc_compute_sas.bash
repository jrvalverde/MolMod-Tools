#!/bin/bash
#
# NAME
#	gmx_xtc_compute_sas - desc
#
# SYNOPSIS
#	gmx_xtc_compute_sas [arg] [arg]
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


GMX_XTC_COMPUTE_SAS="GMX_XTC_COMPUTE_SAS"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include fs_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_xtc_compute_sas() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    local md="$1"
	local trj=""
	
	local name="${md%.*}"
	local ext="${md##*.}"
	local out="${name}_sas"
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

    if [ ! -s "${trj}" ] ; then return 1 ; fi
    if [ ! -e "${name}.tpr" ] ; then return 2 ; fi
    mkdir  -p "$out"
	
    # protein surface area
    if [ ! -e $out/${name}_protein_sasa.xvg ] ; then
        boldblue "Computing SAS (Solvent Accessible Surface)"
        $g_sas -s ${name}.tpr \
	       -f ${trj} \
	       -o $out/${name}_protein_sasa.xvg \
           -odg $out/${name}_solvation_free_energy.xvg \
           -or $out/${name}_avg_residue_area.xvg \
	       -tv $out/${name}_protein_vol_dens.xvg \
	       < <( echo -e "Protein\nProtein" )

        gmx_xvg_plot_running_average $out/${name}_protein_sasa.xvg SVG
        gmx_xvg_plot_running_average $out/${name}_protein_sasa.xvg PNG
        gmx_xvg_plot_running_average $out/${name}_protein_vol_dens.xvg SVG
        gmx_xvg_plot_running_average $out/${name}_protein_vol_dens.xvg PNG
		fgp_xvg_plot                 $out/${name}_protein_sasa.xvg
		fgp_xvg_plot                 $out/${name}_protein_vol_dens.xvg
		fgp_xvg_plot                 $out/${name}_solvation_free_energy.xvg
		fgp_xvg_plot                 $out/${name}_avg_residue_area.xvg
    fi
	
    # paranoid checks
	if [ `nfiles "${name}_protein_sasa.*"` -gt 0 ] ; then
        mv "${name}_protein_sasa."* "$out"
	fi
	if [ `nfiles "${name}_protein_vol.*"` -gt 0 ] ; then
        mv "${name}_protein_vol."* "$out"
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

    gmx_xtc_compute_sas $*
else
    export GMX_XTC_COMPUTE_SAS
fi
