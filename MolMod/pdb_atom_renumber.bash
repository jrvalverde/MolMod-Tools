#!/bin/bash
#
# NAME
#	pdb_atom_renumber.bash
#
# SYNOPSIS
#	pdb_atom_renumber input.pdb output.pdb
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
PDB_ATOM_RENUMBER='PDB_ATOM_RENUMBER'

LIB=`dirname ${BASH_SOURCE[0]}`/lib	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


# NAME
#	strindex - lookup in a string a substring
#
# SYNOPSIS
#	strindex "a large string" "string"
#
# DESCRIPTION
#	strindex returns the position of the substring in the large
#	string, if found, or -1 if it is not present
#
function strindex() { 
    #if [ $# -ne 2 ] ; then errexit "largestring substring" ; fi
    if ! funusage $# "largestring substring" ; then return $ERROR ; fi
    
    # return position of $2 in $1, or -1 if not found
    x="${1%%$2*}"
    [[ $x = $1 ]] && echo -1 || echo ${#x}
}

# NAME
#	pdb_atom_renumber - renumber atoms in a PDB file
#
# SYNOPSIS
#	pdb_atom_renumber infile.pdb outfile
#
# DESCRIPTION
#	Reads an input PDB file (must have a '.pdb' or '.brk' extension)
#	and renumbers all ATOM, ANISOU and TER records starting from 1
#	saving the result in the specified output file.
#
#	The input file name is mandatory and must refer to an existing file
#	If the output file name is not given, then $1.renum will be used.
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
function pdb_atom_renumber {
    #if [ $# -lt 1 ] ; then errexit "pdbfile [outfile]" 
    #else notecont $* ; fi
    if ! funusage $# "pdbfile [outfile]" ; then return $ERROR ; fi
    notecont $*

    # Expect a PDB input file name as first argument and an output file as
    # second argument
    local pdb=$1
    local out=${2:-$pdb.renum}

    notecont "renumbering $pdb to $out"
    if [ ! -e $pdb ] ; then
        warncont "$1 not found" 
        return $ERROR
    fi

    local dir=`dirname $pdb`
    local fin="${pdb##*/}"
    local ext="${fin##*.}"
    local nam="${fin%.*}"
    if [ ! "$ext" == "pdb" -a ! "$ext" == "brk" ] ; then
        warncont "Input file must be a PDB file."
        return $ERROR
    fi
    
    #local entries="(^ATOM  )|(^TER   )|(^TER)|(^ANISOU)|(^HETATM)"
    echo -n "" > "$out"	# truncate any previously existing $pdbout
    local i=0
	local idx=0
    cat $pdb \
    | while read line ; do
        #echo "LINE! $line"
        #get line label (avoid external command to save time)
        #label=`echo "$line" | cut -c 1-6`
        label="${line:0:6}"
        #echo "[$label]"
        case $label in
            MODEL*|ENDMDL) 
			    i=0 
				echo "$line" >> "$out" 
				;;
			    i=0 
				echo "$line" >> "$out" 
				;;
            ATOM*|HETATM)
                # new atom
                i=$((i + 1))		# increase count
                # check if this is a huge (> 99999 atoms) PDB file
                # and if it is reset the count to *** 0 ***
                if [ "$i" -gt 99999 ] ; then i=0 ; fi
                # format count
                idx=`printf "%5d" $i`
                #echo "[$idx]" >> $out
                # substitute index (avoid external command to save time)
                echo "${label}${idx}${line:11}" >> "$out"
                #echo "$line" | sed -e "s/\(.\{6\}\).....\(.*\)/\1$idx\2/" >> "$out"
                ;;
            ANISOU|TER*)
                # reuse previous index from previous ATOM line
                # NOTE: WE ASSUME that ANISOU and TER always follow the 
                # corresponding ATOM line
                idx=`printf "%5d" $i`
                echo "${label}${idx}${line:11}" >> "$out"
                #echo "$line" | sed -e "s/\(.\{6\}\).....\(.*\)/\1$idx\2/" >> "$out"
                ;;
            *) echo "$line" >> "$out" ;;
        esac
        if [ $((i % 1000)) -eq 1 ] ; then echo -n '.' ; fi
    done
    notecont "done"
}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname ${BASH_SOURCE[0]}`/lib	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash

    pdb_atom_renumber $*
else
    export PDB_ATOM_RENUMBER
fi
