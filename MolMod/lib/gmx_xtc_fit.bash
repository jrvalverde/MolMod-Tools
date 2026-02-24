#!/bin/bash
#
# NAME
#	gmx_xtc_fit - fit XTC trajectory (rot+trans)
#
# SYNOPSIS
#	gmx_xtc_fit [name]
#
# DESCRIPTION
#	fit XTC trajectory (with corresponding TPR and NDX files) for
# rot+trans
#
#
# ARGUMENTS
#	name	- trajectory name (without .xtc extension)
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


GMX_XTC_FIT="GMX_XTC_FIT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash


function gmx_xtc_fit() {
    if ! funusage $# [md_name] [delta_ps] ; then return $ERROR ; fi 
    notecont "$*"

    local md="$1"
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

    if [ ! -s "${trj}" ] ; then warncont "no ${trj}!" ; return 1 ; fi
    if [ ! -e "$name.tpr" ] ; then warncont "no $name.tpr!" ; return 2 ; fi
    if [ ! -e "$name.ndx" ] ; then 
	$make_ndx -f "$name.tpr" -o "$name.ndx" <<<q
    fi
	
    boldblue "Fitting trajectory $name.xtc"
    if [ "COMPLEX" = "YES" ] ; then		# i.e. NEVER
	# fit using only relevant macromolecules
        # This will ONLY SAVE those macromolecules in the trajectory
	grep -q "^\[ Protein \]" "$name.ndx" ; P=$?
	grep -q "^\[ DNA \]" "$name.ndx" ; D=$?
	grep -q "^\[ RNA \]" "$name.ndx" ; R=$?
	if   [ $P -eq 0 -a $D -eq 0 -a $R -eq 0 ] ; then sel='"Protein"|"DNA"|"RNA"'
	elif [ $P -eq 0 -a $D -eq 0 ] ; then sel='"Protein"|"DNA"'
	elif [ $P -eq 0 -a $R -eq 0 ] ; then sel='"Protein"|"RNA"'
	elif [ $D -eq 0 -a $R -eq 0 ] ; then sel='"DNA"|"RNA"'
	elif [ $D -eq 0 ] ; then sel='"DNA"'
	elif [ $R -eq 0 ] ; then sel='"RNA"'
	elif [ $P -eq 0 ] ; then sel='"Protein"'
        elif grep -q '^\[ Solute \]' ; then sel='"Solute"'
	else sel='"System"'
	fi
	local n=`grep -c '^\[' "$name.ndx"`
	echo "$trj $sel $n"
        if ! grep -q "^\[ Complex \]" "$name.ndx" ; then
	    $make_ndx -n "$name.ndx" -o "${name}.ndx" \
	              < <( echo -e "${sel}\nname $n Complex\nq\n" )
	fi

        if [ ! -e "${name}_fit.xtc" -o ! -e "${name}_fit.tpr" ] ; then
            cp "${name}.ndx" "${name}_fit.ndx"
#cat<<END
            $trjconv -f "$trj" \
		             -s "$name.tpr" \
		             -n "${name}_fit.ndx" \
		             -o "${name}_fit.xtc" \
			     -fit rot+trans \
            < <( echo -e "Complex\nComplex\n" )
#END
            # in this case, we CANNOT reuse $md.* files, we need
            # to generate equivalent new ones containing only the
            # corresponding atoms
        
        fi
    else
        $trjconv -f "$trj" \
		         -s "$name.tpr" \
		         -n "${name}.ndx" \
		         -o "${name}_fit.xtc" \
			 -fit rot+trans \
        < <( echo -e "System\nSystem\n" )

	cp "$name.tpr" "${name}_fit.tpr"
        cp "$name.top" "${name}_fit.top"
        cp "$name.ndx" "${name}_fit.ndx"
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

    gmx_xtc_fit $*
else
    export GMX_XTC_FIT
fi
