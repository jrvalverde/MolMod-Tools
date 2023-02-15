#!/bin/bash
# NAME
#   	score_score	-- Score using 'score'
#
# SYNOPSIS
#	score_score receptor.{mol2|pdb] ligands.mol2
#
#	Score the ligands against the receptor.
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

function score_score {

    local receptor=$1
    local ligands=$2
    
    local SCOREDIR=$HOME/contrib/score
    local PATH=$SCOREDIR/bin:$PATH

    # Process arguments
    #echo "score: $receptor $ligands $known"

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

    scorelog=$rnam.$lnam.score_PK.txt

    # Prepare data for processing
    if [ ! -d score ] ; then mkdir score ; fi

    cd score

    if [ ! -e RESIDUE ] ; then ln -s $SCOREDIR/score/RESIDUE . ; fi
    if [ ! -e ATOMTYPE ] ; then ln -s $SCOREDIR/score/ATOMTYPE . ; fi

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

    #
    # split file at lines containing ###-- Name as many times as it appears
    #
    csplit -f $rnam.$lnam.lig -n 3 -z $lnam.mol2 '/^########## Name*/' '{*}' &> csplit.log
    # avoid empty initial files
    #if [ ! -s lig000] ; then rm lig000 ; fi

    #
    # score each individual ligand pose
    #
    if [ -s $scorelog ] ; then echo "Score already exists!" ; return 1 ; fi

    touch $scorelog

    for i in $rnam.$lnam.lig* ; do 
	    echo -n "$i:" >> $scorelog
	    score $rnam.pdb $i >> $scorelog
	    mv score.log $i.log 
	    mv score.mol2 $i.mol2
    done

    cd ..
}

score_score $*
