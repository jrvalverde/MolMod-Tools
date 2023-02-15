#!/bin/bash
#
export BABEL_PATH=~/contrib/openbabel/bin
export CHIMERA_PATH=~/contrib/chimera/bin
export PROFIT_PATH=~/contrib/bioinf.org.ac.uk/ProFitV3.1/

export PATH=$BABEL_PATH:$PATH
export PATH=$CHIMERA_PATH:$PATH
export PATH=$PROFIT_PATH:$PATH

export babel=`which babel`
export obminimize=`which obminimize`
export chimera=`which chimera`
export ctioga2=`which ctioga2`
export ProFit=`which ProFit`

myname=`basename "${BASH_SOURCE[0]}"`
mydir=`dirname "${BASH_SOURCE[0]}"`

function usage() {
    cat <<END
    
    Usage: $myname -i input.pdb -h add_H_method -p pH 
    
    Minimize a structure in a PDB file using openBabel
    
    Parameters:

                -?	print this help
		-f      force field to use (must be supported by openBabel
		-c      method to assign partial charges (gasteiger)
        	-i	input file in PDB format
                -h	add H to the system using the method specified
			(chimera babel or any openBabel supported method) 
                -p      pH to consider when adding H (if method is chimera
		        then it will be coerced to 7.4)

END
}


# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o ?f:c:i:hm:p: \
     --long help,ff:,force-field:,charge:,input:,addH,method:,pH: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
        	-\?|--help)
                    usage ; exit 0 ;;
		-f|--ff|--force-field)
		    # force field
		    ff=$2 ; shift 2 ;;
		-c|--charge)
		    # force field
		    charges=$2 ; shift 2 ;;
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
                    addHmethod=$2 ; 
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
		*) echo "ERROR: Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done





# options can be listed with babel -L forcefields
ff=${ff:$1}
pdb=${input:$2}
name=`basename $pdb .pdb`
addHmethod=${addHmethod:"none"}	# chimera, babel or none
energyplot='Y'		# plot energy change during minimization
profitrms='Y'		# compute RMS of minimized structure

addH=${addH:'not'}
if [ $addHmethod == "babel" ] ; then
    pH=${pH:7.365}
    dir=obm_${name}_${ff}_pH_$pH
else 
  if [ $addHmethod == "chimera" ] ; then
    echo "WARNING: adding H with chimera, pH coerced to 7.4"
    pH="7.4"
    dir=obm_${name}_${ff}_pH_${pH}c
  else
    dir=obm_${name}_${ff}
  fi
fi

# check it is a valid force field
$babel -L forcefields | grep -q -i "^$ff "
if [ $? -ne 0 ] ; then
	echo "Selected force field [$ff] is not valid"
	$babel -L forcefields
        exit 1
fi

if [ ! -d $dir ] ; then
    if [ -e $dir ] ; then
        echo "Error: $dir exists and is not a directory"
        exit 1
    fi
    mkdir $dir
fi

# NOTE: obminimize outputs a PDB file without H
#	obminimize fails to work correctly if the input lacks H
#	therefore we must add appropiate H and charges before minimization
# addHmethod can be 'babel' 'chimera' or 'none'

#	Babel does not know about nucleic acids and produces wrong
#	protonation of the nucleotides
#	UCSF chimera seems to do the right thing
if [ "$addHmethod" == "babel" ] ; then 
    # check that the charge method selected is supported by babel
    # options can be listed with babel -L charges
    if [ "$charges" != '' ] ; then
      $babel -L charges | grep -q -i "^$charges "
      if [ $? -ne 0 ] ; then
	    echo "Selected charge method [$charges] is not valid"
	    $babel -L charges
            exit 1
      fi
    else # no charge method selected, use defaults
      if [ "$ff" == "mmff94" -o "$ff" == "mmff94s" ] ; then 
	  charges="mmff94"
      else
	  charges="gasteiger"
      fi
    fi

    if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
        # print command to log file
        echo "$babel -h -p 7.365 --center --partialcharge $charges \\
	    -ipdb $pdb -opdb $dir/$name.H.pdb |& \\
            tee -a $dir/${name}.H_${ff}.log \\
            " | tee -a $dir/${name}.H_${ff}.log
        # do it
        $babel -h -p 7.365 --center  \
	    -ipdb $pdb -opdb $dir/$name.H.pdb |& \
            tee -a $dir/${name}.H_${ff}.log
    fi
elif [ $addHmethod == "chimera" ] ; then
    # we will use our default charge models (ff14SB for std and 
    # gasteiger for non-std residues)
    # reason is this tool is intended for quick calculations
    if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
      echo "NOTE: adding ions and hydrogens using UCSF Chimera"
      $chimera --nogui <<END |& tee -a $dir/${name}.H_${ff}.log 
        open $pdb
        delete element.H
        addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
	delete solvent
	addcharge all chargeModel ff14sb method gas
	write format pdb 0 $dir/$name.H.pdb
        stop now
	#solvate shell TIP3PBOX 5
	# We next need to add ions, but can't easily do it, so we'll leave 
	# automatic solvation out for now.
END
    fi
else
    cp $pdb $dir/${name}.H.pdb
fi

# check we are OK (we should)
if [ ! -s $dir/${name}.H.pdb ] ; then
    echo "Something went wrong with preparation of the model"
    exit 1
fi


# Do the minimization
if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
    echo "$obminimize -ff ${ff} -sd -c 1e-5 -n 5000 \\
       -newton -cut -rvdw 6.0 -rele 10.0 -pf 10  $dir/$name.H.pdb \\ 
       2>&1 > $dir/${name}.H_${ff}.pdb | \\
        tee -a $dir/${name}.H_${ff}.log

       " | tee -a $dir/${name}.H_${ff}.log
    #
    $obminimize -ff ${ff} -sd -c 1e-5 -n 5000 \
	-newton -cut -rvdw 6.0 -rele 10.0 -pf 10 $dir/$name.H.pdb \
	2>&1 > $dir/${name}.H_${ff}.pdb | \
        tee -a $dir/${name}.H_${ff}.log
fi


# extract last energy
if [ -s $dir/${name}.H_${ff}.log ] ; then
  # for directories with too many files or files with spaces, this may be better
  # if test -n "$(find $dir -maxdepth 1 -name 'E=*' -print -quit)" ; then
  # but as we expect few files, this is better
  #if ! ls $dir/E=*  1> /dev/null 2>&1 ; then
  if ! stat --printf='' $dir/E=*  1> /dev/null 2>&1 ; then
    # Save last energy for quick inspection
    lastE=`tail -2 $dir/${name}.H_${ff}.log | head -1 | tr -s ' ' '\t'` 
    echo "$lastE" > $dir/E=`echo "$lastE" | cut -f3`
  fi
else
  echo "WARNING: no log file $dir/${name}.H_${ff}.log found"
fi


# Plot energy evolution
if [ $energyplot=='Y' ] ; then
  if [ ! -s $dir/${name}.H_${ff}.pdf ] ; then
  # make a plot of the energy progression during minimization
    if [ -s $dir/${name}.H_${ff}.log ] ; then
      echo "Plotting energy change"
      cd $dir
	csplit ${name}.H_${ff}.log "/^----------/" > /dev/null 2>&1
	if [ -e xx01 ] ; then
	  # skip first two values as they will often be VERY VERY VERY LARGE
	  tail -n +4 xx01 | head -n -1 > xxtable
	  #ls -l
	  $ctioga2 --title "Energy" --ylabel "Energy" --xlabel "Step" xxtable
	  #rm xx00 xx01 xxtable
          rm xx*
          # in case ctioga2 is not available or fails (e.g. on a non-X system)
	  if [ -s Plot-000.pdf ] ; then
            mv Plot-000.pdf ${name}.H_${ff}.pdf
	  fi
        else
          echo "WARNING: no energies in $dir/${name}.H_${ff}.log!"
          #ls -l
        fi
      cd ..
    else
      echo "WARNING: No log file $dir/${name}.H_${ff}.log found"
    fi
  fi
fi


# Plot per a.a. RMSD
if [ $profitrms=='Y' ] ; then
  if [ ! -s $dir/${name}.H_${ff}.aa.pdf ] ; then
    # compare 
    echo "Computing RMSD"
    r=$name.pdb
    m=$dir/${name}.H_${ff}.pdb
    rmsd=$dir/${name}.H_${ff}.rmsd
    aarmsd=$dir/${name}.H_${ff}.aa.rmsd
    if [ ! -s $aarmsd ] ; then
      if [ -s $r -a -s $m ] ; then
	$ProFit <<END |& tee $rmsd
          REFERENCE $r
          MOBILE $m
          FIT
          RESIDUE $aarmsd
#	  align all chains redgardless of chain ID
#	  ALIGN WHOLE
#	  align only specific chains
#	  ALIGN A:*,A:*
#	  ALIGN B:*,B:* APPEND
#	  trim the ends of the aligned zones and add gaps allowing for a 
#	  like versus like comparison by using fitting zones that are common
#	  to all the structures
#	  TRIMZONES
#	  match only C, Cα, N and O
#	  ATOMS N,CA,C,O
#	  WRITE fitted.pdb
END
      else
          echo "ERROR: cannot make RMSD calculation"
      fi
    fi
    # check again to see if it has been made
    if [ -s $aarmsd ] ; then    
      cat $aarmsd | cut -c1-7,37-42 | tr -d [A-Z] > $dir/aa.rms
      ctioga2 --plot $dir/aa.rms \
              --title "RMSD by a.a." \
	      --xlabel "a.a." \
	      --ylabel "RMSD (Å)"
      #rm aa.rms
      if [ -s Plot-000.pdf ] ; then
	mv Plot-000.pdf $dir/${name}.H_${ff}.aa.pdf
      fi
    fi
  fi
fi
