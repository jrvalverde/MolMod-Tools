#
# NAME
#	make_topolgen_topology
#
# SYNOPSIS
#	make_topolgen_topology ligand.pdb charge
#
# DESCRIPTION
#	Create a topology for a ligand PDB file using topolgen.
#	Results will be saved in directory $ligand.topolgen
#
# AUTHOR
#	Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
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
#
MAKE_TOPOLGEN_TOPOLOGY='MAKE_TOPOLGEN_TOPOLOGY'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash


function make_topolgen_topology {
    #if [ $# -lt 1 ] ; then errexit "ligand.pdb" 
    #else notecont $* ; fi
    if ! funusage $# ligand.pdb ; then return $ERROR ; fi
    notecont $*

    warncont "TOPOLGEN IS UNRELIABLE, REVIEW ANY OUTPUT CAREFULLY"

    local mol=$1
    
    local dir=`dirname $mol`
    local fin="${mol##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    
    local babel=${babel:-`which babel`}
    local topolgen=${topolgen:-`which topolgen`}

    if [ ! "$ext" = "pdb" ] ; then
        warncont "Input file must be a PDB file."
        return $ERROR
    fi
    if [ ! -e $mol ] ; then
    	warncont "$mol does not exist"
	return $ERROR
    fi

    if [ -x "$topolgen" -a ! -e $lig.topolgen/$lig.oplsaa.itp ] ; then
        notecont "making OPLS-AA topology with $topolgen"
        notecont "expect 'Uknonw atom type' messages for non-existing"
	notecont "atom numbers"
        
	# use topolgen-1.3
        #	This should work almost always, it generates sensible
        #	parameters, but charges are empirically adjusted, not
        #	considering any possibly existing mol2 file.
        #	NOTE that topolgen needs a PDB file where all atoms are
        #	present, including H, defined as HETATM and full
        #	connectivity is given in CONECT records. Chimera
        #	will usually produce one such file. Babel will make
        #	one where ATOM is used instead of HETATM
        mkdir -p $lig.topolgen/
        cp $lig.pdb $lig.mol2 $lig.topolgen/
        cd $lig.topolgen/
        $topolgen -f $lig.pdb -o $lig.top -type top -renumber
        if [ ! -s $lig.itp ] ; then
            $topolgen -f $lig.pdb -o $lig.itp -type itp -renumber
        fi
	
	if [ ! -s $lig.itp ] ; then
	    warncont "make_topolgen_topology failed"
	    cd ..
	    return
	fi
	mv $lig.itp $lig.oplsaa.itp
        #
        if [ $? -eq 0 ] ; then
            if [ -e ../$lig.mol2 ] ; then
                # if a .mol2 file is available, prefer the charges in it:
                #	substitute charges in $lig.itp by those in mol2
                #	sed -n '/ATOM/,/BOND/p will extratc lines between 
                #		ATOM and BOND, these included
                #	print lines between ATOM and BOND deleting these two
                # this is terribly inefficient but works for now
                cp ../$lig.mol2 .
                cp $lig.oplsaa.itp $lig.oplsaa.itp.orig
                sed -n '/ATOM/,/BOND/{/ATOM/d;/BOND/d;p}' $lig.mol2 |
                while read no atom x y z typ n res charge ; do 
                    #echo "no=$no atom=$atom x=$x y=$y z=$z typ=$typ n=$n res=$res charge=$charge"
	            #sed "/ \+$res \+$atom/"'!d' $lig.itp | \
                    cat $lig.oplsaa.itp | \
                      sed -e "/ \+$res \+$atom/ s/^\(.\{50\}\).......\(.*\)$/\1$charge\2/g" \
                      > $lig.tmp
                    mv $lig.tmp $lig.oplsaa.itp
                done
            fi
            # Use ONLY if TopolGen does not set the molecule name in the 
            # [ moleculetype ] section:
	    # look for " moleculetype " section line, skip it, skip following
            # comment line and insert name at the beginning of the first line
            # in the section
            ##sed -e "/ moleculetype /{n;n;s/^/$lig/}" $lig.oplsaa.itp \
            ##    > $lig.tmp
            ##mv $lig.tmp $lig.oplsaa.itp
	else
            warncont "could not generate OPLS/AA topology with $topolgen"
	    cd -
	    return $ERROR
        fi
        cd -
    fi

    return $OK
}

# check if we are being executed directly
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash

    make_topolgen_topology $*
fi
