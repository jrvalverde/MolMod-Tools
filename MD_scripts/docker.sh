#!/bin/bash
#
# NAME
#	docker - dock one or more ligands in a receptor
#
# SYNOPSIS
#	docker master.(pdb+mol2) ligand1.mol2 known.mol2 
#
#	docker will prepare the specified receptor from the master file
#	master.pdb, it will use known.mol2 as a reference to define the
#	binding site if available and not empty, and then dock the ligand
#	to the receptor.
#
#	If known.mol2 is empty, then the largest cavity will be used.
#
#	If known.mol2 is not specified, then the "master" receptor will
#	be screened for possible ligands, these will be extracted and
#	the user will be given an opportunity to choose one.
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


# NAME
# 	banner - print large banner
#
# SYNOPSIS
#	banner text
#
# DESCRIPTION
#	banner prints out the first 10 characters of "text" in large letters
#
function banner {
    #
    # Taken from http://stackoverflow.com/questions/652517/whats-the-deal-with-the-banner-command
    #
    #	Msg by jlliagre
    #		Apr 15 '12 at 11:52
    #
    # ### JR ###
    #	Input:	A text up to 10 letter wide
    # This has been included because banner(1) is no longer a standard
    # tool in many Linux systems. This way we avoid having a dependency
    # that might not be met.
    # It is often installed through package 'sysvbanner'
    #	npm has an ascii-banner tool (npm -g install ascii-banner)
    # Other alternatives are toilet(1) and figlet(1)

    typeset A=$((1<<0))
    typeset B=$((1<<1))
    typeset C=$((1<<2))
    typeset D=$((1<<3))
    typeset E=$((1<<4))
    typeset F=$((1<<5))
    typeset G=$((1<<6))
    typeset H=$((1<<7))

    function outLine
    {
      typeset r=0 scan
      for scan
      do
        typeset l=${#scan}
        typeset line=0
        for ((p=0; p<l; p++))
        do
          line="$((line+${scan:$p:1}))"
        done
        for ((column=0; column<8; column++))
          do
            [[ $((line & (1<<column))) == 0 ]] && n=" " || n="#"
            raw[r]="${raw[r]}$n"
          done
          r=$((r+1))
        done
    }

    function outChar
    {
        case "$1" in
        (" ") outLine "" "" "" "" "" "" "" "" ;;
        ("0") outLine "BCDEF" "AFG" "AEG" "ADG" "ACG" "ABG" "BCDEF" "" ;;
        ("1") outLine "F" "EF" "F" "F" "F" "F" "F" "" ;;
        ("2") outLine "BCDEF" "AG" "G" "CDEF" "B" "A" "ABCDEFG" "" ;;
        ("3") outLine "BCDEF" "AG" "G" "CDEF" "G" "AG" "BCDEF" "" ;;
        ("4") outLine "AF" "AF" "AF" "BCDEFG" "F" "F" "F" "" ;;
        ("5") outLine "ABCDEFG" "A" "A" "ABCDEF" "G" "AG" "BCDEF" "" ;;
        ("6") outLine "BCDEF" "A" "A" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("7") outLine "BCDEFG" "G" "F" "E" "D" "C" "B" "" ;;
        ("8") outLine "BCDEF" "AG" "AG" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("9") outLine "BCDEF" "AG" "AG" "BCDEF" "G" "G" "BCDEF" "" ;;
        ("a") outLine "" "" "BCDE" "F" "BCDEF" "AF" "BCDEG" "" ;;
        ("b") outLine "B" "B" "BCDEF" "BG" "BG" "BG" "ACDEF" "" ;;
        ("c") outLine "" "" "CDE" "BF" "A" "BF" "CDE" "" ;;
        ("d") outLine "F" "F" "BCDEF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("e") outLine "" "" "BCDE" "AF" "ABCDEF" "A" "BCDE" "" ;;
        ("f") outLine "CDE" "B" "B" "ABCD" "B" "B" "B" "" ;;
        ("g") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "BCDE" ;;
        ("h") outLine "B" "B" "BCDE" "BF" "BF" "BF" "ABF" "" ;;
        ("i") outLine "C" "" "BC" "C" "C" "C" "ABCDE" "" ;;
        ("j") outLine "D" "" "CD" "D" "D" "D" "AD" "BC" ;;
        ("k") outLine "B" "BE" "BD" "BC" "BD" "BE" "ABEF" "" ;;
        ("l") outLine "AB" "B" "B" "B" "B" "B" "ABC" "" ;;
        ("m") outLine "" "" "ACEF" "ABDG" "ADG" "ADG" "ADG" "" ;;
        ("n") outLine "" "" "BDE" "BCF" "BF" "BF" "BF" "" ;;
        ("o") outLine "" "" "BCDE" "AF" "AF" "AF" "BCDE" "" ;;
        ("p") outLine "" "" "ABCDE" "BF" "BF" "BCDE" "B" "AB" ;;
        ("q") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "FG" ;;
        ("r") outLine "" "" "ABDE" "BCF" "B" "B" "AB" "" ;;
        ("s") outLine "" "" "BCDE" "A" "BCDE" "F" "ABCDE" "" ;;
        ("t") outLine "C" "C" "ABCDE" "C" "C" "C" "DE" "" ;;
        ("u") outLine "" "" "AF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("v") outLine "" "" "AG" "BF" "BF" "CE" "D" "" ;;
        ("w") outLine "" "" "AG" "AG" "ADG" "ADG" "BCEF" "" ;;
        ("x") outLine "" "" "AF" "BE" "CD" "BE" "AF" "" ;;
        ("y") outLine "" "" "BF" "BF" "BF" "CDE" "E" "BCD" ;;
        ("z") outLine "" "" "ABCDEF" "E" "D" "C" "BCDEFG" "" ;;
        ("A") outLine "D" "CE" "BF" "AG" "ABCDEFG" "AG" "AG" "" ;;
        ("B") outLine "ABCDE" "AF" "AF" "ABCDE" "AF" "AF" "ABCDE" "" ;;
        ("C") outLine "CDE" "BF" "A" "A" "A" "BF" "CDE" "" ;;
        ("D") outLine "ABCD" "AE" "AF" "AF" "AF" "AE" "ABCD" "" ;;
        ("E") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "ABCDEF" "" ;;
        ("F") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "A" "" ;;
        ("G") outLine "CDE" "BF" "A" "A" "AEFG" "BFG" "CDEG" "" ;;
        ("H") outLine "AG" "AG" "AG" "ABCDEFG" "AG" "AG" "AG" "" ;;
        ("I") outLine "ABCDE" "C" "C" "C" "C" "C" "ABCDE" "" ;;
        ("J") outLine "BCDEF" "D" "D" "D" "D" "BD" "C" "" ;;
        ("K") outLine "AF" "AE" "AD" "ABC" "AD" "AE" "AF" "" ;;
        ("L") outLine "A" "A" "A" "A" "A" "A" "ABCDEF" "" ;;
        ("M") outLine "ABFG" "ACEG" "ADG" "AG" "AG" "AG" "AG" "" ;;
        ("N") outLine "AG" "ABG" "ACG" "ADG" "AEG" "AFG" "AG" "" ;;
        ("O") outLine "CDE" "BF" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("P") outLine "ABCDE" "AF" "AF" "ABCDE" "A" "A" "A" "" ;;
        ("Q") outLine "CDE" "BF" "AG" "AG" "ACG" "BDF" "CDE" "FG" ;;
        ("R") outLine "ABCD" "AE" "AE" "ABCD" "AE" "AF" "AF" "" ;;
        ("S") outLine "CDE" "BF" "C" "D" "E" "BF" "CDE" "" ;;
        ("T") outLine "ABCDEFG" "D" "D" "D" "D" "D" "D" "" ;;
        ("U") outLine "AG" "AG" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("V") outLine "AG" "AG" "BF" "BF" "CE" "CE" "D" "" ;;
        ("W") outLine "AG" "AG" "AG" "AG" "ADG" "ACEG" "BF" "" ;;
        ("X") outLine "AG" "AG" "BF" "CDE" "BF" "AG" "AG" "" ;;
        ("Y") outLine "AG" "AG" "BF" "CE" "D" "D" "D" "" ;;
        ("Z") outLine "ABCDEFG" "F" "E" "D" "C" "B" "ABCDEFG" "" ;;
        (".") outLine "" "" "" "" "" "" "D" "" ;;
        (",") outLine "" "" "" "" "" "E" "E" "D" ;;
        (":") outLine "" "" "" "" "D" "" "D" "" ;;
        ("!") outLine "D" "D" "D" "D" "D" "" "D" "" ;;
        ("/") outLine "G" "F" "E" "D" "C" "B" "A" "" ;;
        ("\\") outLine "A" "B" "C" "D" "E" "F" "G" "" ;;
        ("|") outLine "D" "D" "D" "D" "D" "D" "D" "D" ;;
        ("+") outLine "" "D" "D" "BCDEF" "D" "D" "" "" ;;
        ("-") outLine "" "" "" "BCDEF" "" "" "" "" ;;
        ("*") outLine "" "BDF" "CDE" "D" "CDE" "BDF" "" "" ;;
        ("=") outLine "" "" "BCDEF" "" "BCDEF" "" "" "" ;;
        (*) outLine "ABCDEFGH" "AH" "AH" "AH" "AH" "AH" "AH" "ABCDEFGH" ;;
        esac
    }

    function outArg
    {
      typeset l=${#1} c r
      for ((c=0; c<l; c++))
      do
        outChar "${1:$c:1}"
      done
      echo
      for ((r=0; r<8; r++))
      do
        printf "%-*.*s\n" "${COLUMNS:-80}" "${COLUMNS:-80}" "${raw[r]}"
        raw[r]=""
      done
    }

    for i
    do
      outArg "$i"
      echo
    done
}

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


# NAME
#	strindex - lookup in a string a substring
#
# SYNOPSIS
#	strindex "a large string" "string"
#
# DESCRIPTION
#	strindex returns the position of the substring in the larger
#	string, if found, or -1 if it is not present
#
function strindex() { 
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
    # Expect a PDB input file name as first argument and an output file as
    # second argument
    local pdb=$1
    local out=${2:-$pdb.renum}

    echo "pdb_atom_renumber: renumbering $pdb to $out"
    if [ ! -e $pdb ] ; then
        echo "pdb_atom_renumber: $1 not found" 
        return $ERROR
    fi

    local dir=`dirname $pdb`
    local fin="${pdb##*/}"
    local ext="${fin##*.}"
    local nam="${fin%.*}"
    if [ ! "$ext" == "pdb" -a ! "$ext" == "brk" ] ; then
        echo "pdb_atom_renumber ERROR: Input file must be a PDB file."
        return $ERROR
    fi
    
    local entries="(^ATOM  )|(^TER   )|(^TER)|(^ANISOU)|(^HETATM)"
    echo -n "" > "$out"	# truncate any previously existing $pdbout
    i=1
    cat $pdb | while read line ; do
        #echo "LINE! $line"
	echo "$line" | egrep -cq "$entries" > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
            idx=`printf "%5d" $i`
            echo "$line" | sed -e "s/\(.\{6\}\).....\(.*\)/\1$idx\2/" >> "$out"
            i=$((i+1))
        else
            # check ENDMDL and reset counter
	    [[ `strindex $line "ENDMDL"` -eq "0" ]] && i=1 # && echo "BINGO!"
            echo "$line" >> "$out"
        fi
    done
}

function docker {
    local master=$1
    local ligands=$2
    local known=$3

    #   this is the leeway we allow around the reference ligand for docking
    #   other molecules
    #	If you modify this, then modify as well box size, grid spacing or
    # 	maxpts
    local radius=5.0
    #local radius=10.0
    #local radius=15.0
    #local radius=30.0

    local chimerabin=~/contrib/chimera/bin
    local dock6dir=~/contrib/dock6
    local dock6bin=$dock6dir/bin
    local pdbtools=~/contrib/pdb-tools
    local obabelbin=~/contrib/openbabel/bin
    #
    # this is used for special, large memory versions of some DOCK6 tools
    #
    local jrbin=~/contrib/jr/bin

    local PATH=$jrbin:$dock6bin:$chimerabin:$pdbtools:$obabelbin:$PATH

    if [ ! -s $master ] ; then exit ; fi
    local receptor=$master
    
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

    if [ "$known" != "" -a -e "$known" ] ; then
        # we allow KNOWN to be empty to force and unknown binding site
        local kext="${known##*.}"
        local knam="${known%.*}"
        local kok=`realfile $known`
        if [ "$kext" != "mol2" ] ; then
    	    echo "ERROR: Reference $known must be in a MOL2 file"
            return 1
        fi
    fi

    # 01_dockprep
    # ===========
    # RECEPTOR PREPARATION
    # --------------------
    # 
    #    DONE BY HAND
    # 
    # 2GSZ structure was processed with Chimera using DockPrep, removing ADP,
    # non-complexed ions, assigning Gasteiger charges and saved in 
    # 01_dockprep/rec.* both as mol2 and PDB
    # 
    # The known ligand (ADP) was saved with unmodified coordinates to 
    # 01_dockprep/knl.* both as mol2 and PDB

    banner ' dockprep '
    if [ ! -d 01_dockprep ] ; then mkdir 01_dockprep ; fi

    # if there is a receptor, install it
    # MASTER exists and is a PDB and/or MOL2 file
    if [ -s $rnam.mol2 ] ; then
        cp $rnam.mol2 01_dockprep/rec.mol2
    else
       # must be PDB
       babel -ipdb $rnam.pdb -omol2 01_dockprep/rec.mol2
    fi
    if [ -s $rnam.pdb ] ; then
        cp $rnam.pdb 01_dockprep/rec.pdb
    else
        # must be a mol2
        babel -imol2 $rnam.mol2 -opdb 01_dockprep/rec.pdb 
    fi

    # if there is a reference, install it
    if [ "$known" != "" ] ; then
        # KNOWN exists and is a (possible empty) mol2 file
        cp $known 01_dockprep/knl.mol2
        if [ -s $knam.pdb ] ; then
            # this test is to avoid wrongfully copying an empty PDB for
            # a non-empty ligand
            cp $known 01_dockprep/knl.pdb
        elif [ -s $knam.mol2 ] ; then
            babel -imol2 $knam.mol2 -opdb 01_dockprep/knl.pdb 
	else
            # known is an empty file to flag an unknown pocket
            touch 01_dockprep/knl.pdb
        fi
    fi

    cd 01_dockprep

    # UNUSED AT THIS POINT
    #	The reason is that, as it is, it will delete ligands. But it is
    #	possible that we do want to keep them (e.g. to dock an additional
    #	ligand to a pre-existing complex). We need to think about the
    #	best approach.
    #
    #	Most likely, if knl.mol2 is not empty, we can get rid of ligands
    #	because we already have a reference to identify the binding site
    #
    #	But, what about ions? What if we do not know the pocket? The
    #   best approach would be to process the command line and have 
    #	special options to control this.
    #
    if [ "$DOCKPREP_CLEAN_RECEPTOR" = "yes" ] ; then
        # extract from MASTER the receptor and prepare it for docking
	cat > dockprep.py <<END
            import chimera
            from DockPrep import prep
            models = chimera.openModels.list(modelTypes=[chimera.Molecule])
            #prep(models,    addHFunc=AddH.hbondAddHydrogens, hisScheme=None, 
            #                mutateMSE=True, mutate5BU=True, mutateUMS=True, mutateCSL=True,
            #                delSolvent=True, delIons=False, delLigands=False, 
            #                delAltLocs=True, incompleteSideChains="rotamers", nogui=False, 
            #                rotamerLib=defaults[INCOMPLETE_SC], rotamerPreserve=True)
            prep(models, delIons=True, delLigands=True)
            from WriteMol2 import writeMol2
            writeMol2(models, "rec.mol2")
            import Midas
            Midas.write(models, None, "rec.pdb")
END
	chimera --nogui `basename $master` dockprep.py &> dockprep.log
    fi

    while [ ! -s rec.pdb -o ! -s rec.mol2 ] ; do
        echo "
    Please, process the receptor using DockPrep, removing the known ligand 
    (if any), non-complexed ions, assigning Gasteiger charges and save 
    as both, a PDB and a mol2 file, using the names
        rec.mol2	    -- the receptor in mol2 format
        rec.pdb 	    -- the receptor in PDB format
        knl.mol2	    -- the known ligand (if any) in mol2 format
        knl.pdb 	    -- the known ligand (if any) in PDB format
    
    If you do not want to continue, press [Ctrl]+[C] and exit UCSF Chimera.
    "
        chimera `basename $master`
    done
    echo "receptor molecule saved in 01_dockprep/rec.pdb"
    echo "charged receptor molecule saved in 01_dockprep/rec.mol2"
    cd ..


    # 02_noH
    # ======
    # GENERATE RECEPTOR WITHOUT H
    # ---------------------------
    # 
    # PDB versions of the structures without the H atoms are generated 
    # using grep and pdb-tools (to renumber atoms) using:

    banner '   no H   '
    if [ ! -d 02_noH ] ; then mkdir 02_noH ; fi
    cp 01_dockprep/*.pdb 02_noH
    cd 02_noH

    for i in rec.pdb ; do 
        if [ ! -e `basename $i .pdb`_noH.pdb ] ; then
            grep -v '^ATOM *[0-9]* *H' $i > zzz.pdb
            pdb_atom_renumber zzz.pdb \
    	        `basename $i .pdb`_noH.pdb
        fi
        echo $i H stripped into 02_noH/`basename $i .pdb`_noH.pdb
    done
    rm -f zzz.pdb
    cd ..

    # 03_molsurf
    # ==========
    # GENERATE RECEPTOR MOLECULAR SURFACES
    # ------------------------------------
    # 
    # Once  the rec_noH.pdb file has been generated, compute its molecular surface

    banner ' mol surf '
    if [ ! -d 03_molsurf ] ; then mkdir 03_molsurf ; fi
    if [ ! -s 02_noH/rec_noH.pdb ] ; then
	    echo "ERROR: 02_noH/rec_noH.pdb does not exist!"
	    if [ ! -e 01_dockprep/rec.pdb ] ; then
		    echo "       01_dockprep/rec.pdb does not exist either!"
		    echo "       Please, ensure rec.pdb containing the prepared receptor exists!"
	    else
		    echo "       Please, revise the rec.pdb file for correctness!"
	    fi
	    exit
    fi
    cp 02_noH/rec_noH.pdb 03_molsurf
    cd 03_molsurf

    for i in rec_noH.pdb ; do
        if [ ! -s `basename $i _noH.pdb`.dms ] ; then
            $chimerabin/dms $i -n -w 1.4 -v -o \
                `basename $i _noH.pdb`.dms
        fi
        echo $i surface saved as 03_molsurf/`basename $i _noH.pdb`.dms
    done
    cd ..

    # 04_sphgen
    # =========
    # GENERATE RECEPTOR SURROUNDING SPHERES
    # -------------------------------------
    # 
    # Spheres surrounding the receptor were generated and named 'rec.sph' using
    # a modified version of SPHGEN (270 format statement modified to allow bigger
    # numbers of spheres in temp2.sph as default 2i5 was not enough on some
    # molecules, and 15 and 355 statements for similar reasons in temp3.atc).

    banner '  sphgen  '
    if [ ! -d 04_sphgen ] ; then mkdir 04_sphgen ; fi
    if [ ! -s 03_molsurf/rec.dms ] ; then
	    echo "ERROR: 03_molsurf/rec.dms does not exist!"
	    echo "       Please check that the molecular surface was computed properly"
	    exit
    fi
    cp 03_molsurf/rec.dms 04_sphgen
    cd 04_sphgen

    if [ ! -s rec.sph ] ; then
	    echo -n "$j .. "

        rm -f rec.sph temp* OUTSPH
        for i in *.dms ; do
            cat > INSPH<<END
$i
R
X
0.0
4.0
1.5
rec.sph
`basename $i .dms`.sph
END
            $jrbin/jrsphgen 
#           mv OUTSPH `basename $i .dms`.OUTSPH
        done
    fi
    echo "rec.dms spheres calculated into 04_sphgen/rec.sph"
    cd ..

    # NOTE: for some structures the contributed programs sphgen_cpp and
    # sphgen_cpp_threads had to be used instead to overcome limitations 
    # in the original sphgen.


    # 05_sitsph
    # =========
    # SELECT BINDING SITE SPHERES
    # ---------------------------
    # 
    # For many of the proteins, the binding site(s) is/are known and
    # available on the original PDB file. To select the putative binding
    # site we must therefore:
    # 
    #     - open original PDB file
    #     - select ligand(s)
    #     - invert selection
    #     - delete everything else
    #     - save as knownligand.mol2
    #     - select all spheres within $radius Angstrom of the known ligand(s):
    #     sphere_selector sphgen_sphere_cluster_file.sph set_of_atoms_file.mol2 radius
    # 
    # This can be automated too using chimera --nogui:

    banner "  sitsph  "
    if [ ! -d 05_sitsph ] ; then mkdir 05_sitsph ; fi
    if [ ! -s 04_sphgen/rec.sph ] ; then
        echo "ERROR: no rec.sph spheres generated."
        echo "       cannot pick site spheres!"
        exit
    fi
    cp 04_sphgen/rec.sph 05_sitsph
    cp $master 05_sitsph

    # just in case there is a known reference ligand to use
    #	(an empty knl.mol2 signals we do NOT want any reference)
    if [ -e 01_dockprep/knl.mol2 ] ; then
        echo "01_dockprep/knl.mol2 found. Using it as the reference ligand"
        cp 01_dockprep/knl.mol2 05_sitsph
    fi

    cd 05_sitsph

    if [ ! -e knl.mol2 ] ; then
        # if we have no known ligand, look for one
        # an empty knl.mol2 file implies "USE THE BIGGEST POCKET"
        #
        #	NOTE: if a molecule has a known ligand but we do not
        #   want to fit in its pocket, we should be very careful.


        # extract ligands
        base=`basename $master .pdb`
        chimera --nogui <<END
        open ${base}.pdb
        select ligand
        write selected format mol2 0 ${base}-L.mol2
        select nucleic acid
        write selected format mol2 0 ${base}-N.mol2
END
	# remove empty ligand files before asking the user for review
        mkdir empty
        # empty mol2 files have a size of 109 bytes
        find . -maxdepth 1 -size 109c -exec mv {} empty \; -print
	# alternately, we could check if the file is empty
        # by counting non-empty/non-space lines between '@<TRIPOS>atom' 
        # and '@<TRIPOS>BOND'.
        for i in ${base}-[LN].mol2 ; do
            # if there is no rec-L or rec-N file, do nothing
            if [ ! -f $i ] ; then continue ; fi
            # this should remove empty lines and yield the two
            # tag lines only as output if there are no atoms
            nlines=`cat receptor-L.mol2 \
            	| grep -v '^[[:space:]]*$' \
                | sed -n '/@<TRIPOS>ATOM/,/@<TRIPOS>/p' \
                | wc -l`
            if [ $nlines -le 2 ] ; then mv $i empty ; fi
        done

	if [ -s "${base}-L.mol2" -o -s "${base}-N.mol2" ] ; then
            echo "$master ligands saved in 05_sitsph/${base}-L.mol2"
            echo "$master nucleic acids saved in 05_sitsph/${base}-N.mol2"

            # Hand reviewing is needed next to remove invalid ligands (e.g. ethylene glycol).
            echo "Please, review in a separate terminal the ligand candidates"
            echo "    05_sitsph/${base}-L.mol2 contains molecules identified as ligands"
            echo "    05_sitsph/${base}-N.mol2 contains nucleic acids"
            echo ""
            echo "Review these files and remove all but the valid ligand(s) to be"
            echo "used to identify the active site"
            echo ""
            echo "Once done, press [ENTER] to continue"
            read line

            # empty mol2 files have a size of 109 bytes
            find . -maxdepth 1 -size 109c -exec mv {} empty \; -print
	    # alternately, we could check if the file is empty
            # by counting non-empty/non-space lines between '@<TRIPOS>atom' 
            # and '@<TRIPOS>BOND'.
            for i in *.mol2 ; do
                # if there is no rec-L or rec-N file, do nothing
                if [ ! -f $i ] ; then continue ; fi
                # this should remove empty lines and yield the two
                # tag lines only as output if there are no atoms
                nlines=`cat receptor-L.mol2 \
            	    | grep -v '^[[:space:]]*$' \
                    | sed -n '/@<TRIPOS>ATOM/,/@<TRIPOS>/p' \
                    | wc -l`
                if [ $nlines -le 2 ] ; then mv $i empty ; fi
            done
	fi

        if [ -s ${base}-L.mol2 ] ; then
            ln -s ${base}-L.mol2 knl.mol2
        elif [ -s ${base}-N.mol2 ] ; then
            ln -s ${base}-N.mol2 knl.mol2
        else
            echo "WARNING: no reference ligands found in $master"
            echo "         the biggest cavity will be used"
        fi
        
    fi
    
    # When there is no ligand in the original file, or an empty reference
    # has been provided, or no reference has been chosen we will default to 
    # using the largest sphere cluster (the first cluster).
    if [ ! -s rec_site.sph ] ; then
        if [ -s knl.mol2 ] ; then
            echo "Using knl.mol2 to pick cavity" 
    	    # select spheres in a radius of RADIUS angstrom
    	    sphere_selector rec.sph knl.mol2 $radius
    	    showsphere <<END
selected_spheres.sph
1
N
selected_spheres.pdb
END
    	    ln -s selected_spheres.sph rec_site.sph
    	    ln -s selected_spheres.pdb rec_site.pdb

        else
            echo "Picking largest cavity available"
    	    showsphere <<END
rec.sph
1
N
selected_spheres.pdb
END
	    ln -s rec.sph rec_site.sph
    	    ln -s selected_spheres.pdb rec_site.pdb
        fi
    fi
    echo "generated site spheres in 05_sitsph/rec_site.sph"
    cd ..


    # 06_gridbox
    # ==========
    # GENERATE GRID BOX
    # -----------------
    #
    #Generate grid box using showbox

    banner ' gridbox  '
    if [ ! -d 06_gridbox ] ; then mkdir 06_gridbox ; fi
    if [ ! -s 05_sitsph/rec_site.sph ] ; then
        echo "ERROR: receptor site generation into 05_sitsph/rec_site.sph failed"
        exit
    fi
    cp 05_sitsph/rec_site.sph 06_gridbox
    cd 06_gridbox

    if [ ! -e receptor_box.pdb ] ; then
        showbox <<END
Y
$radius
rec_site.sph
1
receptor_box.pdb
END
fi
    echo "computed receptor box into 06_gridbox/receptor_box.pdb"

    cd ..

    # 07_grid
    # =======
    # GENERATE GRID
    # -------------
    # 
    # Generate grid using program 'grid'

    banner '   grid   '
    if [ ! -d 07_grid ] ; then mkdir 07_grid ; fi
    if [ ! -s 06_gridbox/receptor_box.pdb ] ; then
        echo "ERROR: 06_gridbox/receptor_box.pdb does not exist"
        exit
    fi
    # copy required files:
    cp 01_dockprep/rec.mol2 07_grid
    cp 05_sitsph/rec_site.sph 07_grid
    cp 06_gridbox/receptor_box.pdb 07_grid

    cd 07_grid

    if [ ! -e grid.nrg ] ; then
        cat > grid.in <<END
compute_grids                  yes
grid_spacing                   0.3
output_molecule                yes
receptor_out_file              rec_clean.pdb
contact_score                  yes
contact_cutoff_distance        4.5
bump_filter                    yes
bump_overlap                   0.75
energy_score                   yes
energy_cutoff_distance         10
atom_model                     a
attractive_exponent            6
repulsive_exponent             9
distance_dielectric            yes
dielectric_factor              4.0
receptor_file                  rec.mol2
box_file                       receptor_box.pdb
vdw_definition_file            $dock6dir/parameters/vdw_AMBER_parm99.defn
score_grid_prefix              grid
END
        echo -n "computing grids.. "
        grid -i grid.in > grid.stdout 
    fi
    if [ ! -s grid.nrg ] ; then
        echo "ERROR: Computation of 07_grid/grid.nrg failed"
	echo "       Please, check the 07_grid/grid.stdout file"
        exit 1
    fi

    #NOTE: on the Finis-Terrae supercomputer the command should end as
    #
    #    qsub -l num_proc=1,s_rt=24:00:00,s_vmem=1G,h_fsize=1G <<ENDJOB
    #        cd $HOME/work/arrojas/dock6/receptor-basic/$i
    #	$PATH=$HOME/dock6/bin:$PATH
    #        grid -i grid.in > grid.stdout&
    #ENDJOB
    #    cd ..
    #done
    echo "computation of 07_grid/grid.* done"
    cd ..

    # 08_dock
    # =======
    # PREPARE ACTUAL DOCKING DATASETS
    # -------------------------------
    # 
    # Make a directory for each ligand
    # Copy required receptor data to corresponding directories in the
    # ligand-docking directory.

    banner '   dock   '
    if [ ! -d 08_dock ] ; then mkdir 08_dock ; fi

    for j in $ligands ; do
        echo "Processing $j"
        lig=`basename $j .mol2`
        if [ -d 08_dock/$lig ] ; then  continue ; fi
        mkdir -p 08_dock/$lig
        cd 08_dock/$lig
        ln -s ../../01_dockprep/rec.mol2 receptor.mol2
        ln -s ../../01_dockprep/rec.pdb receptor.pdb
        ln -s ../../05_sitsph/rec_site.sph .
        ln -s ../../07_grid/grid.nrg .
        ln -s ../../07_grid/grid.bmp .
        ln -s ../../07_grid/grid.cnt .
        if [ -e ../../05_sitsph/knl.mol2 ] ; then
	    ln -s ../../05_sitsph/knl.mol2 .
        fi
        cd ../..
        cp $j 08_dock/$lig/ligand.mol2
    # following is unneeded but handy for later evaluation
        cp $master 08_dock/$lig/orig.pdb
    done

    echo "Prepared directories for docking $master to $ligands"

    # RIGID
    # =====
    # DO RIGID LIGAND DOCKING
    # -----------------------
    # 
    # For each receptor run a rigid docking experiment in its own directory
    # generating the configurarion file and running dock.
    # 
    # NOTES:	consider secondary scoring with gbsa_hawkings or Dock3.5 (requires DelPhi)
    # 	consider writing orientations and scored conformers

    banner '  rigid   '
    cd 08_dock
    for i in * ; do
        # Do not repeat an existing calculation
        if [ -e $i/rigid_scored.mol2 ] ; then continue ; fi
        cd $i
        cat > rigid.in <<END
ligand_atom_file                                             ./ligand.mol2
limit_max_ligands                                            no
skip_molecule                                                no
read_mol_solvation                                           no
calculate_rmsd                                               no
use_database_filter                                          no
orient_ligand                                                yes
automated_matching                                           yes
receptor_site_file                                           ./rec_site.sph
max_orientations                                             500
critical_points                                              no
chemical_matching                                            no
use_ligand_spheres                                           no
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
flexible_ligand                                              no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
contact_score_secondary                                      no
grid_score_primary                                           yes
grid_score_secondary                                         no
grid_score_rep_rad_scale                                     1
grid_score_vdw_scale                                         1
grid_score_es_scale                                          1
grid_score_grid_prefix                                       ./grid
dock3.5_score_secondary                                      no
continuous_score_secondary                                   no
gbsa_zou_score_secondary                                     no
gbsa_hawkins_score_secondary                                 no
amber_score_secondary                                        no
minimize_ligand                                              yes
simplex_max_iterations                                       1000
simplex_tors_premin_iterations                               0
simplex_max_cycles                                           1
simplex_score_converge                                       0.1
simplex_cycle_converge                                       1.0
simplex_trans_step                                           1.0
simplex_rot_step                                             0.1
simplex_tors_step                                            10.0
simplex_random_seed                                          0
simplex_restraint_min                                        no
atom_model                                                   all
vdw_defn_file                                                $dock6dir/parameters/vdw_AMBER_parm99.defn
flex_defn_file                                               $dock6dir/parameters/flex.defn
flex_drive_file                                              $dock6dir/parameters/flex_drive.tbl
ligand_outfile_prefix                                        rigid
write_orientations                                           yes
num_scored_conformers                                        100
write_conformations					     no
cluster_conformations                                        yes
cluster_rmsd_threshold                                       2.0
rank_ligands                                                 no

END
         echo -n "Rigid docking of $i .. "
         dock6 -i rigid.in -o rigid.out
         echo "$i docked"
         cd ..
     done
     echo "Rigid docking done"
     cd ..

    # FLEXIBLE
    # ========
    # DO FLEXIBLE LIGAND DOCKING
    # --------------------------
    # 
    # For each receptor run a rigid docking experiment in its own directory
    # generating the configurarion file and running dock.
    # 
    # NOTES:	consider secondary scoring with gbsa_hawkings or Dock3.5 (requires DelPhi
    # 	and AMSOL) consider writing orientations and scored conformers

    banner ' flexible '
    cd 08_dock

    for i in * ; do
        if [ -e $i/flexible_scored.mol2 ] ; then continue ; fi
        cd $i
        cat > flexible.in <<END
ligand_atom_file                                             ./ligand.mol2
limit_max_ligands                                            no
skip_molecule                                                no
read_mol_solvation                                           no
calculate_rmsd                                               no
use_database_filter                                          no
orient_ligand                                                yes
automated_matching                                           yes
receptor_site_file                                           ./rec_site.sph
max_orientations                                             2000
critical_points                                              no
chemical_matching                                            no
use_ligand_spheres                                           no
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
flexible_ligand                                              yes
min_anchor_size                                              40
pruning_use_clustering                                       yes
pruning_max_orients                                          100
pruning_clustering_cutoff                                    100
pruning_conformer_score_cutoff                               25.0
use_clash_overlap                                            no
write_growth_tree                                            no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
contact_score_secondary                                      no
grid_score_primary                                           yes
grid_score_secondary                                         no
grid_score_rep_rad_scale                                     1
grid_score_vdw_scale                                         1
grid_score_es_scale                                          1
grid_score_grid_prefix                                       ./grid
dock3.5_score_secondary                                      no
continuous_score_secondary                                   no
gbsa_zou_score_secondary                                     no
gbsa_hawkins_score_secondary                                 no
amber_score_secondary                                        no
minimize_ligand                                              yes
minimize_anchor                                              yes
minimize_flexible_growth                                     yes
use_advanced_simplex_parameters                              no
simplex_max_cycles                                           1
simplex_score_converge                                       0.1
simplex_cycle_converge                                       1.0
simplex_trans_step                                           1.0
simplex_rot_step                                             0.1
simplex_tors_step                                            10.0
simplex_anchor_max_iterations                                500
simplex_grow_max_iterations                                  500
simplex_grow_tors_premin_iterations                          0
simplex_random_seed                                          0
simplex_restraint_min                                        no
atom_model                                                   all
vdw_defn_file                                                $dock6dir/parameters/vdw_AMBER_parm99.defn
flex_defn_file                                               $dock6dir/parameters/flex.defn
flex_drive_file                                              $dock6dir/parameters/flex_drive.tbl
ligand_outfile_prefix                                        flexible
write_orientations                                           yes
num_scored_conformers                                        100
write_conformations					     no
cluster_conformations                                        yes
cluster_rmsd_threshold                                       2.0
rank_ligands                                                 no

END
        echo -n "Flexible docking of $i .. "
        dock6 -i flexible.in -o flexible.out
        echo "$i docked"
        cd ..
    done
    echo "Flexible docking done"
    cd ..


    # ZOU GB/SA DOCK
    # --------------
    # 
    # Repeat flexible docking with other scores. Primary score used Grid-Based
    # score(non-bonded terms of molecular mechanics force field).
    # 
    # Next step should be to use Dock3.5 as primary score (a variant of Grid score 
    # using desolvation in addition to steric and electrostatic interactions), and 
    # gbsa_hawkins (MM-GBSA Molecular Mechanichs Generalized Born Surface Area) as 
    # secondary score. However, Dock3.5 rquires AMSOL and Hawkins requires other
    # programs (DELPHI)
    # 
    # Instead we will be using Zou GB/SA as the primary score, as according to the
    # manual gives similar results to the grid-based free energy model with less
    # computation efforts. But this one requires previous generation of GB and SA 
    # grids, which we must do:

    banner ' Zou/GBSA '
    cd 08_dock

    for i in * ; do
        if [ -e $i/gbsa_zou_scored.mol2 ] ; then continue ; fi
        cd $i
        if [ ! -h receptor_box.pdb ] ; then
    	    ln -s ../../06_gridbox/receptor_box.pdb .
        fi
        cat > solvent_grid.in <<END
compute_grids                  yes
grid_spacing                   0.3
output_molecule                no
contact_score                  no
energy_score                   yes
energy_cutoff_distance         9999
atom_model                     a
attractive_exponent            6
repulsive_exponent             12
distance_dielectric            no 
dielectric_factor              1 
bump_filter                    yes
bump_overlap                   0.75
receptor_file                  receptor.mol2
box_file                       receptor_box.pdb
vdw_definition_file            $dock6dir/parameters/vdw_AMBER_parm99.defn
score_grid_prefix              solvent_grid
END
        if [ ! -s solvent_grid.bmp ] ; then grid -i solvent_grid.in ; fi
        if [ ! -h params ] ; then ln -s $dock6dir/parameters params ; fi
        if [ ! -d nchemgrid_GB ] ; then mkdir nchemgrid_GB ; fi
        cd nchemgrid_GB
        touch cavity.pdb
        cat > INCHEM<<END
../receptor.pdb
cavity.pdb
../params/prot.table.ambcrg.ambH
../params/vdw.parms.amb
../receptor_box.pdb
0.3
2
1
8.0 8.0
78.3 78.3
2.3 2.8
gbsa_zou_grid
1
END
        if [ ! -s gbsa_zou_grid.bmp ] ; then nchemgrid_GB ; fi
        if [ ! -d ../nchemgrid_SA ] ; then mkdir ../nchemgrid_SA ; fi
        cd ../nchemgrid_SA
        if [ ! -h params ] ; then ln -s $dock6dir/parameters params ; fi
        cat > INCHEM<<END
../receptor.pdb
../params/prot.table.ambcrg.ambH
../params/vdw.parms.amb
../receptor_box.pdb
0.3
1.4
2
8.0
gbsa_zou_grid
END
        if [ ! -s gbsa_zou_grid.bmp ] ; then nchemgrid_SA ; fi
        cd ..

        # Then, we can perform a GB/SA calculation using something like the following gbsa_zou.in
        cat > gbsa_zou.in <<END
ligand_atom_file                                             ./ligand.mol2
automated_matching                                           yes
receptor_site_file                                           ./rec_site.sph
max_orientations                                             2000
critical_points                                              no
chemical_matching                                            no
use_ligand_spheres                                           no
limit_max_ligands                                            no
skip_molecule                                                no
read_mol_solvation                                           no
calculate_rmsd                                               no
use_database_filter                                          no
orient_ligand                                                yes
use_internal_energy                                          no
flexible_ligand                                              no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
contact_score_secondary                                      no
grid_score_primary                                           no
grid_score_secondary                                         no
dock3.5_score_primary                                        no
dock3.5_score_secondary                                      no
continuous_score_primary                                     no
continuous_score_secondary                                   no
gbsa_zou_score_primary                                       yes
gbsa_zou_score_secondary                                     no
gbsa_zou_gb_grid_prefix                                      ./nchemgrid_GB/gbsa_zou_grid
gbsa_zou_sa_grid_prefix                                      ./nchemgrid_SA/gbsa_zou_grid
gbsa_zou_vdw_grid_prefix                                     ./solvent_grid
gbsa_zou_screen_file                                         ./params/screen.in
gbsa_zou_solvent_dielectric                                  78.300003
gbsa_hawkins_score_secondary                                 no
amber_score_secondary                                        no
minimize_ligand                                              no
atom_model                                                   all
vdw_defn_file                                                ./params/vdw_AMBER_parm99.defn
flex_defn_file                                               ./params/flex.defn
flex_drive_file                                              ./params/flex_drive.tbl
ligand_outfile_prefix                                        gbsa_zou
write_orientations                                           yes
write_conformations					     no
cluster_conformations                                        yes
cluster_rmsd_threshold                                       2.0
num_scored_conformers                                        100
rank_ligands                                                 no
END
        echo -n "Zou GB/SA docking of $i .. "
        dock6 -i gbsa_zou.in -o gbsa_zou.out
        echo "$i docked"

        cd ..
    done
    echo "Zou GB/SA docking done"
    cd ..


    # USE HAWKINS MM-GB/SA DOCKING
    # ----------------------------

    banner ' HAWKINS  '
    cd 08_dock
    for i in * ; do
        if [ -e $i/mmgbsa_hawkins_secondary_scored.mol2 ] ; then continue ; fi
        cd $i
        cat > mmgbsa_hawkins.in <<END
ligand_atom_file                                             ./ligand.mol2
limit_max_ligands                                            no
skip_molecule                                                no
read_mol_solvation                                           no
calculate_rmsd                                               no
use_database_filter                                          no
orient_ligand                                                yes
automated_matching                                           yes
receptor_site_file                                           ./rec_site.sph
max_orientations                                             2000
critical_points                                              no
chemical_matching                                            no
use_ligand_spheres                                           no
use_internal_energy                                          yes
internal_energy_rep_exp                                      12
flexible_ligand                                              yes
min_anchor_size                                              40
pruning_use_clustering                                       yes
pruning_max_orients                                          100
pruning_clustering_cutoff                                    100
pruning_conformer_score_cutoff                               25.0
use_clash_overlap                                            no
write_growth_tree                                            no
bump_filter                                                  no
score_molecules                                              yes
contact_score_primary                                        no
contact_score_secondary                                      no
grid_score_primary                                           yes
grid_score_secondary                                         no
grid_score_rep_rad_scale				     1.0
grid_score_vdw_scale                                         1
grid_score_es_scale                                          1
grid_score_grid_prefix                                       ./grid
dock3.5_score_primary                                        no
dock3.5_score_secondary                                      no
dock3.5_vdw_score					     yes
dock3.5_grd_prefix					     chem52
dock3.5_electrostatic_score				     yes
dock3.5_ligand_internal_energy				     yes
dock3.5_ligand_desolvation_score			     volume
dock3.5_write_atomic_energy_contrib			     yes
dock3.5_score_vdw_scale					     1.0
dock3.5_score_es_scale					     1.0
continuous_score_secondary                                   no
gbsa_zou_score_secondary                                     no
gbsa_hawkins_score_primary				     no
gbsa_hawkins_score_secondary                                 yes
gbsa_hawkins_score_rec_filename				     receptor.mol2
gbsa_hawkins_score_solvent_dielectric			     78.5
gbsa_hawkins_use_salt_screen       			     no
gbsa_hawkins_score_gb_offset				     0.09
gbsa_hawkins_score_cont_vdw_and_es                           yes
gbsa_hawkins_score_vdw_att_exp				     6
gbsa_hawkins_score_vdw_rep_exp				     12
grid_score_rep_rad_scale				     1.0
amber_score_secondary                                        no
minimize_ligand                                              yes
minimize_anchor                                              yes
minimize_flexible_growth                                     yes
use_advanced_simplex_parameters                              no
simplex_max_cycles                                           1
simplex_score_converge                                       0.1
simplex_cycle_converge                                       1.0
simplex_trans_step                                           1.0
simplex_rot_step                                             0.1
simplex_tors_step                                            10.0
simplex_anchor_max_iterations                                500
simplex_grow_max_iterations                                  500
simplex_grow_tors_premin_iterations                          0
simplex_random_seed                                          0
simplex_restraint_min                                        no
atom_model                                                   all
vdw_defn_file                                                $dock6dir/parameters/vdw_AMBER_parm99.defn
flex_defn_file                                               $dock6dir/parameters/flex.defn
flex_drive_file                                              $dock6dir/parameters/flex_drive.tbl
ligand_outfile_prefix                                        mmgbsa_hawkins
write_orientations                                           yes
num_scored_conformers                                        100
write_conformations					     yes
cluster_conformations                                        yes
cluster_rmsd_threshold                                       2.0
rank_ligands                                                 no

END
    #   this works for most cases in FINISTERRAE
    #	qsub -N FDOCK6-$j-$i -l num_proc=1,s_rt=20:00:00,s_vmem=2G,h_fsize=1G <<ENDSUB
    #   try with more memory for big grid files
    #	qsub -N FOCK6-$j-$i -l num_proc=1,s_rt=20:00:00,s_vmem=4G,h_fsize=1G <<ENDSUB
    #   1dg3 requires 4GB memory (from NGS, an x86_64 machine)
    #	qsub -l num_proc=1,s_rt=20:00:00,s_vmem=4G,h_fsize=1G <<ENDSUB
    #    this should work on NGS
    #	qsub -q slow -N DOCK6+$j-$i \
    #	     -e $HOME/work/arrojas/dock6/$j/$i/DOCK6+.err \
    #	     -o $HOME/work/arrojas/dock6/$j/$i/DOCK6+.out <<ENDSUB
    #    	    cd $HOME/work/arrojas/dock6/$j/$i
    #	    export PATH=$HOME/dock6/bin:$PATH
        export DELPHI_HOME=$HOME/bin/delphi
        echo -n "Hawkins MM-GB/SA docking of $i .. "
        dock6 -i mmgbsa_hawkins.in -o mmgbsa_hawkins.out -v
        echo "$i docked"
    #ENDSUB
        cd ..
    done
    cd ..
}

docker $*

