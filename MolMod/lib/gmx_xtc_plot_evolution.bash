#!/bin/bash
#
# NAME
#	gmx_xtc_plot_evolution - plot energy evolution of an MD trajectory
#
# SYNOPSIS
#	gmx_xtc_plot_evolution [name]
#
# DESCRIPTION
#	Make plots of energy, pressure and temperature evolution during an
# MD trajectory in XTC format
#
#
# ARGUMENTS
#	name	- name of the XTC trajectory without the .xtc extension
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


GMX_XTC_PLOT_EVOLUTION="GMX_XTC_PLOT_EVOLUTION"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_xtc_plot_evolution() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    local md="${1:-md}"
	
    local name="${md%.*}"
	local ext="${md##*.}"
	local out="${name}_plots"

    if [ ! -e "$name.edr" ] ; then return 1 ; fi

    notecont "Plotting system evolution"
	mkdir -p "$out"
    if [ ! -e "${name}_plots/${name}_potenergy.xvg" ] ; then
        echo "Potential"    | $g_energy -f $name.edr -o $out/${name}_potenergy.xvg
    fi
    if [ ! -e "${name}_plots/${name}_kinenergy.xvg" ] ; then
       echo "Kinetic-En"   | $g_energy -f $name.edr -o $out/${name}_kinenergy.xvg
    fi
    if [ ! -e "${name}_plots/${name}_totenergy.xvg" ] ; then
        echo "Total-Energy" | $g_energy -f $name.edr -o $out/${name}_totenergy.xvg
    fi
    if [ ! -e "${name}_plots/${name}_pressure.xvg" ] ; then
        echo "Pressure"     | $g_energy -f $name.edr -o $out/${name}_pressure.xvg
    fi
    if [ ! -e "${name}_plots/${name}_temperature.xvg" ] ; then
        echo "Temperature"  | $g_energy -f $name.edr -o $out/${name}_temperature.xvg
        #echo "20" | g_energy -f $name.edr -o ${name}_volume.xvg
        #echo "21" | g_energy -f $name.edr -o ${name}_density.xvg
    fi
    # Make plots with running average
	cd "$out"
    # These may be truncated
	for i in SVG PNG ; do
	    gmx_xvg_plot_running_average   ${name}_potenergy.xvg $i
        gmx_xvg_plot_running_average   ${name}_kinenergy.xvg $i  
        gmx_xvg_plot_running_average   ${name}_totenergy.xvg $i
        gmx_xvg_plot_running_average   ${name}_pressure.xvg  $i
        gmx_xvg_plot_running_average   ${name}_temperature.xvg $i
    done
	for i in *.xvg ; do
	    fgp_xvg_plot $i
	done
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
    include gmx_xvg_plot.bash

    gmx_xtc_plot_evolution $*
else
    export GMX_XTC_PLOT_EVOLUTION
fi
