#!/bin/bash

LIB=${LIB:-`dirname $0`/lib}
source $LIB/include.bash
include util_funcs.bash
include add_H.bash
include gmx_setup_cmds.bash
include gmx_config_em.bash
include gmx_config_nvt.bash
include gmx_config_npt.bash
include gmx_config_md.bash
include gmx_xvg_plot.bash
include gmx_make_ext_index.bash

export AMBERHOME=~/contrib/amber14
export PATH=~/contrib/acpype:~/contrib/amber14/bin:~/contrib/openbabel/bin:$PATH
export GMX_TOP=~/share/gromacs/top
# this overrides the value in the included libraries
export DSSP=~/bin/dssp
export acpype=`which acpype`
export mdrun="gmx mdrun -nt 24 -ntmpi 1"

#defaults
MPI='no'
MPInodes=24
ligands='./LIGANDS'
addH='no'		# yes or no
addHmethod='chimera'	# chimera or babel
solvate='no'		# solvate (yes or no)
counterions='no'        # add counterions to neutralize system charges
useSaline='no'		# use physiologic saline serum (with extra Na and Cl)
pH=7.365		# default pH for babel H assignment
temperature='310'	# target temperature (in Kelvin) 310K=room temperature
pressure='1.0'		# target pressure (in bar) 1bar=sea level atmospherice pressure
optimize='no'		# add an optimization run
equilibrate='no'	# add an equilibration run
shortrun='no'		# add a 1 ns MD production run
longrun='no'		# add a 10 ns MD production run
verbose='no'		# produce additional output

myname=`basename $0`

chimera=chimera
babel=obabel

#
#	Utility functions
#

function usage {
    cat <<END

    Usage: $myname -i input.pdb -h -p pH -m add_H_method -s -c -S -l ligands
    		   -T Temp -P Press -O -E -M -L
    
    	Run a full Gromacs simulation using the AMBER force field.
        
	if -h is used, then H will be added to the system. By default
        a physiologic pH is used. H may be added using Chimera, or
        babel, in which case, a different pH may be specified with -p
        
        This command will analyze the input file looking for ligands, and
        if any are found, will generate the parameters for them using
        ACPYPE. A list of ligands to process can be given instead, and
        in this case, charges for each ligand may be specified.
        
        Once all parameters have been generated, the system will be
        solvated and ions will be added to compensate charges (-s) or,
        if -S is specified, to simulate physiologic saline serum.
        
        After the system has been set up, it will be energy minimized,
        equilibrated, first in NVT and then in NPT, and finally an MD
        run in NPT will be computed.
        
        At each step, relevant statistics will be collected.
        
        Parameters:

                -?	print this help
        	-i	input file in PDB format
                -h	add H to the system
                -m	method to use for adding H (chimera or babel)
		-p	pH to consider for adding H (only used if method
                	is babel) [7.365]
                -s	solvate 
                -c	add counterions to neutralize system charges
                	(implies -s/solvate)
                -S	solvate using physiologic saline serum 
                	(implies -s/solvate and cancels -c/counterions)
                -l	file with a list of ligands, format is
                	'LIG	charge'
                -T	target temperature in Kelvin [310]
                -P	target pressure in bar [1.0]
                -O	add an optimization (energy minimization) run
                -E	add an equilibration run (implies -O)
                -M	add a short 5ns MD run (implies -O -E -A)  
                -L	add a longer 20ns MD run (implies -O -E -M -A)
		-A	analyze MD run
        
        Other files:
        	\$LIG.mol2 for any ligand \$LIG, if a \$LIG.mol2 file exists, it
                	will be used to assign charges to its atoms (instead
                        of using SQM BCC1 or Gasteiger charges if that fails)

END

}

# banner:
# available in 'util_funcs.bash'
# addH:
# available in 'add_H.bash'
# config_em:
# available in 'gmx_config_em.bash'
# config_nvt:
# available in 'gmx_config_nvt.bash'
# config_npt:
# available in 'gmx_config_npt.bash'
# config_md:
# available in 'gmx_config_md.bash'
# config_xpm2ps:
# latest versions of GROMACS cannot generate the ACF with g_gyr
if [ "YES" = "NO" ]; then
	function config_xpm2ps() {

    	cat > ps.m2p <<END
	; Matrix options
	titlefont       = Helvetica     ; Matrix title Postscript Font name
	titlefontsize   = 20.0          ; Matrix title Font size (pt)
	legend          = yes           ; Show the legend
	legendfont      = Helvetica     ; Legend name Postscript Font name
	legendfontsize  = 12.0          ; Legend name Font size (pt)
	legendlabel                     ; Used when there is none in the .xpm
	legend2label                    ; Id. when merging two xpm s
	xbox            = 2.0           ; x-size of a matrix element
	ybox            = 20.0          ; y-size of a matrix element
	matrixspacing   = 20.0          ; Space between 2 matrices
	xoffset         = 0.0           ; Between matrix and bounding box
	yoffset         = 0.0           ; Between matrix and bounding box

	; X-axis options
	x-lineat0value  = no            ; Draw line at matrix value==0
	x-major         = 1000.0        ; Major tick spacing
	x-minor         = 500.0         ; Id. Minor ticks
	x-firstmajor    = 0.0           ; Offset for major tick
	x-majorat0      = no            ; Additional Major tick at first frame
	x-majorticklen  = 8.0           ; Length of major ticks
	x-minorticklen  = 4.0           ; Id. Minor ticks
	x-label         =               ; Used when there is none in the .xpm
	x-font          = Helvetica     ; Axis label PostScript Font
	x-fontsize      = 12            ; Axis label Font size (pt)
	x-tickfont      = Helvetica     ; Tick label PostScript Font
	x-tickfontsize  = 8             ; Tick label Font size (pt)

	;Y-axis options
	y-lineat0value  = no
	y-major         = 10.0
	y-minor         = 5.0
	y-firstmajor    = 0.0
	y-majorat0      = no
	y-majorticklen  = 8.0
	y-minorticklen  = 4.0
	y-label         =
	y-fontsize      = 12
	y-font          = Helvetica
	y-tickfontsize  = 8
	y-tickfont      = Helvetica
END

	}
fi



if [ $# == 0 ] ; then
	usage ; exit 1
fi

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o ?i:hm:p:scSl:T:P:OEMLAv \
     --long help,input:,addH,method:,pH:,solvate,counterions,saline,ligands:,temperature:,pressure:,optimize,equilibrate,shortmd,longmd,analyze,verbose \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
        	-\?|--help)
                    usage ; exit 0 ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
                    if [ ! -s $2 ] ; then
			echo ""
                    	echo "ERROR: $2 doesn't exist or is empty"
                    	usage ; exit 1
                    fi
		    input=$2 ; shift 2 ;;
		-h|--addH) 
		    addH='yes' 
                    addHmethod="gromacs"
		    shift ;;
                -m|--method)
                    if [ "$2" == 'chimera' -o "$2" == "babel" -o "$2" == "gromacs" ] ; then
                        addHmethod=$2 ; 
                    else
                        usage; exit 1
                    fi
                    shift 2 ;;
                -p|--pH)
                    # check $2 is a positive real number
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pH=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
                -c|--counterions)
                    counterions='yes'
                    solvate='yes'
                    shift ;;
		-s|--solvate)
                    solvate='yes'
                    shift ;;
                -S|--saline)
                    solvate='yes'
                    useSaline='yes'
                    counterions='no'
                    shift ;;
                -l|--ligands)
                    if [ ! -s $2 ] ; then
                        echo ""
                    	echo "ERROR: $2 doesn't exist or is empty"
                    	usage ; exit 1
                    fi
                    ligands=$2
                    shift 2 ;;             
		-T|--temperature)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        temperature=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
		-P|--pressure)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pressure=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
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
		-A|--analyze-md)
		    analyze='yes' ; shift 1 ;;
    
                -v|--verbose)
                    verbose='yes'
					shift ;;
                --) shift ; break ;;
		*) echo "ERROR: Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

echo ""
banner " AMBER MD"
echo ""
echo "input: $input"
echo "add-H: $addH"
echo "method: $addHmethod"
echo "pH: $pH"
echo "T: $temperature"
echo "P: $pressure"
echo "solvate: $solvate"
echo "saline: $useSaline"
echo "ligands: $ligands"
echo "optimize: $optimize"
echo "equilibrate: $equilibrate"
echo "short MD run (5ns): $shortrun"
echo "long MD run (20ns): $longrun"
echo "analyze: $analyze"
echo "verbose: $verbose"

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

if [ ! "$ext" == "pdb" -a ! "$ext" == "brk" ] ; then
    echo "ERROR: Input file must be a PDB file"
    usage ; exit 1
fi

## DEFINE OUTPUT DIRECTORY NAME
##
# name=`basename $1 .pdb`_Hc_pH7.4_hoh_ion
# echo $name
name=amber_${nam}

if [ $addH == 'yes' ] ; then
    if [ $addHmethod == 'chimera' ] ; then
        name=${name}_Hc
    elif [ $addHmethod == 'babel' ] ; then
        name=${name}_pH${pH}
        name=${name}_Hb
    else
        name=${name}_H
    fi
fi
if [ $useSaline == 'yes' ] ; then
    name=${name}_150mM
elif [ $solvate == 'yes' ] ; then
    name=${name}_hoh
    if [ $counterions == 'yes' ] ; then
	name=${name}_ions
    fi
fi

# if we are only doing an optimization then we work at 0°K
if [ $optimize = 'yes' -a \
     $equilibrate = 'no' -a \
     $shortrun = 'no' -a \
     $longrun = 'no' ] ; then
    temperature=0
fi
name=${name}_${temperature}K

echo "wd:" `pwd`
echo "output: $name"
echo ""

if [ -e $name -a ! -d $name ] ; then 
    echo "ERROR: $name exists and is not a directory"
    exit 
fi

mkdir -p $name
# redirect all output to log files (one for stdout and one for stderr)
#log=./$name/log.$myname.outerr
#$appendlog='-a'
#$appendlog=''
#exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")
stdout=./$name/log.$myname.out
stderr=./$name/log.$myname.err
if [ "$verbose" == 'yes' ] ; then
    exec | tee $stdout 2| tee $stderr
else
    exec > $stdout 2> $stderr
fi

echo ""
banner " AMBER MD"
echo ""
echo "input: $input"
echo "add-H: $addH"
echo "method: $addHmethod"
echo "pH: $pH"
echo "T: $temperature"
echo "P: $pressure"
echo "solvate: $solvate"
echo "saline: $useSaline"
echo "ligands: $ligands"
echo "optimize: $optimize"
echo "equilibrate: $equilibrate"
echo "short MD run (1ns): $shortrun"
echo "long MD run (10ns): $longrun"
echo "analyze: $analyze"
echo "verbose: $verbose"
echo "output: $name"
echo "wd:" `pwd`
echo '
#-------------------------------------------------------------------------
#		PREPARE SYSTEM
#-------------------------------------------------------------------------
'
banner ' SET UP'

# Copy input files to work directory
# input file
cp $input $name/Orig.pdb

# ligands
if [ -f "$ligands" ] ; then
    cp $ligands $name/
    # check if there are .mol2 or .pdb files to copy
    cut -f1 $ligands | while read lig ; do
	if [ -s $lig.mol2 ] ; then
            cp $lig.mol2 $name
        fi
	if [ -s $lig.pdb ] ; then
            cp $lig.pdb $name
        fi
    done
    # NOTE: later on we will simply check for the existence
    # of the .mol2 files inside the directory.
    # This is so because that way, if the calculation fails,
    # then we can add them later inside the work directory 
    # and restart the calculation to use those new ones.
fi


# FROM NOW ON, WORK INSIDE THE OUTPUT DIRECTORY
cd $name

#
# THERE WE GO!
#
if [ ! -s OrigComplex.pdb ] ; then
    if [ $addH == 'yes' ] ; then
        # remove all H (we'll add them to suit our desired pH)
        #
        if [ "$verbose" == 'yes' ] ; then echo "Removing H" ; fi
        grep -v " H " Orig.pdb | grep -v "^CONECT" | grep -v "^WARNING" \
	    > OrigComplex.pdb
    else
        cp Orig.pdb OrigComplex.pdb
        cp Orig.pdb OrigComplex+H.pdb
    fi
fi
echo "Original complex created"

echo "Adding H"
# Note: maybe this should happen AFTER separating any ligands to 
# avoid alterating them(?)
if [ ! -s OrigComplex+H.pdb ] ; then
    add_H OrigComplex.pdb $method

	if [ "YES" = "NO" ]; then
    	if [ $addHmethod == 'babel' ] ; then
        	echo "Adding hydrogens with OpenBabel"
        	addHbabel OrigComplex.pdb $charges
		# will produce OrigComplex+H.pdb
    	elif [ $addHmethod == 'chimera' ] ; then
        	echo "Adding hydrogens with UCSF Chimera"
        	addHchimera OrigComplex.pdb
	    	# will produce OrigComplex+H.pdb
		else
        	echo "Feeding original geometry 'as is' to GROMACS"
        	# no H to add, or Gromacs method, use input structure 'as is'
        	egrep  '(^ATOM)|(^HETATM)|(^CONECT)' OrigComplex.pdb > OrigComplex+H.pdb
    	fi
	fi
fi
echo "OrigComplex protonated"

# ------------------------------------------------------------------------
# Separate ligands and Protein
echo "Extracting ligands"
if [ ! -s Protein.pdb ] ; then
    # we can't check for the ligands as we still do not know them, so
    # we only check for existence of the protein.

    # get a starting model, we'll remove the ligands next
    cp OrigComplex+H.pdb Protein.pdb

    # get list of ligands
    if [ ! -e $ligands ] ; then
        grep '^HETATM' OrigComplex+H.pdb | cut -c18-21 | uniq | grep -v ' MG '
    else
        # format of LIGANDS is 'LIG	charge'
        if [ "$ligands" != "LIGANDS" ] ; then
            cp $ligands LIGANDS
        fi
        cut -f1 LIGANDS 
    fi \
    | while read lig ; do	# in a subshell
        charge=0
        if [ -e LIGANDS ] ; then charge=`grep $lig LIGANDS | cut -f2` ; fi
        # compute multiplicity
        # HEURISTIC: assume all charges are due to e- that yield unpaired spin
        mult=$(( ${charge#-} + 1 ))
        echo ""
        #echo $lig $charge $mult
        banner "$lig $charge $mult"
        echo ""

        # extract ligand with the H already added
        # and remove it from the protein
        if [ $addHmethod == 'babel' ] ; then
            grep -h "^HETATM.* $lig" Protein.pdb > het$lig.pdb
    	    # remove ligand from protein
    	    grep -v "^HETATM.* $lig" Protein.pdb > Prot.pdb
    	    mv Prot.pdb Protein.pdb
        else 
      	    # for all the other cases, use Chimera    
    	    # Using Chimera helps keep/remove the CONECT records
	    $chimera --nogui <<END
                open Protein.pdb
                select #0:$lig
                write selected format pdb 0 het$lig.pdb
                delete #0:$lig
                write format pdb 0 Protein.pdb
                stop now
END
	    egrep '(^ATOM)|(^HETATM)|(^CONECT)' het$lig.pdb > het.pdb
            mv het.pdb het$lig.pdb
        fi


        #
        #	We'll try to generate the ligand parameters from scratch.
        #	Most likely this will fail to produce accurate AM1/BCC
        #	charges if the molecules are ionized. In that case, we
        #	resort to Gasteiger charges.
        #
        #	There is a scape though: you can compute charges elsewhere
        #	(e.g. in Chimera, Gabedit, using Mopac, or any other such)
        #       first, using AM1/BCC or whatever method, and save the files
        #	on the working directory as MOL2 files. Then these charges
        #	(hopefully more accurate) will be used instead. 
        #	You may even use babel --partialcharge {mmff94|eem|gasteiger}
        #	but babel has shown various problems adding H with -h -p 7.4 
        #	(e.g. with ATP).
        #
        if [ -e $lig.acpype ] ; then continue ; fi
        # add AM1-BCC charges with GAFF atom types and save as .mol2
        if [ ! -e $lig.mol2 -o ! -e $lig.pdb ] ; then
            # try to assign charges using Chimera and antechamber
            echo "Attempting to asssign charges using Chimera"
            $chimera --nogui <<END
                open het$lig.pdb
                #addh inisolation true hbond true
                addcharge all chargeModel 99sb method am1
                write format mol2 0 $lig.mol2
                write format pdb  0 $lig.pdb
                stop now
END
	    # NOTE: review the output to check that all went as expected.
            #	If there is something wrong, CORRECT THE ORIGINAL PDB FILE.
        fi
        # if a MOL2 file is available, assume it has charges and use them
        if [ -e $lig.mol2 ] ; then
          # use user charges
          #$acpype -i $lig.mol2 -n $charge -m $mult -b $lig -r -l -a amber -c user
          $acpype -i $lig.mol2 -n $charge -m $mult -b $lig -z -l -a amber -c user
          # if  MOL2 file failed, then resort to Gasteiger charges
          if [ $? -eq 1 ] ; then
              echo "COULD NOT USE MOL2 FILE CHARGES. USING GASTEIGER CHARGES"
              #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a amber -c gas
              $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a amber -c gas
          fi
        else
          # compute charges using SQM
          #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a amber
          $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a amber
          # if SQM failed, then resort to Gasteiger charges
          if [ $? -eq 1 ] ; then
              echo "COULD NOT USE SQM. USING GASTEIGER CHARGES"
              #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a amber -c gas
              $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a amber -c gas
          fi
        fi
    done
fi
echo "Separated Protein and ligands"


echo "Merging back protein and ligands"
if [ ! -e Complex.pdb -o ! -e Complex.top ] ; then
    # we need to merge back now the protein and the updated ligands, but this
    # requires that we first generate the topology for the protein:
    # this step will add H using GROMACS if they are missing 

    if [ "$addH" = 'no' -o "$addHmethod" = 'chimera' -o "$addHmethod" = 'babel' ] ; then
        $pdb2gmx -ff amber99sb -f Protein.pdb -o Protein2.pdb -p Protein.top \
	    -water spce -i
    else
        # add H ourselves
        $pdb2gmx -ff amber99sb -f Protein.pdb -o Protein2.pdb -p Protein.top \
	    -water spce -ignh -i
    fi

    if [ $? -ne 0 ] ; then exit ; fi

    # 
    # Merge Protein2.pdb + updated Ligand_NEW.pdb -> Complex.pdb
    #    NOTE: Ligand_NEW contains ALL the hydrogens, so it is not
    #    ionized as we would expect!
    #    Furthermore, they'll likely belong all to the same chain
    #    and Gromacs will try to connect them.
    grep -h ATOM Protein2.pdb *.acpype/*_NEW.pdb >| Complex.pdb
    #
    #grep -h ATOM Protein2.pdb > Complex.pdb
    #grep -h HETATM Lig*.pdb | sed -e 's/HETATM/ATOM  /g' >> Complex.pdb

    # Edit Protein.top -> Complex.top
    cp Protein.top Complex.top
    
    # check there are indeed ligands to add
    if [ `ls -1f *.acpype 2>&/dev/null | wc -l` -ne 0 ] ; then 
        echo "Adding ligands to complex"
        for i in *.acpype ; do
            lig=`basename $i .acpype`
            if [ ! -e $lig.itp ] ; then
                # remove atomtypes (we only want them included once
                # at the beginning, hence we'll process them separately
                cat $i/*_GMX.itp | sed -n '1,/atomtypes/p;/moleculetype/,$p' | \
                    grep -v " atomtypes " > $lig.itp
                sed -n -e '/atomtypes/,/^$/p' $i/*_GMX.itp >> atomtypes
            fi

            cat Complex.top | sed "/forcefield\.itp\"/a\
        #include \"$lig.itp\"\
        " >| Complex2.top

            echo "$lig      1" >> Complex2.top
            mv Complex2.top Complex.top
        done
         # now insert any new atom types before the ligands
        if [ ! -e atomtypes.itp ] ; then
            echo "[ atomtypes ]" > atomtypes.itp
            #echo "; name    at.num      mass     charge   ptype  sigma         epsilon" >> atomtypes.itp
            # first ensure there are no duplicates
            export IFS=''
            newatoms='0'
            #sort atomtypes | uniq | grep "^ " | \
            while read line ; do 
                atom=`echo $line | cut -c 1-3 | tr -d ' '`
                echo "${atom}=${line}"
                grep -q "^$atom " $GMX_TOP/amber99sb.ff/ffnonbonded.itp
                if [ $? -ne 0 ] ; then 
                    echo "NOT FOUND: $line" 
                    echo "$line" >> atomtypes.itp
                    newatoms=$(($newatoms+1))
                fi
            done < <(sort atomtypes | uniq | grep "^ ")
            echo "" >> atomtypes.itp
            if [ $newatoms -gt 0 ] ; then
                banner " WARNING!"
                echo "New atom types defined"
                echo "Edit the file 'atomtypes.itp' to revise new atom num, mass and charge"
                echo "See $GMX_TOP/amber99sb.ff/ffnonbonded.itp as reference"
                exit
            fi
        fi
        #rm atomtypes
        cat Complex.top | sed "/forcefield\.itp\"/a\
        #include \"atomtypes.itp\"\
        " >| Complex2.top
        mv Complex2.top Complex.top
    fi
fi
echo "Complex reconstituted"
echo ""

# create simulation box
# XXX JR XXX
# we use a triclinic box (maybe the kind of box should be a parameter?)
# and a 1.0 nm edge (for large complexes this should be a parameter too)
echo "Building a triclinic, +1.0nm simulation box"
if [ ! -e Complex_b4ion.pdb ] ; then
    # Setup the PBC box
    #	we should prefer -bt dodecahedron
    #	allow for 1.0 nm between protein and box edges
    $editconf -bt triclinic -f Complex.pdb -o Complex_PBC.pdb -d 1.0

    if [ $? -ne 0 ] ; then exit ; fi

    if [ $solvate == 'yes' ] ; then
        # Fill the box with water from SPC216.
        $genbox -cp Complex_PBC.pdb -cs spc216.gro -o Complex_b4ion.pdb -p Complex.top
    else
	cp Complex_PBC.pdb Complex_b4ion.pdb
    fi

    if [ $? -ne 0 ] ; then exit ; fi

fi
echo "Triclinic box created"



echo '
#-------------------------------------------------------------------------
#				ADD IONS 
#-------------------------------------------------------------------------
'
if [ ! -s em.mdp ] ; then
    if [ "$solvate" = "yes" ] ; then
        gmx_config_em
    else
        gmx_config_em_vacuum
    fi
fi

if [ ! -s Complex_b4em.pdb ] ; then
    # Add ions
    # we expect a warning because we still haven't charge-equilibrated the system
    # and we may have non-zero total charge.
    $grompp -maxwarn 1 -f em.mdp -c Complex_b4ion.pdb -p Complex.top -o Complex_b4ion.tpr
    if [ $? -ne 0 ] ; then exit ; fi

    cp Complex.top Complex_ion.top
	mv mdout.mdp addion_out.mdp

    if [ $useSaline == 'yes' ] ; then
        # Use a concentration of 150 mM and a neutral system
        # 	we have MG, ATP and UD1, so SOL should be 14+3
	#	place ions using based on potenrial instead of randomly
        echo "SOL" | $genion -s Complex_b4ion.tpr -o Complex_b4em.pdb \
        	-neutral -conc 0.15 -p Complex_ion.top #-norandom
        if [ $? -ne 0 ] ; then exit ; fi
    elif [ $counterions == 'yes' ] ; then
        # Only equilibrate charges
        #	place ions randomly
        echo "SOL" | $genion -s Complex_b4ion.tpr -o Complex_b4em.pdb -neutral -p Complex_ion.top
        if [ $? -ne 0 ] ; then exit ; fi
    else
	# do not modify
        cp Complex_b4ion.pdb Complex_b4em.pdb
    fi


    mv Complex_ion.top Complex.top
fi

n=`out='no' grep  -v "^[;#]" Complex.top | while read line ; do 
        if [ "$out" == 'yes' ] ; then 
            echo $line 
        fi 
    	if [ "$line" == "[ molecules ]" ] ; then 
            out="yes" 
        fi
    done | grep -v '^\[' | grep -v "^Protein" | wc -l`
if [ $n -eq 0 ] ; then
    grp="Protein"
	tau="0.1"
	ref_t="$temperature"
else
    # XXX JR XXX THIS SHOULD BE "SOLUTE SOLVENT"
	grp="Protein Non-Protein"
	tau_t="0.1 0.1"
	ref_t="$temperature $temperature"
fi

#anner $n
#cho "grp=$grp"
#cho "tau_t=$tau_t"
#cho "ref_t=$ref_t"

# check if an optimization has been requested
#	note that if equilibration or MD are requested,
#	then optimization is forced as well, i.e.
#	if there is no optimization there cannot be
#	equilibration or MD either, but there may be a
#	request to analyze an existing trajectory
#cho "Opt=$optimize"
if [ "$optimize" == "no" ] ; then echo "No optimization: Done" ; fi

if [ "$optimize" = 'yes' ] ; then
    echo '
#-------------------------------------------------------------------------
#				MINIMIZE ENERGY
#-------------------------------------------------------------------------
'
    banner "  E  M  "



    if [ -s em.pdb ] ; then
	    echo "em.pdb exists: Skipping energy minimization"
    else
	# Run minimisaton
	$grompp -f em.mdp -c Complex_b4em.pdb -p Complex.top -o em.tpr
	if [ $? -ne 0 ] ; then exit ; fi
	mv mdout.mdp em_out.mdp

	$mdrun -v -deffnm em
	if [ $? -ne 0 ] ; then exit ; fi
    fi
    if [ ! -e em_energy.xvg ] ; then
	# plot course of minimisation
	echo "Potential" | $g_energy -f em.edr -o em_energy.xvg
    fi
    # generate PDB file
    if [ ! -e em.pdb ] ; then
	# generate PDB file (use trjconv with a TPR reference to preserve chains)
	#$editconf -f em.gro -o em_PBC.pdb
	echo "System" | $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump
    fi
    # try again to generate PDB file
    if [ -e em.gro -a ! -e em.pdb ] ; then 
        $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump <<< 0 
    fi

    for i in *.xvg ; do if [ ! -e ${i%xvg}PNG ] ; then gmx_xvg_plot $i ; fi ; done

    echo "Energy minimization done"
fi



# Before proceeding, find out how many groups do we have for
# temperature coupling
#
# we want to treat solute and solvent as separate groups
# but if there are no non-protein atoms, then the non-protein group
# does not exist
#
#	XXX JR XXX SEE OPLS-AA.BASH
#
n=`out='no' grep  -v "^[;#]" Complex.top | while read line ; do 
        if [ "$out" == 'yes' ] ; then 
            echo $line 
        fi 
    	if [ "$line" == "[ molecules ]" ] ; then 
            out="yes" 
        fi
    done | grep -v '^\[' | grep -v "^Protein" | wc -l`


if [ $n -eq 0 ] ; then
    grp="Protein"
	tau="0.1"
	ref_t="$temperature"
else
    # XXX JR XXX THIS SHOULD BE "SOLUTE SOLVENT"
	grp="Protein Non-Protein"
	tau_t="0.1 0.1"
	ref_t="$temperature $temperature"
fi

#anner $n
#cho "grp=$grp"
#cho "tau_t=$tau_t"
#cho "ref_t=$ref_t"

# check if an equilibration has been requested
#	note that if MD has been requested,
#	then optimization and equilibration are forced 
#	as well, i.e. if there is no equilibration there 
#	cannot be MD either, but an analysis may have been
#       requested
if [ "$equilibrate" == "no" ] ; then echo "No equilibration: done" ; fi

if [ "$equilibrate" = 'yes' ] ; then
    banner " N V T  "

    echo '
    #-------------------------------------------------------------------------
    #		1: EQUILIBRATE IN NVT ENSEMBLE
    #	ISOTHERMAL-ISOCHORIC        CANONICAL ENSEMBLE
    #-------------------------------------------------------------------------
    '

    #	From: www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/06_equil.html
    #
    # EM ensured that we have a reasonable starting structure, in terms of 
    # geometry and solvent orientation. To begin real dynamics, we must equilibrate 
    # the solvent and ions around the protein. If we were to attempt unrestrained 
    # dynamics at this point, the system may collapse. The reason is that the 
    # solvent is mostly optimized within itself, and not necessarily with the 
    # solute. It needs to be brought to the temperature we wish to simulate and 
    # establish the proper orientation about the solute (the protein). After we 
    # arrive at the correct temperature (based on kinetic energies), we will apply 
    # pressure to the system until it reaches the proper density.
    #
    # Remember that posre.itp file that pdb2gmx generated a long time ago? 
    # We're going to use it now. The purpose of posre.itp is to apply a position 
    # restraining force on the heavy atoms of the protein (anything that is not 
    # a hydrogen). Movement is permitted, but only after overcoming a substantial 
    # energy penalty. The utility of position restraints is that they allow us to 
    # equilibrate our solvent around our protein, without the added variable of 
    # structural changes in the protein.
    #

    # Equilibration is often conducted in two phases. The first phase is conducted
    # under an NVT ensemble (constant Number of particles, Volume, and Temperature).
    # This ensemble is also referred to as "isothermal-isochoric" or "canonical." 
    # The timeframe for such a procedure is dependent upon the contents of the 
    # system, but in NVT, the temperature of the system should reach a plateau at 
    # the desired value. If the temperature has not yet stabilized, additional 
    # time will be required. Typically, 50-100 ps should suffice, and we will 
    # conduct a 200-ps NVT equilibration to be on the safe side.
    #
    if [ -s nvt.pdb ] ; then
	    echo "nvt.pdb exists. Skipping initial NVT equilibration"
    else
	if [ ! -e nvt.mdp ] ; then
	    # arguments may contain spaces: they must be quoted!
            gmx_config_nvt "nvt" "$temperature"
	fi

	# Run NVT equilibration
	if [ ! -e nvt.tpr ] ; then
            $grompp -f nvt.mdp -c em.gro -r em.gro -p Complex.top -o nvt.tpr
            mv mdout.mdp nvt_out.mdp
	fi

	if [ $? -ne 0 ] ; then exit ; fi

	if [ ! -e nvt.gro ] ; then 
            $mdrun -s nvt.tpr  -deffnm nvt -v
	fi

	if [ $? -ne 0 ] ; then exit ; fi

	if [ ! -e nvt.pdb ] ; then
            # generate PDB file
            #$editconf -f nvt.gro -o nvt_PBC.pdb
	     echo "System" | $trjconv -f nvt.gro -s nvt.tpr -o nvt.pdb -pbc nojump
	fi

    fi

    # Generate monitor files
    if [ ! -e nvt_pot_energy.xvg ] ; then
	# plot energy progress
	echo "Potential" | $g_energy -f nvt.edr -o nvt_pot_energy.xvg
    fi

    if [ ! -e nvt_temperature.xvg ] ; then
	# Check if equilibration was achieved (requires manual supervision)
	#	In the NVT equilibration step we want to ensure that the
	#	correct temperature was reached and stabilized.
	#	Typically 50-100ps should suffice.
	echo "Temperature" | $g_energy -f nvt.edr -o nvt_temperature.xvg
    fi
    
    for i in *.xvg ; do if [ ! -e ${i%xvg}PNG ] ; then gmx_xvg_plot $i ; fi ; done

    echo ""
    echo "NVT equilibration done"
    echo ""



    banner " N P T  "

    echo '
    #-------------------------------------------------------------------------
    #		2: EQUILIBRATE IN NPT ENSEMBLE
    #		      ISOTHERMAL-ISOBARIC
    #-------------------------------------------------------------------------
    '
    #
    #	From: www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/07_equil2.html
    #
    #
    # The previous step, NVT equilibration, stabilized the temperature of the
    # system. Prior to data collection, we must also stabilize the pressure (and 
    # thus also the density) of the system. Equilibration of pressure is conducted
    # under an NPT ensemble, wherein the Number of particles, Pressure, and 
    # Temperature are all constant. The ensemble is also called the 
    # "isothermal-isobaric" ensemble, and most closely resembles experimental 
    # conditions.
    #
    # The .mdp file used for the next NPT equilibration is not drastically
    # different from the parameter file used for NVT equilibration. Note the
    # addition of the pressure coupling section, using the Parrinello-Rahman
    # barostat.
    #
    # A few other changes:
    #
    #	continuation = yes: We are continuing the simulation from the NVT 
    #			equilibration phase
    #	gen_vel = no: Velocities are read from the trajectory (see below)
    #


    if [ -s npt.pdb ] ; then
	    echo "npt.pdb exists: Skipping subsequent NPT equilibration"
    else
	if [ ! -e npt.mdp ] ; then
            gmx_config_npt "npt" "$pressure" "$temperature"
	fi

	# Run NPT equilibration
	#                            -t nvt.trr???
	if [ ! -e npt.tpr ] ; then
            $grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p Complex.top -o npt.tpr
            mv mdout.mdp npt_out.mdp
	fi

	if [ $? -ne 0 ] ; then exit ; fi

	if [ ! -e npt.gro ] ; then
            $mdrun -s npt.tpr -deffnm npt -v
	fi

	if [ $? -ne 0 ] ; then exit ; fi

	if [ ! -e npt.pdb ] ; then
            # generate PDB file
            #$editconf -f npt.gro -o npt_PBC.pdb
	    echo "System" | $trjconv -f npt.gro -s npt.tpr -o npt.pdb -pbc nojump
	fi
    fi

    # At this point we should check that both, temperature and pressure 
    # are equilibrated
    #
    # The pressure value fluctuates widely over the course of the equilibration
    # phase, but this behavior is not unexpected. The running average of these 
    # data can be plotted as a red line in the plot. Over the course of the 
    # equilibration, the expected average value of the pressure is ~1.0 bar.
    #
    # As with the pressure, the running average of the density may also be plotted 
    # in red. The average value over the course of the simulation should be close
    # to the experimental value of 1000 kg m-3 and the expected density of the 
    # SPC/E model of 1008 kg m-3. The parameters for the SPC/E water model closely 
    # replicate experimental values for water. The density values should be very
    # stable over time, indicating that the system is well-equilibrated now with
    # respect to pressure and density.
    #

    if [ ! -e npt_pot_energy.xvg ] ; then
	# plot energy progress
	echo "Potential" | $g_energy -f npt.edr -o npt_pot_energy.xvg
	echo "Total-Energy" | $g_energy -f npt.edr -o npt_tot_energy.xvg
    fi
    if [ ! -e npt_temperature.xvg ] ; then
	# plot temperature
	echo "Temperature" | $g_energy -f npt.edr -o npt_temperature.xvg
    fi
    if [ ! -e npt_density.xvg ] ; then
	# plot density (no longer available)
	echo "Density" | $g_energy -f npt.edr -o npt_density.xvg
    fi
    if [ ! -e npt_pressure.xvg ] ; then
	# plot pressure
	echo "Pressure" | $g_energy -f npt.edr -o npt_pressure.xvg
    fi

    for i in *.xvg ; do if [ ! -e ${i%xvg}PNG ] ; then gmx_xvg_plot $i ; fi ; done

    echo "NPT equilibration done"
fi


# Check if we have been asked to do an MD simulation
#
if [ "$longrun" == 'no' -a "$shortrun" == 'no' ] ; then 
    echo "No Molecular Dynamics: done" 
fi
#
# This is an EITHER/OR approach, where we either do a short or a long run
#
if [ "$TRADITIONAL" = "YES" ] ; then
    if [ "$longrun" = "yes" -o "$shortrun" = "yes" ] ; then 

        banner "  M  D  "

        echo '
        #-------------------------------------------------------------------------
        #		RUN MD SIMULATION
        #-------------------------------------------------------------------------
        '

        #	From: http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/08_MD.html
        #
        # Upon completion of the two equilibration phases, the system is now 
        # well-equilibrated at the desired temperature and pressure. We are now 
        # ready to release the position restraints and run production MD for data 
        # collection. The process is just like we have seen before, as we will 
        # make use of the checkpoint file (which in this case now contains preserve 
        # pressure coupling information) to grompp. 

        # we should check if an MD run already exist and if so, extend it
        if [ -s md.pdb ] ; then
	        echo "md.pdb exists. Skipping MD simulation"
        else
	    dt="0.002"
	    if [ "$longrun" == "yes" ] ; then 
                md=lmd
	        ns=50			        # 50 ns
                npicos=$(( ns * 1000 ))	        # 50 000 ps
	        #echo "Doing long $time ps MD run"
	    else 
                # if we are here then $shortrun must be yes
                md=md
	        ns=10			        # 10 ns
	        npicos=$(( ns * 1000)) 	        # 10000 ps
	        #echo "Doing short $time ps MD run"
	    fi

        echo "gmx_config_md md='$md' p='$pressure' t='$temperature' dt='$dt' ps='$npicos' (ns=${ns}ns)"
	    gmx_config_md $md $pressure $temperature $dt $npicos

	    # Run simulation
	    #                           -t npt.trr???
	    $grompp -maxwarn 3 -f $md.mdp -c npt.gro -t npt.cpt -p Complex.top -o $md.tpr

	    if [ $? -ne 0 ] ; then exit ; fi

	    $mdrun -v -deffnm $md


	    if [ $? -ne 0 ] ; then exit ; fi

	    # Create PDB file
	    #$editconf -f md.gro -o md_PBC.pdb
	    echo "System" | $trjconv -f $md.gro -s $md.tpr -o $md.pdb -pbc nojump -conect
        fi

        # At this point we might collect some basic stats, but we'll leave
        # it for the next (optional) step: Analysis

        echo "MD run completed"
    fi
else
    if [ "$shortrun" = 'yes' ] ; then
        banner " MD 10 ns"
        dt="0.002"
	    smd=smd
        lmd=lmd
	    ns=10			                # 10 ns
	    npicos=$(( ns * 1000)) 	        # 10000 ps
	    
	    echo "gmx_config_md md='$smd' p='$pressure' t='$temperature' dt='$dt' ps='$npicos' (ns=${ns}ns)"

        # $ngroups is ignored for now, will not in the future
        if [ ! -s ${smd}_01.pdb ] ; then
            gmx_config_md $smd $pressure $temperature $dt $npicos $ngroups
            cp ${smd}.mdp ${smd}_01.mdp
        fi
        if [ -e ${lmd}_01.pdb ] ; then
            echo "Long runs already exist. Skipping short runs."
        else
            prev='npt'
            next='none'
            for i in 01 02 03 04 05 06 07 08 09 10 ; do
                if [ ! -e ${smd}_$i.pdb ] ; then
                    next=${smd}_$i
                    break;
                else
                    prev=${smd}_$i
                    continue
                fi
            done
            if [ "$next" = 'none' ] ; then
                echo "You already have 10 x ${ns}ns runs."
                echo "Add long runs instead."
                exit 1
	        else
                echo ""
                echo ">>> Continuing $prev for ${ns}ns as $next."
                if [ ! -e $next.mdp ] ; then cp ${smd}_01.mdp $next.mdp ; fi
                if ! gmx_run_md $next $prev ; then exit $ERROR ; fi
                #analyze_md_run $next $ligands
            fi
        fi
    fi    

    if [ "$longrun" = 'yes' ] ; then
        banner " MD 50 ns"
	    dt="0.002"
        smd=smd
        lmd=lmd
        ns=50			                # 50 ns
        npicos=$(( ns * 1000 ))	        # 50 000 ps

        echo "gmx_config_md md='$lmd' p='$pressure' t='$temperature' dt='$dt' ps='$npicos' (ns=${ns}ns)"
	    if [ ! -s ${lmd}_01.mdp ] ; then
            gmx_config_md $lmd $pressure $temperature $dt $npicos
            cp ${lmd}.mdp ${lmd}_01.mdp
        fi
        prev="${smd}_01"
        next='none'
        # first find which one was the last short run
        for i in 01 02 03 04 05 06 07 08 09 10 ; do
            if [ ! -e ${smd}_$i.pdb ] ; then
                break
            else
                prev=${smd}_$i
                continue
            fi
        done
        # and then find out if there are any previous long runs
        for i in 01 02 03 04 05 06 07 08 09 10 ; do
            if [ ! -e ${lmd}_$i.pdb ] ; then
                next=${lmd}_$i
                break
            else
                prev=${lmd}_$i
                continue
            fi
        done
        if [ "$next" = 'none' ] ; then
            echo "You already have 10 x ${ns}ns runs."
            echo "Longer simulations should be run manually."
            exit 1
        else
	        echo ""
            echo ">>> Continuing MD run $prev for ${ns}ns as $next."
	        if [ ! -e $next.mdp ] ; then cp ${lmd}_01.mdp $next.mdp ; fi
            if ! run_md $next $prev ; then exit $ERROR ; fi
	        #analyze_md_run $next $ligands
        fi
    fi

fi

# Analyze trajectory: we always do it if an MD has been requested
# otherwise, we check for presence of an 'md' fileset and analyze
# it

if [ "$longrun" = "yes" -o "$shortrun" = "yes" -o "$analyze" = "yes" ] ; then 
    echo '
    #-------------------------------------------------------------------------
    #		ANALYSE MD RUN
    #-------------------------------------------------------------------------
    '
    banner ' BASIC '
    banner 'ANALYSIS'

    if [ -e analysed ] ; then
	    echo "simulation already analysed. Skipping analysis"
    else
        gmx_make_ext_index $md.pdb
#        # create an index file
#        if [ ! -e md.ndx ] ; then
#            $make_ndx -f md.tpr -o md.ndx <<< q
#        fi
            
	# Create a low-res XTC trajectory file (TRR is high precision and larger)
	if [ ! -e md.xtc ] ; then
            echo "System" | $trjconv -f md.trr -s md.tpr -o md.xtc
	fi

	# analysis (correct trajectory for PBC)
	if [ ! -e md_noPBC.xtc ] ; then
            echo "System" | $trjconv -s md.tpr -f md.xtc -o md_noPBC.xtc -pbc mol -ur compact
	fi

	# Create trajectory without the water
	echo "Solute" | $trjconv -f md.xtc -s md.tpr -o md_complex.xtc
	echo "Solute" | $tpbconv -s md.tpr -o md_complex.tpr
	echo "Solute"  | $trjconv -s md_complex.tpr -f md_complex.xtc -o md_complex.gro -dump 0

	# fit system to itself for easier manipulation
	$trjconv -s md_complex.tpr -f md_complex.xtc -o md_complex_fit.xtc -fit rot+tran <<END
System
System
END

	# Compute various graphs
	echo "Potential" | $g_energy -f md.edr -o md_potenergy.xvg
	echo "Kinetic" | $g_energy -f md.edr -o md_kinenergy.xvg
	echo "Total-Energy" | $g_energy -f md.edr -o md_totenergy.xvg
	echo "Pressure" | $g_energy -f md.edr -o md_pressure.xvg
	echo "Temperature" | $g_energy -f md.edr -o md_temperature.xvg
	#echo "Volume" | $g_energy -f md.edr -o md_volume.xvg
	echo "Density" | $g_energy -f md.edr -o md_density.xvg

	#	1. RMSD (movement w.r.t. original conformation)
	#	Show structural stability using ns as time unit
	# use a here-document
	$g_rms -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsd.xvg -tu ns <<END
Backbone
Backbone
END
	# this is equivalent to the above using process substitution
	$g_rms -s md_complex.tpr \
	       -f md_complex_fit.xtc \
	       -o md_complex_rmsd_atp.xvg \
	       -tu ns < <( echo "non-Protein"; echo "non-Protein" )

	#	2. RMSF (movility per atom/residue)
	#	backbone
	# equivalent to 1. using a here-string
	$g_rmsf -s md_complex.tpr \
		-f md_complex_fit.xtc \
		-o md_complex_rmsf_bb.xvg \
		-res \
		<<< "Backbone"
	#	side chains
	$g_rmsf -s md_complex.tpr \
		-f md_complex_fit.xtc 	
		-o md_complex_rmsf_sc.xvg \
		<<< "SideChain"
	#	non-protein (ligands + ions)
	$g_rmsf -s md_complex.tpr \
		-f md_complex_fit.xtc \
		-o md_complex_rmsf_np.xvg \
		<<< "non-Protein"
	#	ATP
	#echo "14" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_atp.xvg -oq md_complex_rmsf_atp.xvg
	#	Makes no sense for MG (only one atom)
	#	UD1
	#echo "15" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_ud1.xvg -oq md_complex_rmsf_ud1.xvg


	#	3. Radius of gyration (compactness and stability of the structure)
	#	backbone
	# The radius of gyration of a protein is a measure of its compactness. If a 
	# protein is stably folded, it will likely maintain a relatively steady value 
	# of R_g. If a protein unfolds, its R_g will change over time. 
	#
	$g_gyrate -s md_complex.tpr \
		  -f md_complex.xtc \
		  -o md_complex_gyr.xvg \
		  <<< "Backbone"

	#	4. Compute secondary structure changes
	$do_dssp -f md_complex.xtc \
		 -s md_complex.tpr \
		 -sc md_complex_scount.xvg \
		 -o md_complex_ss.xpm \
		 -dt 10 \
		 <<< "MainChain"

        # prepare also a PostScript output
        config_xpm2ps
	$xpm2ps -f md_complex_ss.xpm -di ps.m2p -o md_complex_ubq_ss.eps



	#	5. Clusterize trajectory and output central structures in
	#	each cluster.
	#g_cluster -s md_complex.tpr -f md_complex.trr -dist rmsd-distribution.xvg \
	#	-o clusters.xpm -sz cluster-sizes.xvg -tr cluster-transitions.xpm \
	#        -ntr cluster-transitions.xvg -clid cluster-id-over-time.xvg \
	#        -cl clusters.pdb -cutoff 0.25 -method gromos -dt 10 [ -av ]
	$g_cluster -s md.tpr \
		   -f md.trr \
		   -cl clusters.pdb \
		   -cutoff 5 \
		   -method gromos \
		   -dt 10 \
		    < <( echo Protein ; echo System )

	# and now get the cluster average structures
	$g_cluster -s md.tpr \
		   -f md.xtc \
		   -cl clustav.pdb \
		   -cutoff 5 \
		   -method gromos \
		   -dt 10 \
		   -av \
		    < <( echo Protein ; echo System )


        # create an index of all ligands
#       $make_ndx  -f md.tpr -o lig.ndx <<END
#13 | 14 | 15
#q
#END

	# count H-bonds (protein vs. ligands)
	$g_hbond -f md.xtc \
		 -s md.tpr -n lig.ndx \
		 -num md_hbnum.xvg \
		 -ac md_hbac.xvg \
		 < <( echo Protein ; echo Other )

        # create an index of protein plus all ligands
    	# Remove solvent
        # It can also be done using the names quoted, and separated
        # by AND, OR, NOT... run 'gmx make_ndx' and type 'h'
        # for help
#   	if grep -q "^(\[ Solute \]" md.ndx ; then
#          # first check if there is a Solute group
#          selection='"Solute"'
#	elif grep -q "^(\[ Solvent \]" md.ndx ; then
#   	    # if there is no solute defined, check if there is a SOLVENT group
#	    selection='!"Solvent"'
#   	elif grep -q "^(\[ SOL_ION \]" md.ndx ; then
#	    # or maybe it was a protein with complexed ions
#	    selection='!"SOL_ION"'
#   	elif grep -q "^(\[ Water_and_ions \]" md.ndx ; then
#	    # if neither solute nor solvent exist, try water+ions
#	    selection='!"Water_and_ions"'
#   	elif grep -q "^(\[ Water \]" md.ndx ; then
#	    # maybe there is only water and no ions
#	    selection='!"Water"'
#       else
#           selection=""
#           if grep "^\[ Protein \]" md.ndx ; then 
#           	selection="${selection}"Protein""
#           fi
#           if grep -e "^\[ RNA\]" ; then
#               selection="${selection}RNA\n"
#           fi
#           if grep -e "^\[ DNA\]" ; then
#               selection="${selection}DNA\n"
#           fi
#           if grep -e "^[ LIG \]" ; then
#               selection="${selection}LIG\n"
#           fi
#       fi
	if [ "$selection" != "" ] ; then
	    $make_ndx  -f md.tpr -o pro+lig.ndx < <( echo -e "${selection}\nq" )
        else
            cp md.ndx pro+lig.ndx
        fi
	# protein surface area
	$g_sas -s md.tpr \
               -f md.xtc \
	       -o md_sasa.xvg \
	       -tv md_vol.xvg \
	       -n pro+lig.ndx \
	       < <( echo -e "Protein\nProtein\n" )

	# Visualise with VMD
	#vmd md.gro md.trr
	
	# plot everything so fart
	for i in *.xvg ; do
	    # generate PNG and XVG with grace, 
	    # and png, svg and pdf with feedgnuplot
	    gmx_xvg2img "$i"
	done

        touch analysed
    fi
    echo "Analysis done"
fi




# FINALLY try to convert any missing relevant gro file to pdb

# try first with trjconv and the TPR file to preserve chain information
# using the TPR file as reference and removing PBC
if [ -e em.gro -a ! -e em.pdb ] ; then $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump <<< 0 ; fi
if [ -e nvt.gro -a ! -e nvt.pdb ] ; then $trjconv -f nvt.gro -s nvt.tpr -o nvt.pdb -pbc nojump <<< 0 ; fi
if [ -e npt.gro -a ! -e npt.pdb ] ; then $trjconv -f npt.gro -s npt.tpr -o npt.pdb -pbc nojump <<< 0 ; fi
if [ -e md.gro -a ! -e md.pdb ] ; then $trjconv -f md.gro -s md.tpr -o md.pdb -pbc nojump <<< 0 ; fi

# if that failed, tray with editconf
# editconf loses chain information because .gro lacks it, it will also keep PBC
if [ -e em.gro -a ! -e em.pdb ] ; then $editconf -f em.gro -o em_PBC.pdb <<< 0 ; fi
if [ -e nvt.gro -a ! -e nvt.pdb ] ; then $editconf -f nvt.gro -o nvt_PBC.pdb <<< 0 ; fi
if [ -e npt.gro -a ! -e npt.pdb ] ; then $editconf -f npt.gro -o npt_PBC.pdb <<< 0 ; fi
if [ -e md.gro -a ! -e md.pdb ] ; then $editconf -f md.gro -o md_PBC.pdb <<< 0 ; fi


# We are done
cd ..

banner 'DONE'
