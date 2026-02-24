#!/bin/bash
#
# NAME
#	gmx_xtc_cluster - desc
#
# SYNOPSIS
#	gmx_xtc_cluster [arg] [arg]
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


GMX_XTC_CLUSTER="GMX_XTC_CLUSTER"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash

convert=`which convert`		# from ImageMagick
#convert="gm convert"		# from GraphicsMagick

function gmx_xtc_cluster() {
    if ! funusage $# [md_name] ; then return $ERROR ; fi 
    notecont "$*"

    local dyn="${1:-md}"
	
	local md="${dyn%.*}"
	local ext="${dyn##*.}"
	local out="${md}_cluster"
	local trj=""
	if [ "$ext" = "xtc" -o "$ext" = "trr" ] ; then
	    trj="$dyn"
    elif [ -s "$md".xtc ] ; then
	    trj="$md".xtc
    elif [ -s "$md".trr ] ; then 
	    trj="$md.trr"
	else
        warncont "$md does not look like a trajectory"
		return 1
    fi

    if [ ! -s "${trj}" ] ; then return 1 ; fi
    if [ ! -e "${md}.tpr" ] ; then return 2 ; fi
	
    mkdir -p "$out"

    boldblue "Clustering"
    if [ ! -e "$out/${md}_clusters.pdb" ] ; then
        $g_cluster -s "$md.tpr" \
		    	   -f "${trj}" \
		    	   -cl "$out/${md}_clusters.pdb" \
				   -cutoff 0.5 \
	        	   -method gromos \
				   -dt 10 \
				   -dist "$out/${md}_rmsd-dist.xvf" \
		    	   -o "$out/${md}_rmsd-clust.xpm" \
            	   < <( echo -e "Protein\nSystem" )

        $convert $out/${md}_rmsd-clust.xpm $out/${md}_rmsd-clust.png
		if [ `nfiles "${md}*clust*.*"` -gt 0 ] ; then
            mv "${md}"*clust*.* ${md}_rmsd-dist.xvf  "$out"
		fi
    fi
    # and now get the cluster average structures
    if [ ! -e "$out/${md}_av_clust.pdb" ] ; then
        $g_cluster -s "$md.tpr" \
		       -f "$trj" \
		       -cl $out/${md}_av_clust.pdb \
			   -cutoff 0.5 \
	           -method gromos \
			   -dt 10 \
			   -av \
			   -dist $out/${md}_av_rmsd-dist.xvf \
		       -o $out/${md}_av_rmsd-clust.xpm \
               < <( echo -e "Protein\nSystem" ) 
		
        $convert $out/${md}_av_rmsd-clust.xpm $out/${md}_av_rmsd-clust.png
		if [ `nfiles "${md}_av_*"` -gt 0 ] ; then
	        mv "${md}_av_"* "$out"
		fi
    fi
	
    #egrep -v '( SOL | WAT |TIP3| CLA | NA | POT )' $out/${md}_clustav.pdb > $out/${md}_clustav_nosol.pdb
    egrep -v '( SOL | WAT |TIP3| CLA | NA | POT )' $out/${md}_clusters.pdb > $out/${md}_clusters_nosol.pdb
    #egrep -v '( SOL | WAT |TIP3| CLA | NA | POT |DPPC)' $out/${md}_clustav.pdb > $out/${md}_clustav_noDPPC.pdb
    egrep -v '( SOL | WAT |TIP3| CLA | NA | POT |DPPC)' $out/${md}_clusters.pdb > $out/${md}_clusters_noDPPC.pdb

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

    gmx_xtc_cluster $*
else
    export GMX_XTC_CLUSTER
fi
