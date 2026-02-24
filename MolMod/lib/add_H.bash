#!/bin/bash
#
# NAME
#	add_H - add hydrogens to a PDB file
#
# SYNOPSIS
#	add_H input.pdb method pH
#
# DESCRIPTION
#	Adds hydrogens to the specified input file using one of a number
#	of methods. The supported methods are
#		babel chimera reduce haad gromacs none
#
#	The available methods will depend on the existence of the required
#	external programs. At a minimum, 'none' (do not add H) is always
# 	available.
#
#	Currently, the recommended methods are chimera or reduce
#
#	pH is optional, defaults to 7.365 and is only used by 'babel'
#
#	At the end, you will get two files named after the input file,
#		$input-H.pdb	- the input file without H
#		$input+H.pdb	- the input file with the added H (if any)
#
#	It relies on external variables to locate auxiliary programs, but
#	tries to provide sensible defaults in case these external variables
#	are not defined. It also relies on the existence of a WATER global
#	variable to use if the 'gromacs' method is selected.
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
ADD_H='ADD_H'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include util_funcs.bash
include pdb_atom_renumber.bash


function add_H() {
    #if [ $# -lt 1 ] ; then error "file.pdb [method] [pH]" 
    #else notecont $* ; fi
    if ! funusage $# file.pdb [method] [pH] ; then return $ERROR ; fi 
    notecont $*
    local pdb=$1
    local method=${2:-'none'}
    local pH=${3:-'7.365'}
    
    # provide defaults for external variables
    local chimera=${chimera:-`which chimera`}
    local babel=${babel:-`which babel`}
    local reduce=${reduce:-`which reduce`}
    local haad=${haad:-`which haad`}
    local ff=${ff:-opls-aa}
    #local WATER=${WATER:-'spc'}	# this would be a more sensible general default, but if we set ff to opls-aa then tip4p is what corrresponds to it
    local WATER=${WATER:-'tip4p'}
    local chargeModel=${chargeModel:-'99sb'}
    if [ "$chargeModel" = "default" ] ; then chargeModel='99sb' ; fi

    if [ "$method" == "help" ] ; then
        echo "add_H input.pdb {method} {pH}"
        echo "	method is optional and can be any of"
        echo "		babel, chimera, reduce, haad, gromacs, none"
        echo "	pH is optional, only used by babel, and defaults to 7.365"
        echo "  this will generate input-H.pdb and input+H.pdb"
        echo ""
		return $OK
    fi
    
    notecont ">>> add_H: adding H to $pdb using $method at a pH of $pH"

    if [ ! -e "$pdb" ] ; then
        warncont "$1 not found" ; return $ERROR
    fi
    
    # dissect input file name
    local dir=`dirname $pdb`
    local fin="${pdb##*/}"
    local ext="${fin##*.}"
    local nam="${fin%.*}"
    
    if [ ! "$ext" == "pdb" -a ! "$ext" == "brk" ] ; then
        warncont "Input file must be a PDB file."
        return $ERROR
    fi

    # work on input file directory
    cd $dir
    if [ ! -e ${nam}-H.pdb -o ! -e ${nam}+H.pdb ] ; then
        #
        # remove all H (we'll re-add them to suit our desired pH)
        #
        grep -v ".\{76\} H\b" $fin | \
        grep -v "^CONECT " | \
        grep -v "^WARNING" \
	    > ${nam}-H.pdb
        if [ $method == 'babel' -a -x "$babel" ] ; then
	  if [ "YES" = "YES" ] ; then
    	    notecont "Adding H using OpenBabel ($babel) at pH $pH"
            # Add H at a pH of 7.365 (default) computing Gasteiger charges
            #	NOTE: babel will add all H at the end of the
            #	PDB file, all called H, leaving an unsorted
            #	PDB without specific H atom names.
            #	CAVEAT: if there are no CONECT records (e.g.
            #	after docking) then babel might possibly add H
            #	to the wrong atoms.
	    #	WARNING: TRY TO AVOID THIS AS A GENERAL RULE
	    local charges="gasteiger" # or "mmff94" or "eem"
	    $babel -h -p $pH --center --partialcharge $charges \
                  -ipdb ${nam}-H.pdb -opdb ${nam}+H.pdb
	  else
	    add_H_babel ${nam}-H.pdb $pH
	  fi
        elif [ $method == 'chimera' -a -x "$chimera" ] ; then
	  if [ "YES" == "YES" ] ; then
            notecont "Adding H using UCSF Chimera"
            #
            # Add H using Chimera. It will often do the right thing
            #	When no CONECT records are available, Chimera may
            #	be able to recognize some hetero groups (like nucleic
            #	acids).
            #
            $chimera --nogui <<END
            	open ${nam}-H.pdb
            	addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
            	addcharge all chargeModel $chargeModel method gasteiger
            	write format pdb 0 ${nam}+H.pdb
                stop now
END
	  else
	    add_H_chimera ${nam}-H.pdb
	  fi
    elif [ $method == 'reduce' -a -x "$reduce" ] ; then
	    # Add H using Kinemage reduce
	    # 	When no CONECT records are available, reduce can
	    #	use a database of hetero-compounds to recognize
	    #   many of them
	    #
            notecont "Adding H using reduce"
            $reduce  -build ${nam}-H.pdb > ${nam}.H.pdb 
            pdb_atom_renumber ${nam}.H.pdb ${nam}+H.pdb
            rm $nam.H.pdb
    elif [ $method == 'haad' -a -x "$haad" ] ; then
	    # Add H using HAAD
	    #
            notecont "Adding H using HAAD"
	    notecont " "
            notecont "As a general rule you should avoid using HAAD"
            notecont "HAAD SHOULD BE RESERVED FOR SYSTEMS WITH ONLY"
	    notecont "A SINGLE PROTEIN CHAIN"
            notecont " "
            # sanity checks: HAAD CANNOT ADD H TO HETERO COMPOUNDS
            #	HAAD ONLY WORKS FOR PROTEINS
            #	NOTE: THE SECOND TEST (WC) SHOULD NOT BE NEEDED
            #grep -q "^HETATM" $nam.pdb || [[ `wc -l < "$ligands"` != "0" ]] && \
            grep -q "^HETATM" $nam.pdb &&
            	warncont "HAAD only works for ONE protein chain" ; \
                warncont "ANY OTHER CHAINS OR LIGANDS WILL BE DELETED"

            $haad ${nam}-H.pdb
            mv ${nam}-H.pdb.h $nam.H.pdb
            pdb_atom_renumber ${nam}.H.pdb ${nam}+H.pdb
            rm ${nam}.H.pdb
    elif [ $method == 'gromacs' ] ; then
            # Add H using Gromacs
	    #	Like babel, it is unable to recognize most ligands
	    #	but unlike babel, at least it will place H in the
	    #	file in suitable positions.
	    #
            #	NOTE: for OPLS-AA we should use TIP4P water
	    notecont "Adding H using gromacs"
        $pdb2gmx -ff $ff -f ${nam}-H.pdb -o ${nam}+H.pdb \
                    -p ${nam}+H.top \
	            -water $WATER -chainsep id_or_ter
        if [ $? -ne 0 ] ; then return $ERROR ; fi
    else
	    # method = 'none', unknown, or undefined
	    #	Do not add H. The user guarantees that the H are all
	    #	correct and present, hopefully because s/he has added
	    #	and manually verified them before invoking us.
	    #
        notecont "Using original geometry as is"
        # no H to add, use input structure 'as is'
        egrep  '(^ATOM)|(^HETATM)|(^CONECT)|(^TER)' ${nam}.pdb > ${nam}+H.pdb
	fi
    else
        notecont "using ${nam}-H and ${nam}+H from a previous run"
    fi

    notecont "${nam}-H and ${nam}+H created"

    # return to wherever we were formerly
    cd -
    return $OK

}

function add_H_babel {
    if ! funusage $# file.pdb ; then return $ERROR ; fi
    notecont $*
    #if [ $# -ne 1 ] ; then errexit "file.pdb" 
    #else notecont $* ; fi

    local pdb=$1
    local charges=$2
    local ext="${input##*.}"
    local nam="${in%.*}"
    if [ "$ext" != "pdb" -o "$ext" != "brk" ] ; then
        warncont "$pdb doesn't seem to be a PDB file"
        return $ERROR
    fi

    notecont "Adding H to $pdb using OpenBabel"
    # Add H at a pH of 7.365 computing Gasteiger charges
    #	NOTE: babel will add all H at the end of the
    #	PDB file, all called H, leaving an unsorted
    #	PDB without specific H atom names.
    #	CAVEAT: if there are no CONECT records (e.g.
    #	after docking) then babel might possibly add H
    #	to the wrong atoms.
    charges="gasteiger" # or "mmff94" or "eem"
    $babel -h -p 7.365 --center --partialcharge $charges \
          -ipdb $pdb -opdb ${nam}+H.pdb
}

function add_H_chimera() {
    if ! funusage $# file.pdb ; then return $ERROR ; fi
    notecont $*
    #if [ $# -ne 1 ] ; then errexit "file.pdb" 
    #else notecont $* ; fi

    local pdb=$1
    local ext="${input##*.}"
    local nam="${in%.*}"
    
    # set defaults for globals
    local chargeModel=${chargeModel:-'99sb'}
    if [ "$chargeModel" = "default" ] ; then chargeModel='99sb' ; fi

    if [ "$ext" != "pdb" -o "$ext" != "brk" ] ; then
        warncont "$pdb doesn't seem to be a PDB file"
        return $ERROR
    fi
    notecont "Adding H to $pdb using UCSF Chimera"
    #
    # Add H using Chimera. It will often do the right thing
    #	When no CONECT records are available, Chimera might
    #	be able to recognize some hetero groups (like nucleic
    #	acids).
    #
    $chimera --nogui <<END
        open $pdb
        addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
        addcharge all chargeModel $chargeModel method gasteiger
        write format pdb 0 ${nam}+H.pdb
        stop now
END

}


#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    # [[ -v VAR ]] tests if a variable is set
    # [[ -z "$VAR" ]] tests if length of $VAR is zero
    LIB=`dirname $0`
    source $LIB/include.bash
    include util_funcs.bash
    include pdb_atom_renumber.bash

    add_H $*
else
    export ADD_H
fi
