#!/bin/bash
# NAME
#   	score_zscore	-- Score using 'xscore'
#
# SYNOPSIS
#	score_xscore receptor.{mol2|pdb] ligands.mol2
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

function score_xscore {

    local receptor=$1
    local ligands=$2
    
    # SETUP Xscore system
    #	ENSURE YOU USE THE CORRECT PATH HERE
    . $HOME/contrib/xscore/setup.sh

    
    # Process arguments
    #echo "xscore: $receptor $ligands $known"

    if [ ! -e "$ligands" -o ! -e "$receptor" ] ; then
        echo "XSCORE: Nothing to score"
        exit
    fi

    local rext="${receptor##*.}"	# leave extension
    local rnam="${receptor%.*}"		# remove extension
    local rname=${rnam##*/}			# remove leading dir path
    local rok=`realfile $receptor`
    if [ "$rext" != "pdb" -a "$rext" != "mol2" ] ; then
    	echo "ERROR: Receptor $receptor must be a PDB or MOL2 file"
        return 1
    fi
    
    local lext="${ligands##*.}"
    local lnam="${ligands%.*}"
    local lname=${lnam##*/}			# remove leading dir path
    local lok=`realfile $ligands`
    
    local outsum=${rname}_${lname}_xscore.sum
    local outlog=${rname}_${lname}_xscore.log
    
    if [ "$lext" != "mol2" ] ; then
    	echo "ERROR: Ligands $ligands must be in a MOL2 file"
        return 1
    fi

    
    if [ -s xscore/$outsum ] && grep -q energy xscore/$outsum ; then
        echo "$receptor $ligands already scored"
        return 0
    fi

    # Prepare data for processing
    if [ ! -d xscore ] ; then
        mkdir -p xscore
    fi
    destdir=`realfile ./xscore`
    
    workdir=`mktemp -d`
    cd $workdir
    if [ ! -s $rok ] ; then echo "ERROR: $receptor ($rok)" ; return 1 ; fi
    # this legacy check should be always false now
    if [ ! -e $rname.pdb ] ; then 
        if [ "$rext" = "mol2" ] ; then
	    babel -imol2 $rok -opdb $rname.pdb
        else
            ln -s $rok $rname.pdb
        fi
    fi

    if [ ! -s $lok ] ; then echo "ERROR: wrong $ligands ($lok)" ; return 1 ; fi
    # ditto, this check should be always false now
    if [ ! -s $lname.mol2 ] ; then 
	ln -s $lok $lname.mol2
    fi


    echo "Scoring $rname.pdb $lname.mol2"
    # set a timeout of 5' (300") on each
    #	$! expands to the PID of the most recently executed background command:
    #	( some-large-command ) & sleep 300 ; kill $!
    # the above has a problem in that if the command ends earlier we still wait
    # the specified timeout.
    #
    # The solution by J. R. Valverde in EMBnet.news is better, but we may also
    # use now the 'timeout' command from coreutils, which returns 124 if the
    # command was terminated by a timeout
    #
    #	Note: for the EMBnet.News solution try the following
    #
    # (submitter=$$ ; (sleep $tmo ; pkill -P $submitter)& large-command)& wait $!
    # or 
    # (submitter=$! ; (sleep $tmo ; kill $submitter)& large-command)& wait $!
    #
    # maximum running time of DSX (m = min., s = sec.)
    local tmo=15m 
    # grace timeout (15 sec.)
    local gto=15s
    #
    # this is to deal with inconsistencies in the timeout command
    # across different versions of Ubuntu
    #
    #	This works in Ubuntu 11.10 (e.g. xistral)
    #
    local toopt="-k $gto $tmo "
    #
    #	This works in Ubuntu 10.04.2 [seconds] (e. g. ngs)
    #
    #local toopt="300"

    timeout $toopt xscore -score $rname.pdb $lname.mol2 | grep -v "Warning:" > $destdir/$outsum
    if [ -f xscore.log ] ; then mv xscore.log $destdir/$outlog ; fi

    cd -
}

score_xscore $*
