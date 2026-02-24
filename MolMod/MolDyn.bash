#!/bin/bash
#
# NAME
#	opls-aa	- run a simulation using the OPLS-AA force field
#
# DESCRIPTION
#	opls-aa -i infile -h add_H_method -p pH -s -n -S -l ligands -O -E -M -L
#
#	Analyze the input file (possibly with the help of a ligands file)
#	to identify existing ligands, determine appropriate topology 
#	parameters for each ligand (using a variety of alternative methods)
#	add H if requested using the method specified) at the pH indicated
#	(pH only works for 'babel'), and optionally solvate, add counterions
#	to neutralize the system or soak in physiologic saline serum.
#
#	Once the system has been analyzed and built, optional comutations
#	can be performed by indicating successive steps in a standard
#	simulation: Optimization (energy minimization), equilibration
#	(first in NVT and then in NPT) and production MD runs of 1ns and/or
#	long production MD runs of 10ns.
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

myname=`basename "${BASH_SOURCE[0]}"`
mydir=`dirname "${BASH_SOURCE[0]}"`

# Include files with useful functions
# aliases do not work by default in non-interactive scripts
# shopt -s expand_aliases
#alias include='INCLUDE=yes source'
#
# it is better not to use aliases, plus, we do not need INCLUDE any more
# we prefer to use 'source' over '.' because it is more conspicuous
export FUNCS_BASE=$mydir/lib
source $FUNCS_BASE/setup_cmds.bash
source $FUNCS_BASE/gromacs_funcs.bash
source $FUNCS_BASE/fs_funcs.bash
source $FUNCS_BASE/util_funcs.bash


### OVERRIDES 
###			HACKER'S REALM
###	This is only for insider-knowledge-holders. Check included libraries.
###
###	By overriding internal variables used in the included libraries
### here, before the variable is used in an actual function call, we can 
### force use of this value instead of the default one without needing to 
### pass additional parameters to the corresponding functions (which might 
### become cumbersome and possibly unreadable).
###
###	Eventually we should set them more clearly, but until we have more
### experience on their relevance we'll rather be cautious.
###
#	Some problems fail with "there is no domain decomposition for N 
# ranks..." which means the number of threads or the maximum bonded 
# interaction ranks must be manually adjusted. Default is 0 (guess)
nthreads=10	# maximum number of parallel threads
maxdd=0		# maximum distance for bonded interactions with DD (nm)

### END OF OVERRIDES


# defaults
ff='opls-aa'
MPI='no'
MPInodes=24
addH='no'		# yes or no
addHmethod='none'	# chimera or babel or gromacs or reduce or haad or none (default = none)
pH='7.365'		# default pH for babel H assignment
solvate='no'		# solvate (yes or no)
counterions='no'	# only add counterions
useSaline='no'		# use physiologic saline serum (with extra Na and Cl)
ligands='./LIGANDS'	# file with a listing of ligands
optimize='no'		# add an optimization run
equilibrate='no'	# add an equilibration run
shortrun='no'		# add a 1 ns MD production run
longrun='no'		# add a 10 ns MD production run
VERBOSE=0

# ERROR TRAPPING (work in progress)
#----------------------------------
#tempfiles=( )
#cleanup() {
#  rm -f "${tempfiles[@]}"
#}
#trap cleanup 0
#
# then whenever you create a temporary file
#temp_foo="$(mktemp -t foobar.XXXXXX)"
#tempfiles+=( "$temp_foo" )

#set -o pipefail  # trace ERR through pipes
#set -o errtrace  # trace ERR through 'time command' and other functions
#set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
#set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
#

# we can have several traps and they will all be called in order
#trap 'error "${LINENO} ERR"'


# For each force field use the water model it was parametrized with
if [ "$ff"="opls-aa" ] ; then
    export WATER='tip4p'
elif [ "$ff"="AMBER" ] ; then
    export WATER='tip3p'
elif [ "$ff"="CHARMM" ] ; then
    export WATER='tip3p'
elif [ "$ff"="GROMOS" ] ; then
    export WATER='spc'
else
    export WATER='spc'
fi

#
# Stablish paths for programs
#

export USERBIN=~/bin
export ACPYPE=~/contrib/acpype				# ACPYPE
export AMBER=~/contrib/amber14/bin			# Ambertools
export OPENBABEL=~/contrib/openbabel/bin		# OpenBabel
export AMBERHOME=~/contrib/amber14
export GMX_TOP="/usr/share/gromacs/top"     	    	# GROMACS topology files
export GROMACS="/usr/bin"				# Gromacs
export PATH=$PATH:$ACPYPE:$AMBER:$OPENBABEL:$USERBIN

# In addition to these packages, we also want to specify several
# specific programs. If any of them is missing, leave empty and
# it won't be used.
#
# At the very least you need babel (and possibly one topolgy builder)
# if you have hetero (non-protein) compounds
#
### THESE WILL OVERRIDE THE VALUES SPECIFIED IN THE INCLUDED LIBRARIES!
###	AND SHOULD LIKELY BE REMOVED FROM HERE
###
###	IF YOU DO NOT HAVE ANY OF THEM, SET IT TO ""

# general tools
export babel=`which babel`		# get it from http://openbabel.org
export chimera=`which chimera`		# get it from http://www.cgl.ucsf.edu/chimera/
# add H
export reduce=`which reduce`		# get it from http://kinemage.biochem.duke.edu/software/
export REDUCE_HET_DICT=~/share/kinemage/reduce_wwPDB_het_dict.txt
export haad=`which haad`		# get it from http://zhanglab.ccmb.med.umich.edu/HAAD
# QM (unsupported outside CNB/CSIC)
#export openmopac=`which MOPAC2009.exe`	# get if from http://OpenMopac.net
#export openmopac=~/contrib/mopac/MOPAC2009.exe # no longer needed
export openmopac="${HOME}/contrib/mopac/MOPAC2016.exe"
export MOPAC_LICENSE=~/contrib/mopac
export freeON=`which FreeON.sh`		# get freeON at http://freeon.org
export ergoSCF=`which ErgoSCF.bash`	# get ergo at http://ergoscf.org
# topology builders
export mktop=`which mktop_2.2.1.pl`	# get it from http://www.aribeiro.net.br/mktop/
#export topolgen=`which topolgen`	# get it from http://www.gromacs.org/@api/deki/files/88/=topolgen-1.1.tgz
export topolgen=~/contrib/TopolGen/topolgen_1.1.pl	# get it from http://www.gromacs.org/@api/deki/files/88/=topolgen-1.1.tgz
export topolbuild=~/contrib/topolbuild1_3/bin/topolbuild	# get it from http://www.gromacs.org/Downloads/User_contributions/Other_software
export topolbuilddat=~/contrib/topolbuild1_3/dat/
export acpype=`which acpype`		# get it from http://www.gromacs.org/Downloads/User_contributions/Other_software
# analysis
export DSSP=~/bin/dsspcmbi		# needed for Gromacs do_dssp
#export do_dssp=`which do_dssp454`	# latest do_dssp is buggy, use a previous one


# UNDOCUMENTED, to be deleted
topology='default'	# default topology to use (default = use hardcoded heuristic)
export topology		# it may be that some topology generators work better
                        # for some ligands and worst for others and if so,
                        # selection should be done on a per-ligand basis in
                        # the LIGANDS file.
chargeModel='default'   # charge model to use to install newly computed MOL2
export ChargeModel	# and PDB files.


function usage {
# Unneeded as we'll ignore all parameters
#    if [ $# -ne 0 ] ; then echo "Err: ${FUNCNAME[0]}" ; exit 1 
#    else echo -e "\n>>> ${FUNCNAME[0]}" $* ; fi

    local addhmethods="babel|gromacs"
    # external reduce, chimera
    if [ "$haad" != "" ] ; then
        addhmethods="haad|$addhmethods"
    fi
    if [ "$reduce" != "" ] ; then
        addhmethods="reduce|$addhmethods"
    fi
    if [ "$chimera" != "" ] ; then
        addhmethods="chimera|$addhmethods"
    fi

    cat <<END

    Usage: $myname -i input.pdb -h add_H_method -p pH -s -n -S -l ligands 
    		-O -E -M -L
    
    	Run a full Gromacs simulation using the $ff force field.

	If -h is used, then H will be added to the system. By default
        a physiologic pH is used. H may be added using Chimera, gromacs,
        reduce, haad or babel. Only in the last case (babel), a different
        pH may be specified.
        
        This command will analyze the input file looking for ligands, and
        if any are found, will generate the parameters for them using
        various approaches. A list of ligands to process can be given 
        instead, and in this case, charges for each ligand may be specified.
        
        Accurate atomic charges may be assigned to a ligand in a .mol2 file.
        
        A topology can also be provided for a ligand as a .itp file.
        
        Once all parameters have been generated, the system will be
        solvated (-s) and ions will be added to compensate charges (-c) 
        or, if -S is specified, to simulate physiologic saline serum.
        
        After the system has been set up, it may be energy minimized,
        equilibrated, first in NVT and then in NPT, and finally an MD
        production run in NPT can be computed for extensions of 1 ns 
        and 10 ns.
        
        At each step, relevant statistics will be collected and a complete
        analysis carried out.

        Parameters:

                -?	print this help
        	-i	input file in PDB format
                -h	add H to the system using the method specified 
                	($addhmethods) 
                -p      pH to consider when adding H (only used if 
                	method is babel)
                -s	solvate the system (only add water)
                -n	solvate and neutralize charges
                -S	solvate using physiologic saline serum (implies -s)
                -l	file with a list of ligands, format is
                	'LIG	charge'
                -T	target temperature in Kelvin [310]
                -P	target pressure in bar [1.0]
                -O	add an optimization (energy minimization) run
                -E	add an equilibration run (implies -O)
                -M	add a short 1 ns MD run (implies -E -O)
                -L	add a long 10 ns MD run (implies -M -E -O)
        
        Other files:
        	\$LIG.mol2 for any ligand \$LIG, if a \$LIG.mol2 file exists, it
                	will be used to assign charges to its atoms (instead
                        of calculating them).
		\$LIG.itp  for any ligand \$LIG, if this file exists, then it
                	will be used to define the topology. 
                        IMPORTANT NOTE: if the \$LIG.itp file requires (includes)
                        other files, these should be present as well; deep
                        nesting (includes within includes) is NOT supported.

	Side products:
        	This program will generate several by-products that can
                help you solve problems when they appear. They will be
                saved in sub-folders:
                \$LIG.mmooll22/		various mol2 files with
                        		charges computed using different methods
                \$LIG.topolbuild/	Gromacs parameters for OPLS-AA computed
                			with topolbuild
                \$LIG.topolgen/		Gromacs parameters for OPLS-AA computed
                			with topolgen
                \$LIG.mktop/		Gromacs parameters for OPLS-AA and AMBER
                			computed with mktop
                \$LIG.acpype/		Parameters for CNS/XPLOR, Gomacs Gromos,
                			Gromacs OPLS-AA, Gromacs Amber, AMBER,
                                        CHARMM and Pickle computed with ACPYPE.
                LIGANDS.OK		A file listing all the ligands that could
                			be succesfully processed
                \$LIG.mol2		The .mol2 file used
                \$LIG.itp		The topology used for the simulation

	Output:
        	Depending on what you asked, you will get a huge number of
                files:
                	OrigComplex*	Original Complex
                        Protein*	Protein part
                        \$LIG.*		Ligand(s)
                        Complex*	Complex prepared for Gromacs simulation
                        em.*		Optimization (Energy Minimization)
                        eq_nvt_200ns.*	Equilibration in NVT
                        eq_npt_200ms.*	Equilibration in NPT
                        md_??.*		Various MD steps

END

}


# process command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
#	t:	undocumented, to be removed, select topology generator
TEMP=`getopt -o c:t:i:h:p:l:sSnOEMLv \
     --long charge:,topology:,input:,addH:,ph:,ligands:,solvate,saline,neutral,optimize,equilibrate,shortmd,longmd,verbose \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-c|--charge)
		    # undocumented.
		    #  select charge model
		    charge=$2
		    shift 2 ;;
        	-t|--topology)
                    # undocumented, to be removed
                    # select topology generator to use for ligands
                    #	This is only for testing and comparing each method
                    if [ "$2"="topolbuild" -o "$2"="topolgen" \
                        -o "$2"="mktop" -o "$2"="acpype" ] ; then
                        topology=$2
		    fi
                    shift 2 ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
                    if [ ! -s $2 ] ; then
			echo ""
                    	warncont "$2 doesn't exist or is empty."
                    	usage ; exit 1
                    fi
		    # If we are NOT given a file name, we will
                    # work in the current directory using file OrigComplex.pdb
                    # which must exist.
                    # If we are given a file name, we will create a
                    # special directory to work in and copy that file
                    # into the new directory as OrigComplex.pdb
                    # Since the directory name will depend on the
                    # options, that action will have to be deferred
                    # until after option processing.
		    #cp $2 OrigComplex.pdb 
                    input=$2
                    shift 2 ;;
		-h|--addH) 
		    addH='yes'
		    case "$2" in
		        chimera|babel|gromacs|reduce|haad|none)
                            addHmethod=$2 ;;
                        *)
			    warncont "requested method <$2> is not supported"
			    usage ; exit ;;
                    esac
                    shift 2 ;;
                -p|--pH)
                    # check $2 is a positive real number
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pH=$2
                    else
                        echo ""
                        warncont "$2 is not a positive real number."
                        usage ; exit 1
                    fi
                    shift 2 ;;
		-s|--solvate)
                    # add water
                    solvate='yes'
                    shift ;;
                -n|--neutral)
                    # only add ions to counteract the charges of the complex
                    solvate='yes'
                    counterions='yes'
                    shift ;;
                -S|--saline)
                    # add ions to physiologic serum concentration
                    solvate='yes'
                    counterions='yes'
                    useSaline='yes'
                    shift ;;
                -l|--ligands)
                    if [ ! -s $2 ] ; then
                        echo ""
                    	warncont "$2 doesn't exist or is empty."
                    	usage ; exit 1
                    fi
                    ligands=$2
                    shift 2 ;;
		-T|--temperature)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        temperature=$2
                    else
                        echo ""
                        warncont "$2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
		-P|--pressure)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pressure=$2
                    else
                        echo ""
                        warncont "$2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
                -O|--optimize)
                    optimize='yes'
                    shift ;;
                -E|--equilibrate)
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;
                -M|--shortmd)
                    shortrun='yes'
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;
                -L|--longmd)
                    longrun='yes'
                    shortrun='yes'
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;
                -v|--verbose)
                    VERBOSE=1
                    shift ;;
		--) shift ; break ;;
		*) warncont "Unknown option!" ; usage ; exit 1 ;;
	esac
done

# Setup simulation directory
# get file directory
#	if $input is empty this will return "."
d=`dirname "$input"`

in="${input##*/}"
ext="${input##*.}"
nam="${in%.*}"

#echo "dir: $d"
#echo "in : $in"
#echo "ext: $ext"
#echo "nam: $nam"
#echo "input: $input"

if [ "$ext" != "pdb" -a "$ext" != "brk" ] ; then
    warncont "Input file must be a PDB file."
    # may be we could use a mol2 file or other type instead,
    # certainly a .gro file should work
    usage ; exit 1
fi

## DEFINE OUTPUT DIRECTORY NAME
##
# name=`basename $1 .pdb`_hoh
# echo $name
name=${ff}_${nam}

if [ $addH == 'yes' ] ; then
    name=${name}_H
    if [ $addHmethod == 'chimera' ] ; then
        # we should check availability of UCSF chimera
        name=${name}c
    elif [ $addHmethod == 'babel' ] ; then
    	# we should check availability of babel
        name=${name}b_$pH
    elif [ $addHmethod == 'reduce' ] ; then
    	# we should check availability of babel
        name=${name}r
    else
        name=${name}g
    fi
fi

if [ "$useSaline" == 'yes' ] ; then
    name=${name}_150mM
elif [ "$counterions" = 'yes' ] ; then
    name=${name}_hoh_ions
elif [ "$solvate" == 'yes' ] ; then
    name=${name}_hoh
fi

echo "output: $name"
echo ""

if [ -e $name -a ! -d $name ] ; then 
    errexit "$name exists and is not a directory."
fi


mkdir -p $name

# Redirect output to a log file
#
# redirect all output to log files (one for stdout and one for stderr)
#log=./$name/LOG.$myname.out
#err=./$name/LOG.$myname.err
#exec > $log 2> $err
#
# use a single log file, backing it up to an increasing count if one
# already exists.
#
log=./$name/log.$myname.std
#if [ -e $log ] ; then
#    cnt=1
#    while [ -e $log.$cnt ] ; do
#        cnt=$((cnt + 1))
#    done
#    mv $log $log.$cnt
#fi
#save any existing log file in a version-numbered file
version_file $log

# make redirections for 'eval'uated commands in case of verbose output
redirect_std_out_err $name

# report parameters selected
echo ""
banner " $ff MD"
echo ""
echo "input: $input"
echo "add-H: $addH"
echo "method: $addHmethod"
echo "pH: $pH"
echo "T: $temperature"
echo "P: $pressure"
echo "solvate: $solvate"
echo "counterions: $counterions"
echo "saline: $useSaline"
echo "ligands: $ligands"
echo "optimize: $optimize"
echo "equilibrate: $equilibrate"
echo "short MD run (1ns): $shortrun"
echo "long MD run (10ns): $longrun"

echo '
#-------------------------------------------------------------------------
#		PREPARE SYSTEM
#-------------------------------------------------------------------------
'
banner ' SET UP'

# Copy input files to work directory
cp $input $name/OrigComplex.pdb
if [ -f $ligands ] ; then
    cp $ligands $name/LIGANDS
    # check if there are .mol2 files to copy
    cut -f1 $ligands | while read lig ; do
	if [ -s $lig.mol2 ] ; then
            cp $lig.mol2 $name
        fi
 	if [ -s $lig.pdb ] ; then
            cp $lig.pdb $name
        fi
 	if [ -s $lig.itp ] ; then
            cp $lig.itp $name
            # if it includes other files wee need them as well:
	    grep '#include' $lig.itp |\
            while read inc fil ; do
                cp $fil $name
            done
        fi
   done
    # NOTE: later on we will check for the existence
    # of the .mol2 files inside the directory.
    # This is so because that way, if the calculation fails,
    # then we can add them later inside the working directory 
    # and restart the calculation to use those new ones.
fi

cd $name


banner "  SYSTEM"
echo ""
echo ">>> Preparing system"

if [ "$addH" != 'yes' ] ; then
    addHmethod='none'
fi

# Make $name+H.pdb $name-H.pdb
if ! add_H OrigComplex.pdb $addHmethod $pH ; then exit $ERROR ; fi

# Assuming OrigComplex+H.pdb, split it in Protein.pdb and Ligand.pdb
# we could get a PDB ID if needed, e.g.
# wget -c "http://www.pdb.org/pdb/download/downloadFile.do?fileFormat=pdb&compression=NO&structureId=1BVG" -O 1BVG.pdb

# simple way (all ligands in a single file)
#split_complex OrigComplex+H.pdb

cp OrigComplex+H.pdb Protein.pdb

 ------------------------------------------------------------------------
# Separate ligands and Protein

# extract ligands from Protein.pdb
# at the end, Protein.pdb will no longer contain ligands
# and we will have, for each ligand:
#   $lig.mol2
#   $lig.pdb
#   $lig.acpype/    	with the ligand topologies
#   	$lig_NEW.pdb
#   	$lig_GMX_OPLS.itp
#   	$lig_GMX_OPLS.top
#
#   	$lig_GMX.gro
#   	$lig_GMX.ito
#   	$lig_GMX.top
#   	$lig_CNS.*
#   	$lig_CHARMM.*
#   	$lig_AC.*, etc...
#

if ! extract_ligands Protein.pdb $ligands $topology $ff ; then
    errexit "Could not extract ligands"
fi
echo "Separated Protein + ligands"

# Generate Protein topology
# Process Protein without ligands with pdb2gmx, 
# considering chain IDs and TER records, and define water
#	NOTE: for OPLS-AA we should use TIP4P water
echo ""
if [ ! -e ProteinOK.pdb ] ; then
    echo ">>> Generating protein topology"
    if [[ "$ff" == "opls"* ]] ; then forcefield="oplsaa" ; fi
        eval $pdb2gmx -ff $forcefield -f Protein.pdb -o ProteinOK.pdb -p Protein.top \
	    -water $WATER -ignh -chainsep id_or_ter $LOG
    if [ ! -s ProteinOK.pdb ] ; then exit ; fi
    # Generates posre_Protein_chain_{ABC}.itp Protein_Protein_chain_{ABC}.itp
    #	ProteinOK.pdb Protein.top

else
    echo "Using ProteinOK.pdb from previous run."
fi
echo ""

#
# Reconstruct the complex.
#
#	This is force field specific, specially in the case of
#	OPLS-AA, which is why we do not put it in a function.
#
if [ ! -e Complex.pdb -o ! -e Complex.top ] ; then
    echo ""
    echo ">>> Reconstituting complex"
    echo ""
    # we need to merge back now the protein and the updated ligands
    # 
    # Start by adding the Protein to the Complex
    grep -h ATOM ProteinOK.pdb >| Complex.pdb
    cp Protein.top Complex.top

    # Edit Complex.top to add each ligand
    # Update $lig.pdb to match the chosen topology
    #
    # check there are indeed successfully processed ligands to add
    if [ -s $ligands ] ; then 
        echo ""
        echo ">>> Adding ligands to complex"
	echo ""
        echo "NOTE:"
        echo "	WE ARE NOT DEALING WITH THE POSSIBILITY OF HAVING"
        echo "	MORE THAN ONE COPY OF EACH LIGAND WITH THE SAME NAME!"
        echo "	IF THAT IS THE CASE, PLEASE, CONSIDER RENAMING EACH"
        echo "	COPY TO USE A UNIQUE NAME."
        echo ""
        touch atomtypes

        cat $ligands | while read lig charge ; do
            if [ "$lig" == "" ] ; then continue ; fi
            echo ""
	    echo "Adding ligand '$lig' '$charge' ($ligands)"
	    echo ""
            if [[ "$ff" == "opls"* ]] ; then
                echo "Adding $lig coordinates and $ff parameters"
	        add_ligand_oplsaa Complex $lig
	    elif [[ "$ff" == "amber"* ]] ; then
	    	add_ligand_amber Complex $lig
	    elif [[ "$ff" == "charmm"* ]] ; then
	    	echo "UNIMPLEMENTED"
	    	exit
	    elif [[ "$ff" = "gromos"* ]] ; then
	    	echo "UNIMPLEMENTED"
	    	exit
	    fi
            echo "Added $lig $charge ($ligands)"
        done
    fi
else
    echo ""
    echo "Using Complex.pdb and Complex.top from previous run."
    echo ""
fi
echo ""
echo "Complex reconstituted"
echo ""

#
# Define a triclinic PBC box
#
if [ ! -e Complex_PBC.top ] ; then
    # Setup the box 
    #	should prefer -bt dodecahedron
    #	allow for 1.2 nm between protein and box edges
    echo ""
    echo ">>> Defining simulation box."
    eval $editconf -bt triclinic -f Complex.pdb -o Complex_PBC.pdb -d 1.2 $LOG
    if [ $? -ne 0 ] ; then exit ; fi
    
    cp Complex.top Complex_PBC.top
else
    echo "Using Complex_PBC.(pdb|top) from previous run."
fi


#
#  Solvate if needed
#
if [ ! -e Complex_b4em.pdb ] ; then
    echo ""
    echo ">>> Preparing for Energy Minimization"
    if [ "$solvate" != 'yes' ] ; then
        # we do not add anything, simply jump to ready for EM
        cp Complex_PBC.pdb Complex_b4em.pdb
        cp Complex_PBC.top Complex_b4em.top
    else
        # add water and possibly ions
        if [ $useSaline = 'yes' ] ; then
            if [ ! -s Complex_PBC+saline.pdb ] ; then
	        if ! solvate Complex_PBC.pdb saline ; then exit $ERROR ; fi
            fi
            cp Complex_PBC+saline.pdb Complex_b4em.pdb
            cp Complex_PBC+saline.top Complex_b4em.top
        elif [ "$counterions" = 'yes' ] ; then
            if [ ! -s Complex_PBC+ion.pdb ] ; then
    	        if ! solvate Complex_PBC.pdb counterions ; then exit $ERROR ; fi
            fi
            cp Complex_PBC+ion.pdb Complex_b4em.pdb
            cp Complex_PBC+ion.top Complex_b4em.top
	else
	    # by default we will use water
	    if [ ! -s Complex_PBC+water.pdb ] ; then
                if ! solvate Complex_PBC.pdb water ; then exit $ERROR ; fi
            fi
            cp Complex_PBC+water.pdb Complex_b4em.pdb
	    cp Complex_PBC+water.top Complex_b4em.top
    	fi
    fi
else
	echo "Using Complex_b4em.(pdb|top) from previous run."
fi
make_ext_index Complex_b4em.pdb



# Find if we need to split the simulation system in groups
#	This is used for temperature coupling when there are 
#	solvation elements in the system
if [ "$solvate" = "yes" ] ; then
    # There will be two simulation groups, solute and solvent
    ngroups='2'
else
    ngroups='1'
fi


if [ "$optimize" = 'yes' ] ; then
    if [ ! -e em.pdb ] ; then
        banner "   E M"
        # Run minimisaton
        make_em_config 
        echo ""
        echo ">>> Minimizing energy."
        # we have em.mdp, Complex_b4em.pdb and Complex_b4em.top
        if ! run_md em Complex_b4em ; then exit $ERROR ; fi

        # plot course of minimisation (potential energy)
        echo "Potential" | g_energy -f em.edr -o em_energy.xvg
        grace -hardcopy -hdevice SVG -printfile em_energy.svg em_energy.xvg 
    else
        echo "Using EM already computed in a previous run."
    fi
fi


if [ "$equilibrate" = 'yes' ] ; then
    if [ ! -e eq_nvt_200ps.pdb ] ; then
        banner "  N V T "
        make_eq_nvt_200ps_config $ngroups
        echo ""
        echo ">>> Running NVT equilibration."
        # we have eq_nvt_200ps.mdp, em.pdb, em.gro and em.top
        if ! run_md eq_nvt_200ps em ; then exit $ERROR ; fi
        analyze_md_run eq_nvt_200ps $ligands
    else
        echo "Using NVT equilibration computed in a previous run."
    fi    
fi


if [ "$equilibrate" = 'yes' ] ; then
    if [ ! -e eq_npt_200ps.pdb ] ; then
        banner "  N P T "
        make_eq_npt_200ps_config $ngroups
        echo ""
        echo ">>> Running NPT equilibration."
        if ! run_md eq_npt_200ps eq_nvt_200ps ; then exit $ERROR ; fi
        analyze_md_run eq_npt_200ps $ligands
    else
        echo "Using NPT equilibration computed in a previous run."
    fi    
fi



# ### JR ###
# in the following, we could make an initial file and then add
# cycles using gromacs tpbconv facility to add additional ps of
# simulation as (-extend parameter is in ps)
#
# tpbconv -s input_md.tpr -o input_md_extended.tpr -extend 5000
# mdrun -s input_md_extended.tpr -deffnm ubiquitin_md -cpi ubiquitin_md.cpt -append
#

if [ "$shortrun" = 'yes' ] ; then
    banner " M D 1 ns"
    make_md_01_config $ngroups
    if [ -e md_10.pdb ] ; then
        echo "Long runs already exist. Skipping short runs."
    else
        prev='eq_npt_200ps'
        next='none'
        for i in 01 02 03 04 05 06 07 08 09 10 ; do
            if [ ! -e md_$i.pdb ] ; then
                next=md_$i
                break;
            else
                prev=md_$i
                continue
            fi
        done
        if [ "$next" = 'none' ] ; then
            echo "You already have 10 x 1ns runs."
            echo "Add long runs instead."
            exit 1
	else
            echo ""
            echo ">>> Continuing $prev for 1ns as $next."
            if [ ! -e $next.mdp ] ; then cp md_01.mdp $next.mdp ; fi
            if ! run_md $next $prev ; then exit $ERROR ; fi
            analyze_md_run $next $ligands
        fi
    fi
fi    

if [ "$longrun" = 'yes' ] ; then
    banner " MD 10 ns"
    make_md_10_config $ngroups
    prev='md_01'
    next='none'
    # first find which one was the last short run
    for i in 01 02 03 04 05 06 07 08 09 10 ; do
        if [ ! -e md_$i.pdb ] ; then
            break
        else
            prev=md_$i
            continue
        fi
    done
    # and then find out if there are any previous long runs
    for i in 10 20 30 40 50 60 70 80 90 100 ; do
        if [ ! -e md_$i.pdb ] ; then
            next=md_$i
            break
        else
            prev=md_$i
            continue
        fi
    done
    if [ "$next" = 'none' ] ; then
        echo "You already have 10 x 10 ns runs."
        echo "Longer simulations should be run manually."
        exit 1
    else
	echo ""
        echo ">>> Continuing MD run $prev for 10ns as $next."
	if [ ! -e $next.mdp ] ; then cp md_10.mdp $next.mdp ; fi
        if ! run_md $next $prev ; then exit $ERROR ; fi
	analyze_md_run $next $ligands
    fi
fi

# XXX JR XXX HACK HACK HACK HACK
# this is harmless and allows us to recover analyses from broken runs
#	TO BE REMOVED
analyze_md_run eq_nvt_200ps $ligands
analyze_md_run eq_npt_200ps $ligands
analyze_md_run md_01 $ligands
analyze_md_run md_10 $ligands

for i in *.gro ; do
    if [ ! -s $i ] ; then continue ; fi
    if [ ! -s `basename $i gro`pdb ] ; then 
        $editconf -f $i -o `basename $i gro`pdb
    fi
done
cd ..

# Visualize results
grace=`which grace`
if [ "$grace" = "" ] ; then
    echo ""
    echo ">>> You can convert XVG files to SVG (for publication) using"
    echo ""
    echo "    for i in *.xvg ; do"
    echo "       \$grace  -hardcopy -hdevice SVG -printfile \`basename \$i xvg\`svg \$i  -pexec 'runavg(S0,100)'"
    echo "    done"
    echo ""
else
    for i in *.xvg ; do
        svg=`basename $i xvg`xvg
	if [ ! -e "$svg" ] ; then
	    $grace $i \
	        -hardcopy -hdevice SVG \
		-printfile $svg \
		-pexec 'runavg(S0, 100)'
	fi
    done
fi
echo ""
echo ">>> You can visualize trajectories with VMD using:"
echo ""
echo "    # vmd md.gro md.trr"
echo ""
echo ">>> You can also visualize trajectories with UCSF Chimera"
echo ">>> and PyMol if you like"
echo ""

echo '

                FINISHE         E     N         A#FINE
                D               TR    I         C     C 
                #               # M   F         A     A    
                ENDED           E  I  #         B     P
                #               D   N D         A     U
                #               N    AE         D     T
                FINITO#         E     T         O#END#

'
