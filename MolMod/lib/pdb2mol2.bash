#!/bin/bash
#
# NAME
#	pdb2mol2 - convert a PDB file to Mol2 format assigning charges
#
# DESCRIPTION
#	Convert a PDB filt to mol2 format trying as many charge-computation
#	methods as possible.
#
#	Results will be saved as both, MOL2 and PDB files to ensure that
#	atom positions and names are kept in synchrony. The output files
#	will ne named according to the input file name followed by
#		.$method.pdb and $method.mol2
#
#	Currently supported methods (outside CNB/CSIC) include
#	    ab initio
#		none yet
#	    semiempirical
#		openmopac
#		chimera AM1/BCC
#	    empirical
#		babel (with --partialcharges, use babel -L charges for a list)
#
# AUTHOR
#	(C) Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#
#	Licensed under (at your option) either GNU/GPL or EUPL
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
PDB2MOL2='PDB2MOL2'

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include setup_cmds.bash
include util_funcs.bash
include pdb_atom_renumber.bash


function pdb2mol2 {
    #if [ $# -lt 1 ] ; then errexit "pdbfile [chargemethod]"
    #else notecont $* ; fi
    if ! funusage $# "pdbfile [chargemethod]" ; then return $ERROR ; fi
    notecont $*

    local mol=$1
    local charge=$2

    local openmopac=${openmopac:-'LD_LIBRARY_PATH=~/contrib/mopac ~/contrib/mopac/MOPAC2009'}
    local babel=${babel:-`which babel`}
    local chimera=${chimera:-`which chimera`}
    local ergoSCF=${ergoSCF:-`which ErgoSCF.bash`}
    local freeON=${freeON:-`which freeon.bash`}
    local gamessUS=${gamessUS:-`which gamess.sh`}
    local NWchem=${NWchem:-`which nwchem.bash`}
    local abinit=${abinit:-`which abinit.bash`}
    
    local dir=`dirname $mol`
    local fin="${mol##*/}"
    local ext="${fin##*.}"
    local lig="${fin%.*}"
    
    if [ ! "$ext" = "pdb" ] ; then
        warncont "Input file must be a PDB file."
        return $ERROR
    fi
    if [ ! -e $mol ] ; then
    	warncont "$mol does not exist"
	return $ERROR
    fi
    
    # Try to make a .mol2 file with charges from a PDB file
    if [ -e $lig.mol2 ] ; then 
        notecont "Using existing $lig.mol2"
        return $OK
    fi

    pushd `pwd`
    cd $dir
    # save all computed mol2 files in a subdirectory
    mkdir -p $lig.mmooll22
    cp $lig.pdb $lig.mmooll22
    cp $lig.pdb $lig.pdb.orig
    cd $lig.mmooll22

    # OpenMopac (this loses TRIPOS atomtypes and may pose a problem later).
    #
    # 	compute multiplicity
    # HEURISTIC: assume all charges are due to e- that yield unpaired spin
    #	ignore minus sign (i.e. take absolute value)
    local mult=$(( ${charge#-} + 1 ))
    #
    if [ ! -s "$lig.mopac.mol2" -a -x "$openmopac" -a -x "$babel" ] ; then
        notecont "trying to make a mol2 file with $openmopac"
        $babel -ipdb $lig.pdb -omopcrt $lig.mopcrt
    	sed -e "s/PUT KEYWORDS HERE/1SCF PM7 CHARGE=$charge MULLIK/g" $lig.mopcrt > $lig.mop
        LD_LIBRARY_PATH=`dirname $openmopac` $openmopac $lig.mop 
	mv $lig.out $lig.mopac.out ; mv $lig.arc $lig.mopac. arc
	
	# we cannot use babel to convert output to mol2 with newer
	# versions of OpenMopac, so we'll do it outselves
        #$babel -imopout $lig.out -omol2 $lig.mopac.mol2
	# openmopac may have changed atom order
	#$babel -imol2 $lig.mopac.mol2 -opdb $lig.mopac.pdb

	# extract the charge section from mopac output
	csplit -z $lig.mopac.out \
	    "%NET ATOMIC CHARGES%3" "/^ DIPOLE /" "%MOPAC DONE%1" \
	    -f $lig.mopac.chrg.
	    
	# charges are in $lig.mopac.chrg.00, use them
	sed -e 's/.*[A-Z)] *//g' -e 's/ .*//g' $lig.mopac.chrg.00 \
	    > $lig.mopac.chrg

        # Now generate a "dummy" mol2 file
	$babel -imopcrt $lig.mopcrt -omol2 $lig.mopac.mol2
	# remove charges from this file
	cat $lig.mopac.mol2 | sed -e "s/LIG1 .*/$lig      /g" > $lig.mopac.m2
        # split it into header, coordinates and tail
	csplit $lig.mopac.m2 -f $lig.mopac.m2. \
	    "/^@<TRIPOS>ATOM/1" "/^@<TRIPOS>BOND/"
        # this has generated three files, $lig.mopac.m2.01 is the one we
	# need now to insert the charges, we can rebuild and paste all at
	# once
	(cat $lig.mopac.m2.00 ; \
	    paste $lig.mopac.m2.01 $lig.mopac.chrg ; \
	    cat $lig.mopac.m2.02) \
	    > $lig.mopac.m2
	# attempt to clean up
	rm $lig.mopac.m2.* $lig.mopac.chrg*
	$babel -imol2 $lig.mopac.m2 -omol2 $lig.mopac.mol2
	$babel -imol2 $lig.mopac.m2 -opdb  $lig.mopac.pdb
    fi
    
    # in case OpenMopac failed and there is no user-supplied mol2 file, 
    # try to make one using Chimera and Antechamber:
    # add AM1-BCC charges with GAFF atom types and save as .mol2
    #
    if [ ! -s $lig.am1-bcc.mol2 -a -x "$chimera" ] ; then
        # try to assign charges using Chimera and antechamber
        enotecont "Attempting to asssign charges using Chimera with AM1/BCC"
        $chimera --nogui <<END
            open $lig.pdb
            #addh inisolation true hbond true
            addcharge all chargeModel 99sb method am1
            write format mol2 0 $lig.am1-bcc.mol2
            write format pdb  0 $lig.am1-bcc.pdb
            stop now
END
	# Chimera saves the molecule named as "$lig.pdb" in the mol2 file
        sed -e "s/$lig.pdb/$lig/g" $lig.am1-bcc.mol2 > $lig.tmp
        mv $lig.tmp $lig.am1-bcc.mol2
	# NOTE: review the output to check that all went as expected.
        #	If there is something wrong, CORRECT THE ORIGINAL PDB FILE.
    fi

    if [ -x "$babel" ] ; then
    	#for i in qtpie qeq eem mmff94 gasteiger ; do
        $babel -L charges | cut -f1 -d' ' | while read i ; do
	    notecont "assigning charges using babel $i"
            $babel -ipdb $lig.pdb --partialcharge $i -omol2 $lig.$i.mol2
	    # if we succeeded, then make a corresponding PDB as well
            if [ -s $lig.$i.mol2 ] ; then
                $babel -imol2 $lig.$i.mol2 -opdb $lig.$i.pdb
	    fi
        done
    fi
    
    if [ -x "$ergoSCF" ] ; then
        warncont "SORRY $ergoSCF support is only available at CNB/CSIC"
        
        # $babel -ipdb $lig.pdb -omol2 $lig.ergo.mol2
        # # check which basis sets are available for this ligand
        # #	we use an in-house ErgoSCF wrapper to facilitate work
        # #     we could use a drop back table to categorize basis
        # #     sets in order of accuracy and select the best available one
        # $ergoSCF -i $lig.ergo -b help > $lig.basis
        # if grep aug-cc-pCV5Z $lig.basis ; then basis=aug-cc-pCV5Z 
        # elif grep 6-311++Gss $lig.basis ; then basis=6-311++Gss
        # else basis='' ; fi
	# if "$basis" != '' ; then
        #     $ergoSCF -i $lig.ergo -c $charge -g STO-3G -b $basis
        # fi
        # rm $lig.basis
        # # use mol2 file
        # if [ -s $lig.ergo/$lig.STO-3G.$basis.mol2 ] ; then
        #     cp $lig.ergo/$lig.STO-3G.$basis.mol2 $lig.$basis.mol2
        # fi

    fi
    if [ -x "$freeON" ] ; then
        # our main problem here is to find out if all required atom
        # types are supported by the chosen basis set, we can do it like
	# in ergoSCF and FreeOn
        warncont "SORRY $freeON support is only available at CNB/CSIC"
    fi
    if [ -x "$fgamessUS" ] ; then
        # our main problem here is to find out if all required atom
        # types are supported by the chosen basis set
        warncont "SORRY $gamessUS support is only available at CNB/CSIC"
    fi
    if [ -x "$NWchem" ] ; then
        # our main problem here is to find out if all required atom
        # types are supported by the chosen basis set
        warncont "SORRY $NWchem support is only available at CNB/CSIC"
    fi
    
    # Now try to select the possibly best mol2 file and
    # copy it -and the matching PDB file- to the target directory
    #
    # we'll select them in the following hardcoded precedence
    #
    #	NOTE that ab initio do not normally take into account Dirac 
    #	relativistic effects, and so may be inaccurate for heavy metals
    if [ -s $lig.aug-cc-pCV5Z.mol2 ] ; then
        cp $lig.aug-cc-pCV5Z.mol2 ../$lig.mol2
        cp $lig.aug-cc-pCV5Z.pdb  ../$lig.pdb
        
    elif [ -s $lig.6-311++Gss.mol2 ] ; then
        cp $lig.6-311++Gss.mol2 ../$lig.mol2
        cp $lig.6-311++Gss.pdb  ../$lig.pdb
    
    # below this level, accuracy of DFT and SME QM often go hand in hand
    # semiempirical parametrization implicitly includes relativistic effects
    # but it may not support all the elements in the periodic table
    elif [ -s $lig.mopac.mol2 ] ; then
	cp $lig.mopac.mol2 ../$lig.mol2
        cp $lig.mopac.pdb  ../$lig.pdb
    
    elif [ -s $lig.am1-bcc.mol2 ] ; then
        cp $lig.am1-bcc.mol2 ../$lig.mol2
        cp $lig.am1-bcc.pdb  ../$lig.pdb
    
    # next come empirical methods implemented in babel
    elif [ -s $lig.qtpie.mol2 ] ; then
        cp $lig.qtpie.mol2 ../$lig.mol2
        cp $lig.qtpie.pdb  ../$lig.pdb
    
    elif [ -s $lig.qeq.mol2 ] ; then
        cp $lig.qeq.mol2 ../$lig.mol2
        cp $lig.qeq.pdb  ../$lig.pdb
    
    elif [ -s $lig.eem.mol2 ] ; then
        cp $lig.eem.mol2 ../$lig.mol2
        cp $lig.eem.pdb  ../$lig.pdb
    
    elif [ -s $lig.mmff94.mol2 ] ; then
        cp $lig.mmff94.mol2 ../$lig.mol2
        cp $lig.mmff94.pdb  ../$lig.pdb
    
    elif [ -s $lig.gasteiger.mol2 ] ; then
        cp $lig.gasteiger.mol2 ../$lig.mol2
        cp $lig.gasteiger.pdb  ../$lig.pdb
    
    else
        warncont "Couldn't make a mol2 file for $lig"
        warncont "this should be exceedingly rare"
	popd
        return $ERROR
    fi
    
    popd
    return $OK
}

# check if we are being executed directly
my_name=$0
my_file=$BASH_SOURCE
if [[ $my_name == $my_file ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
    source $LIB/include.bash
    include setup_cmds.bash
    include util_funcs.bash
    include pdb_atom_renumber.bash

    pdb2mol2 $*
fi
