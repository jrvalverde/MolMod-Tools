#!/bin/bash
#
# NAME
#	gmx_gro_to_pdb - convert from GROMACS .gro to PDB format
#
# SYNOPSIS
#	gmx_gro_to_pdb [gro_name] [subset]
#
# DESCRIPTION
#	Convert from a GROMACS structure .gro file to a PDB format file,
# optionally extracting only a part of the structure.
#
#	If no arguments are given, the whole structure is converted.
# A tpr file must exist in order to get the topology right. Otherwise
# information on bonds and chains may be missing from the output PDB. 
# If an index file exists it will be used.
#
#	A subset to be converted can be specified using an identifier
# for the subset from the index file.
#
# ARGUMENTS
#	name	- the name of the .gro file without the extension
#	subset	- an optional name for the subset to save
#
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


GMX_GRO_TO_PDB="GMX_GRO_TO_PDB"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash


function gmx_gro_to_pdb() {
    if ! funusage $# [gro_name] [subset] ; then return $ERROR ; fi 
    notecont "$*"

    local name=${1:-system}
    local subset=${2:-System}
    
    local tpr=''
    local out=''
    local index=''
    local ERR=1
    
	name=${name%.gro}	# remove extension to get base name
	
    if [ -s "${name}".gro ] ; then
        gro="${name}".gro
    else
        warncont "${name}.gro does not exist"
        return $(( ERR++ ))
    fi

    if [ -s "${name}".tpr ] ; then
        tpr="${name}".tpr
    else
        warncont "no ${name}.tpr"
    fi

    if [ "$subset" = "System" -o $tpr='' ] ; then
        out="$name.pdb"
    else
        out="$name"_"$subset".pdb
    fi
    
    if [ -s "${name}".ndx ] ; then
        index="-n ${name}.ndx"
    else
        index=''
    fi

    if [ -s "$out" ] ; then
        warncont "$out already exists"
        return  $(( ERR++ ))
    fi
	
    if [ "$tpr" = '' ] ; then
        gmx editconf -f "$gro" -o "$out" -pbc true
    else
	echo "$subset" \
	| gmx trjconv \
            -s "$tpr" \
            -f "$gro" \
            -o "$out" \
            -pbc whole \
            -conect \
            $index
        
	# -pbc whole => make all broken molecules whole
    # -pbc mol => put center of mass of molecules in the box
    # -pbc res => put center of mass of residues in the box
    fi
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
	include setup_cmds.bash

    gmx_gro_to_pdb $*
else
    export GMX_GRO_TO_PDB
fi
