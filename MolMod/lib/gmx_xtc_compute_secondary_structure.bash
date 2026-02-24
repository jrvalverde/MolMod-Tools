#!/bin/bash
#
# NAME
#	gmx_xtc_compute_secondary_structure - desc
#
# SYNOPSIS
#	gmx_xtc_compute_secondary_structure [arg] [arg]
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


GMX_XTC_COMPUTE_SECONDARY_STRUCTURE="GMX_XTC_COMPUTE_SECONDARY_STRUCTURE"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash
include gmx_xvg_plot.bash


function gmx_xtc_compute_secondary_structure() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    export DSSP=`which dssp`

    local md="${1:-md}"
	local trj=""
	
	local name="${md%.*}"
	local ext="${md##*.}"
	local out="${name}_ss"
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


    if [ ! -e "$trj" ] ; then warncont "no $trj" ; return 1 ; fi
    if [ ! -e "${name}.tpr" ] ; then warncont "no $name.tpr" ; return 2 ; fi
	if [ ! -e "$name.ndx" ] ; then
	    $make_ndx -f $name.tpr -o $name.ndx <<<q
	fi

    boldblue "Computing secondary structure changes"
    mkdir -p "$out"
    if [ ! -e "${name}_ss/${name}_num_ss.xvg" ] ; then
    # this doesn't work on SARS for some reason
        echo "compute secondary structure"
		# ANCIENT, NO LONGER SUPPORTED
        #$do_dssp -f ${trj} \
		#	     -s ${name}.tpr \
		#		 -sc $out/${name}_scount.xvg \
		#		 -o $out/${name}_ss.xpm \
		#		 -dt 10 <<<MainChain
		$do_dssp -f $trj \
		         -s $name.tpr \
				 -n $name.ndx \
				 -num $out/${name}_num_ss.xvg \
				 -hmode dssp \
				 -nb \
				 -o $out/${name}_dssp.dat 

        gmx_xvg_plot_nxy $out/${name}_num_ss.xvg SVG
        gmx_xvg_plot_nxy $out/${name}_num_ss.xvg PNG
		fgp_xvg_plot     $out/${name}_num_ss.xvg

# FOR OLD VERSION
#        cat > ps.m2p <<END
#; Matrix options
#titlefont       = Helvetica     ; Matrix title Postscript Font name
#titlefontsize   = 20.0          ; Matrix title Font size (pt)
#legend          = yes           ; Show the legend
#legendfont      = Helvetica     ; Legend name Postscript Font name
#legendfontsize  = 12.0          ; Legend name Font size (pt)
#legendlabel     =               ; Used when there is none in the .xpm
#legend2label    =               ; Id. when merging two xpm s
#xbox            = 20.0           ; x-size of a matrix element
#ybox            = 2.0          ; y-size of a matrix element
#matrixspacing   = 20.0          ; Space between 2 matrices
#xoffset         = 0.0           ; Between matrix and bounding box
#yoffset         = 0.0           ; Between matrix and bounding box
#
#; X-axis options
#x-lineat0value  = 0            ; Draw line at matrix value==0
#x-major         = 100.0        ; Major tick spacing
#x-minor         = 50.0         ; Id. Minor ticks
#x-firstmajor    = 0.0           ; Offset for major tick
#x-majorat0      = no            ; Additional Major tick at first frame
#x-majorticklen  = 8.0           ; Length of major ticks
#x-minorticklen  = 4.0           ; Id. Minor ticks
#x-label         =               ; Used when there is none in the .xpm
#x-font          = Helvetica     ; Axis label PostScript Font
#x-fontsize      = 12            ; Axis label Font size (pt)
#x-tickfont      = Helvetica     ; Tick label PostScript Font
#x-tickfontsize  = 8             ; Tick label Font size (pt)
#
#;Y-axis options
#y-lineat0value  = none
#y-major         = 10.0
#y-minor         = 5.0
#y-firstmajor    = 0.0
#y-majorat0      = no
#y-majorticklen  = 8.0
#y-minorticklen  = 4.0
#y-label         =
#y-fontsize      = 12
#y-font          = Helvetica
#y-tickfontsize  = 8
#y-tickfont      = Helvetica
#END
#
#        $xpm2ps -f ${name}_ss.xpm -di ps.m2p -o ${name}_ubq_ss.eps
#	    $convert ${name}_ss.xpm ${name}_ss.png
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
    
    set -x

    gmx_xtc_compute_secondary_structure $*
else
    export GMX_XTC_COMPUTE_SECONDARY_STRUCTURE
fi
