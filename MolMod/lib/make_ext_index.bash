#!/bin/bash
#
# NAME
#	make_ext_index - make an extended index of a coordinate file
#
# SYNOPSIS
#	make_ext_index coordinates
#
# DESCRIPTION
#	Coordinates must be a filename ending in .pdb or .gro containing
#	the atomic coordinates of a protein or protein complex.
#
#	If the input file is in PDB format, it will be scanned for the
#	existence of chains, and each chain will be indexed separately,
#	with all atoms and ligands that have not been assigned to a chain
#	being added into chain 'Z'.
#
#	If the input file is in Gromacs format, it will simply be indexed.
#
#	In either case, the coordinates will be scanned for the presence
#	of Water and possibly ions. If there are, two additional indexes
#	will be built, one for solvent (water and ions) and one for the
#	solute(s) containing protein and ligands.
#
# CAVEAT
#	We are assuming that the system is not already using chain 'Z'.
#	This may be a little too optimistic.
#
#	If there are atoms that should belong to the same chain but are
#	not labelled as such, said atoms will be taken 'out' of their chain
#	and assigned to chain 'Z'.
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
#	Licensed under (at your option) either GNU/GPL or EUPL
#
# LICENSE:
#
#	Copyright 2014 JOSE R VALVERDE, CNB/CSIC.
#	Copyright 2018 JOSE R VALVERDE, CNB/CSIC.
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
MAKE_EXT_INDEX='MAKE_EXT_INDEX'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


function make_ext_index {
    #if [ $# -ne 1 ] ; then errexit "file"
    #else notecont $* ; fi
    if ! funusage $# file ; then return $ERROR ; fi
    notecont $*

    local file=$1
    local sol=''
    local nosol=''
    local solvent=''
    
    local f="${file##*/}"	# filename with no dir
    local e="${file##*.}"	# extension (pdb or gro)
    local n="${f%.*}"		# name

    if [ -e $n.ndx ] ; then 
    	notecont "Using already existing $n.ndx"
        return $OK
    fi
    # make an initial index (with chain IDs, if PDB) 
    if [ "$e" = "pdb" ] ; then
        # Make index file from PDB and try all possible one-letter chains
        # first, assign any unassigned ATOM or HETATM to chain Z
        #	this is needed for e.g. SOL atoms
        cat $file | sed -e '/\(^ATOM  \|^HETATM\).\{15\} / s/^\(.\{21\}\) /\1Z/g' > $file.pdb
        (
            for i in {A..Z} ; do
	        echo "chain $i"
            done
            echo "q"
        ) | $make_ndx -f $file.pdb -o $n.ndx
        rm $file.pdb
    else
        echo "q" | $make_ndx -f $file -o $n.ndx
    fi


    # count number of existing groups (make_ndx uses zero-offset, so this
    #	will give us the number that will be assigned to the next group created)
    sol=`grep -c "^\[" $n.ndx`
    nosol=$(($sol + 1))
    # check if there are water and ions
    grep -q Water_and_ions $n.ndx
    if [ $? -eq 0 ] ; then
    	solvent='Water_and_ions'
    else
        # check if there is only water
        grep -q Water $n.ndx
        if [ $? -eq 0 ] ; then
    	    solvent='Water'
        else
            # no water, keep default $n.ndx and return
            return $OK
        fi
    fi

    notecont "$solvent $sol $nosol"
    # add solvent groups to the index file
    echo "
    \"$solvent\"
    name $sol Solvent
    ! $sol
    name $nosol Solute
    q
    " | $make_ndx -f $file -n $n.ndx -o $n.ndx

    rm -f ./\#$n.ndx*


}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash
    
    make_ext_index $*
fi

