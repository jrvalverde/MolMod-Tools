#!/bin/bash
#
# NAME
#	gmx_make_ext_index - make an extended index of a coordinate file
#
# SYNOPSIS
#	gmx_make_ext_index coordinates
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
#   UNSUPPORTED:
#       WE WILL DEFINE AN EXTRA FUNCTION TO ADD GROUPS TO AN NDX
#   Extra optional arguments providing an index group specifications can
#   also be provided, and then, these groups will also be created. E.g.
#       gmx_make_ext_index md.pdb 'r 112 & '"chA" | "chB" & r 112'
#       gmx_make_ext_index md.pdb 'r 112' '"chA" | "chB" & r 112' ...
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
#	José R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
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
GMX_MAKE_EXT_INDEX='GMX_MAKE_EXT_INDEX'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash
include gmx_ndx_dedup.bash


function gmx_make_ext_index {
    #if [ $# -ne 1 ] ; then errexit "file"
    #else notecont $* ; fi
    if ! funusage $# "file.(pdb|gro|tpr)" ; then return $ERROR ; fi
    notecont $*

    local file=$1
    local sol=''
    local nosol=''
    local solvent=''
    
    local f="${file##*/}"	# filename with no dir
    local e="${file##*.}"	# extension (pdb or gro or tpr)
    local n="${f%.*}"		# name

    if [ ! -s $file ] ; then errexit "$file does not exist!" ; fi

    if [ -s $n.ndx ] ; then 
    	notecont "Using already existing $n.ndx"
        optndx="-n $n.ndx"
	else
	    optndx=''
    fi
    #echo "file=$file f=$f e=$e n=$n optndx=$optndx"
    
    # make an initial index (with chain IDs, if PDB) 
    if [ "$e" = "pdb" ] ; then
        # Make index file from PDB and try all possible one-letter chains
        # first, assign any unassigned ATOM or HETATM to chain Z
        #	this is needed for e.g. SOL atoms
        cat $file | sed -e '/\(^ATOM  \|^HETATM\).\{15\} / s/^\(.\{21\}\) /\1Z/g' > $n.Z.pdb
        (
            for i in {A..Z} ; do
	        echo "chain $i"
            done
            echo "q"
        ) | $make_ndx -f $n.Z.pdb $optndx -o ${n}.ndx
        #rm $file.Z.pdb
    else
	    # gro and tpr files lack chain information
        echo "q" | $make_ndx -f $file $optndx -o ${n}.ndx
    fi
#exit
    if grep -q DNA "${n}.ndx" ; then
        echo "Merging Protein and DNA"
        echo -e '"Protein" | "DNA"\n\nq' \
        | $make_ndx -f "$file"  -n "${n}.ndx" -o "${n}.ndx"
    fi

    # count number of existing groups (make_ndx uses zero-offset, so this
    #	will give us the number that will be assigned to the next group created)
    nsol=`grep -c "^\[" $n.ndx`
    nnosol=$((nsol + 1))
	
    # check if there are water and ions
    if grep -q Water_and_ions ${n}.ndx ; then
    	solvent='Water_and_ions'
    # check if there is only water
    elif grep -q "^(\[ SOL_ION \]" "$n.ndx" ; then
	# or maybe it was a protein with complexed ions
 		solvent="SOL_ION"
    elif grep -q Water ${n}.ndx ; then
    	solvent='Water'
    elif grep -q "^(\[ SOL \]" "$n.ndx" ; then
 		solvent='"SOL" | "Ion" | "NA" | "CL"'
    elif grep -q TIP3 $n.ndx ; then
        # CHARMM water with Cl and K (we can add more names even if absent)
        solvent='"TIP3" | "CLA" | "POT"'
    else
        # apparently there is no water, keep default ${n}.ndx and return
        return $OK
    fi

    notecont "$solvent $sol $nosol"
    # add solvent/solute groups to the index file (and rename them)
    echo "
    \"$solvent\"
    name $nsol Solvent
    !$nsol
    name $nnosol Solute
    q
    " | $make_ndx -f $file -n ${n}.ndx -o ${n}.ndx
    
    if [ "TRUE" = "FALSE" ] ; then
        # remove first argument (coordinates)
        shift
        # now what remains is a list of additional groups to add
        for i in "$[@]" ; do
            if [ "$i" = '' ] ; then break ; fi
            echo -e "$i\q" | $make_ndx -f $file -n "$n.ndx" -o "${n}.ndx"
        done
    fi

    rm -f ./\#$n.ndx*

    # just in case
	gmx_ndx_dedup $n
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
	include gmx_ndx_dedup.bash
    
    gmx_make_ext_index $*
else
    export GMX_MAKE_EXT_INDEX
fi

