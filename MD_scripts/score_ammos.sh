#!/bin/bash
# NAME
#   	score_ammos	-- Score using AMMOS
#
# SYNOPSIS
#
#	score_ammos receptor.pdb ligands.mol2
#
#	Score one or more complex(es) between ligand(s) and receptor
#
#		receptor.pdb	the receptor in PDB format
#		ligands.mol2	one or more ligans in MOL2 format
#
# AUTHOR
#	All the code is
#		(C) Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#	and
#		Licensed under (at your option) either GNU/GPL or EUPL
#
# LICENSE:
#
#	Copyright 2014 JOSE R VALVERDE, CNB/CSIC.
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

# recursively get the last file pointed to by a symlink
function lastlink() { [ ! -h "$1" ] && echo "$1" || (local link="$(expr "$(command ls -ld -- "$1")" : '.*-> \(.*\)$')"; cd $(dirname $1); lastlink "$link" | sed "s|^\([^/].*\)\$|$(dirname $1)/\1|"); }

# get the real absolute path name of a file
function realfile () {
   if [ -x `which readlink` ] ; then
        readlink -e $1
    elif [ -x `which realpath` ] ; then
        realpath $1
    else
        local target=`lastlink $1`
        local tname=${target##*/}
        local tdir=`dirname $target`
        echo $(cd $tdir ; pwd -P)"/$tname"
    fi
}

function score_ammos {
    local receptor=$1
    local ligands=$2
    
    local AMMOS=$HOME/contrib/AMMOS_ProtLig/
    local PATH=$AMMOS/bin:$PATH

    # Process arguments
    #echo "DSX: $receptor $ligands $known"

    if [ ! -e $ligands -o ! -e $receptor ] ; then
        echo "AMMOS: Nothing to score"
        exit
    fi

    local rext="${receptor##*.}"
    local rnam="${receptor%.*}"
    local rok=`realfile $receptor`
    if [ "$rext" != "pdb" -a "$rext" != "mol2" ] ; then
    	echo "ERROR: Receptor $receptor must be a PDB or MOL2 file"
        return 1
    fi
    
    local lext="${ligands##*.}"
    local lnam="${ligands%.*}"
    local lok=`realfile $ligands`
    if [ "$lext" != "mol2" ] ; then
    	echo "ERROR: Ligands $ligands must be in a MOL2 file"
        return 1
    fi

    mkdir -p ammos
    cd ammos

    if [ ! -s $rok ] ; then echo "ERROR: $receptor ($rok)" ; return 1 ; fi
    if [ ! -e $rnam.pdb ] ; then 
        if [ "$rext" = "mol2" ] ; then
	    babel -imol2 $rok -opdb $rnam.pdb
        else
            ln -s $rok $rnam.pdb
        fi
    fi

    if [ ! -s $lok ] ; then echo "ERROR: $ligands ($lok)" ; return 1 ; fi
    if [ ! -s $lnam.mol2 ] ; then 
	ln -s $lok $lnam.mol2
    fi

    if [ ! -e ammos.in ] ; then
    cat > ammos.in <<END
path_of_AMMOS_ProtLig= $AMMOS
protein= $rnam.pdb
bank= $lnam.mol2
case_choice= 3 
radius= 6
END
    fi

    if [ ! -d ${lnam}_case_3_OUTPUT ] ; then
    AMMOS_ProtLig_sp4.py ammos.in <<END
1
END
    fi

    cd ..
}

score_ammos $*


