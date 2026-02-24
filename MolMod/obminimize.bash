#!/bin/bash
#
# Minimize using openbabel. Output will be in a subdirectory of CURRENT
# directory! *NOT* in a subdirectory AT the PDB file location
#
# (C) José R. Valverde CNB-CSIC 2024
#
cp $0 .			# make a copy of ourselves for future reference
# fix path
export PATH=~/contrib/openbabel/bin:$PATH

# options can be listed with $babel -L forcefields
ff=$1				# pdb file 
name=`basename $2 .pdb`
addHmethod="none"	# chimera or $babel or none
energyplot='Y'		# plot energy change during minimization
profitrms='Y'		# compute RMS of minimized structure

babel=/usr/bin/obabel

# make a numbered backup copy of a file ending in .### (dot + three digits)
# inside a subdirectory named 'bck' to avoid cluttering the file name space
# (as happened in VMS)
# 
function backup_file() {
    local f=$1
	local n=`basename $f`
	local d=`dirname $f`
    i=0
	if [ ! -s "$f" ] ; then return 0 ; fi		# sanity check
    if [ ! -d $d/bck ] ; then mkdir -p $d/bck ; fi
    while [ -e $d/bck/$n,`printf %03d $i` ] ; do
        i=$((i + 1))
    done
    echo saving $f as $d/bck/$n,`printf %03d $i`
    cp $f $d/bck/$n,`printf %03d $i`
}

#
# There we go
#

if [ $addHmethod == "$babel" ] ; then
    dir=obm_${name}_${ff}_pH_7.3
else 
  if [ $addHmethod == "chimera" ] ; then
    dir=obm_${name}_${ff}_pH_7.4c
  else
    dir=obm_${name}_${ff}
  fi
fi

# check it is a valid force field
$babel -L forcefields | grep -q -i "^$ff "
if [ $? -ne 0 ] ; then
	echo "Selected force field [$ff] is not valid"
        exit
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
#	therefore we must add appropiate H before minimization.

# options can be listed with $babel -L charges
charges="gasteiger"
if [ "$ff" == "mmff94" -o "$ff" == "mmff94s" ] ; then charges="mmff94" ; fi 

backup_file "$dir"/${name}.H_${ff}.log

#
#	$babel does not know about nucleic acids and produces wrong
#	protonation of the nucleotide
#	UCSF chimera seems to do the right thing
if [ "$addHmethod" == "$babel" ] ; then 
    if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
        echo "$babel -h -p 7.365 --center --partialcharge $charges \\
	    -ipdb $2 -opdb $dir/$name.H.pdb |& \\
            tee -a $dir/${name}.H_${ff}.log \\
    " | tee -a $dir/${name}.H_${ff}.log
    #
        $babel -h -p 7.365 --center  \
	    -ipdb $2 -opdb $dir/$name.H.pdb |& \
            tee -a $dir/${name}.H_${ff}.log
    fi
elif [ $addHmethod == "chimera" ] ; then
    if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
	echo "Removing and adding H with UCSF Chimera"
    chimera --nogui <<END |& tee -a $dir/${name}.H_${ff}.log 
        open $2
        delete solvent
	    delete element.H
        addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
	    write format pdb 0 $dir/$name.H.pdb
        stop now
	#solvate shell TIP3PBOX 5
	# We next need to add ions, but can't easily do it, so we'll leave 
	# automatic solvation out for now.
END
    fi
else	# none or an unknown method
    cp "$2" "$dir/${name}".H.pdb
fi

if [ ! -s $dir/${name}.H_${ff}.pdb ] ; then
    echo "obminimize -ff ${ff} -sd -c 1e-5 -n 5000 \\
       -newton -cut -rvdw 6.0 -rele 10.0 -pf 10  $dir/$name.H.pdb \\ 
       2>&1 > $dir/${name}.H_${ff}.pdb | \\
        tee -a $dir/${name}.H_${ff}.log

" | tee -a $dir/${name}.H_${ff}.log
#
    obminimize -ff ${ff} -sd -c 1e-5 -n 5000 \
	-newton -cut -rvdw 6.0 -rele 10.0 -pf 10 $dir/$name.H.pdb \
	2>&1 > $dir/${name}.H_${ff}.pdb | \
        tee -a $dir/${name}.H_${ff}.log

    # Save last energy for quick inspection
    lastE=`tail -2 $dir/${name}.H_${ff}.log | head -1 | tr -s ' ' '\t'` 
    echo "$lastE kJ/mol" > $dir/"E="`echo "$lastT" | cut -f3`
fi

# add a separator to the log file
echo "-----------" >> $dir/${name}.H_${ff}.log

#exit
if [ $energyplot=='Y' ] ; then
  if [ -s $dir/${name}.H_${ff}.log -a ! -s $dir/${name}.H_${ff}.E.pdf ] ; then
  # make a plot of the energy progression during minimization
    echo "Plotting energy change"
    cd $dir
      csplit ${name}.H_${ff}.log "/^------/" "{*}" > /dev/null 2>&1
      if [ ! -e xx01 ] ; then rm -f xx00 ; exit ; fi
      # skip first two values as they will usually be VERY VERY VERY LARGE
      #tail -n +4 xx01 | head -n -1 | grep -v Time > xxtable
      #ctioga2 --title "Energy" --ylabel "Energy" --xlabel "Step" xxtable
      #rm xx00 xx01 xxtable
      #mv Plot-000.pdf ${dir}/${name}.H_${ff}.pdf
	  # skip first two values as they will usually be VERY VERY VERY LARGE
      # (Kcal/mol)??? It rather seems like (KJul/mol)
	  tail -n +4 xx01 | head -n -1 | grep -v Time: \
      | feedgnuplot --domain \
	                --lines \
					--title "Energy/step (kJ/mol)" \
					--hardcopy ${name}.H_${ff}.E.pdf
      rm xx*
	cd ..
  fi
fi | tee -a $dir/${name}.H_${ff}.log

# add a separator to the log file
echo "-----------" >> $dir/${name}.H_${ff}.log

function multijoin1()
{
    # first argument COULD be the tag field (to be removed)
	# second arg COULD be the joining field
	# now $* is a list of files to be joined by the first column
	cut -d ' ' -f1,3 $1  > .o
    chain=${1##*/} ; chain=${chain%.tmp}
	echo -n "#aa ${chain} " > .h
	shift
	while [ $# -gt 0 ] ; do
	    chain=${1##*/} ; chain=${chain%.tmp}
	    echo -n "${chain} ">> .h
	    join --nocheck-order -a1 -a2 -e 0 -o auto .o <(cut -d' ' -f1,3 $1 ) > .tmp
        mv .tmp .o
	    shift
	done
	echo '' >> .h
	cat .h .o 
	rm .o .h
}


if [ $profitrms=='Y' ] ; then
  if [ ! -s $dir/${name}.H_${ff}_aa_rmsd.pdf ] ; then
    # compare 
    echo "Computing RMSD"
    r=$dir/${name}.H.pdb
    m=$dir/${name}.H_${ff}.pdb
    aarmsd=$dir/${name}.H_${ff}_aa.rmsd
	if [ ! -s $aarmsd ] ; then
	~/contrib/bioinf.org.ac.uk/ProFitV3.1/ProFit <<END
      REFERENCE $r
      MOBILE $m
      FIT
      RESIDUE $aarmsd
END
    fi
	echo "Plotting per a.a. RMSD"
    #cat $aarmsd | cut -c1-7,37-42 > aa.rms
    #ctioga2 aa.rms
	#rm aa.rms
    #mv Plot-000.pdf $dir/${name}.H_${ff}.aa.pdf
	# split each chain into a separate file X.tmp
    cat $aarmsd | cut -c1-7,37-42 \
	| sed -e 's/^ \+//g' -e 's/^\([A-Z]\)\([0-9]\+\)/\2 \1/g' \
	| awk '{print>"'$dir/'"$2".tmp"}'
	# vnl format has a commented (#) header which allows us to set a legend
	
	multijoin1 $dir/?.tmp \
	| feedgnuplot --lines \
	              --domain \
				  --title "RMSD/aa (Angstrom)" \
				  --vnl \
				  --autolegend \
				  --hardcopy $dir/${name}.H_${ff}_aa_rmsd.pdf
	rm $dir/?.tmp
  fi
fi | tee -a $dir/${name}.H_${ff}.log
