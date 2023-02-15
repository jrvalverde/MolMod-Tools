#!/bin/bash
#   Rescore using DSX
#et -x

function backup_file {
    local f=$1
    i=0
    while [ -e $f.`printf %03d $i` ] ; do
        i=$((i + 1))
    done
    echo saving $f as $f.`printf %03d $i`
    cp $f $f.`printf %03d $i`
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

function check_file_ext() {
    file=$1
    ext=$2

    if [ ! -s "$file" ] ; then
        echo "ERROR: no '$file' file found"
        return 1
    fi
    # ${string##substring} 
    # Deletes longest match of $substring from front of $string.
    local fext="${file##*.}"
    #${string%substring}
    # Deletes shortest match of $substring from back of $string.
    local fnam="${file%.*}"		# remove extension
    fnam=${fnam##*/}			# remove leading dir path
    local fok=`realfile $file`
    if [ "$fext" "$ext" ] ; then
    	echo "ERROR: Receptor '${file}' must be a '.${ext}' file"
        return 1
    fi
    return 0
}

function add_dsx_score {
    if [ $# -lt 2 ] ; then echo "ERROR:${FUNCNAME[0]}  ligands scores" 
    else echo ">>> ${FUNCNAME[0]} $*" ; fi

    local mol2=$1
    local scores=$2
    
    local i=0
    cat $mol2 |\
    while read line ; do
        if [[ $line =~ \@\<TRIPOS\>MOLECULE.* ]] ; then
            # DSX uses zero offset
            dsxline=`grep "^ ${i} " $scores`
            dsxrmsd=`echo "$dsxline" | cut -d'|' -f3`
            dsxscore=`echo "$dsxline" | cut -d'|' -f4`
            dsxpcs=`echo "$dsxline" | cut -d'|' -f6`
            if [ "$dsxscore" = "" ] ; then
            	echo "########## ERROR: cannot assign dsxscore for ligand #$i"
            else
                echo "########## DSX score: $dsxscore"
                echo "########## DSX RMSD:  $dsxrmsd"
                echo "########## DSX PCS: $dsxpcs"
                echo ""
            fi
            i=$((i + 1))
        fi
	echo "$line" 
    done
}


function score_dsx {
    if [ $# -lt 2 ] ; then echo "ERROR:${FUNCNAME[0]}  receptor ligand [known]" 
    else echo ">>> ${FUNCNAME[0]} $*" ; fi
    
    local receptor=$1
    local ligands=$2
    local known=$3
    
    # use these on 64 bit Linux (set paths appropriately)
    export ARCH=linux64
    export EXE_ARCH=linux_64

    # use these on 32 bit Linux (set paths as needed)
    #export ARCH=RHEL_linux32
    #export EXE_ARCH=rhel_linux_32


    export PATH=$HOME/contrib/dsx/$ARCH:$PATH
    #export LD_LIBRARY_PATH=$HOME/contrib/dsx/$ARCH:$LD_LIBRARY_PATH
    local DSX=$HOME/contrib/dsx/$ARCH/dsx_$EXE_ARCH.lnx
    local DSX_POT=$HOME/contrib/dsx/pdb_pot_0511/

    # Process arguments

    if [ ! -s "$receptor" ] ; then
        echo "ERROR: no '$receptor' file found"
        return 1
    fi
    # ${string##substring} 
    # Deletes longest match of $substring from front of $string.
    local rext="${receptor##*.}"
    #${string%substring}
    # Deletes shortest match of $substring from back of $string.
    local rnam="${receptor%.*}"		# remove extension
    rnam=${rnam##*/}			# remove leading dir path
    local rok=`realfile $receptor`
    if [ "$rext" != "pdb" -a "$rext" != "mol2" ] ; then
    	echo "ERROR: Receptor $receptor must be a PDB or a MOL2 file"
        return 1
    fi
    
    if [ ! -s "$ligands" ] ; then
        echo "ERROR: no '$ligands' file found"
        return 1
    fi
    local lext="${ligands##*.}"
    local lnam="${ligands%.*}"
    lnam=${lnam##*/}			# remove leading dir path
    local lok=`realfile $ligands`
    if [ "$lext" != "mol2" ] ; then
    	echo "ERROR: Ligands $ligands must be in a MOL2 file"
        return 1
    fi

    # Check if a reference was provided and reflect it in the
    # output subdirectory name
    if [ -z "$known" ] ; then 
        known=$ligands 
        # save results in sudirectory "dsx"
        dir="dsx"
    else
        # use $known as reference
        # save results in subdirectory "dsxR"
        dir="dsxR"
    fi
    local kext="${known##*.}"
    local knam="${known%.*}"
    knam=${knam##*/}			# remove leading dir path
    local kok=`realfile $known`
    if [ "$kext" != "mol2" ] ; then
    	echo "ERROR: Reference $known must be in a MOL2 file"
        return 1
    fi

    # Make output directory
    if [ ! -d $dir ] ; then mkdir -p $dir ; fi
    # Move inside output directory
    # (we must because we cannot specify where output goes)
    cd $dir
    
 
    # make .mol2 file from .pdb if needed
    if [ ! -e $rnam.mol2 ] ; then 
        if [ "$rext" = "pdb" ] ; then
            #echo "DSX scoring: making mol2 from pdb"
	    babel -ipdb $rok -omol2 $rnam.mol2
        else
            ln -s $rok $rnam.mol2
        fi
    fi

    if [ ! -s $lnam.mol2 ] ; then 
	ln -s $lok $lnam.mol2
    fi

    if [ ! -s $knam.mol2 ] ; then 
	ln -s $kok $knam.mol2
    fi

    #
    # set a timeout of 5' (300") on each DSX calculation
    #	$! expands to the PID of the most recently executed background command:
    #	( some-large-command ) & sleep 300 ; kill $!
    # the above has a problem in that if the command ends earlier we still wait
    # the specified timeout.
    #
    # The solution by J. R. Valverde in EMBnet.news is better, but we may also
    # use now the 'timeout' command from coreutils, which returns 124 if the
    # command was terminated by a timeout
    #
    #	Note: for the EMBnet.News solution try the following
    #
    # (submitter=$$ ; (sleep $tmo ; pkill -P $submitter)& large-command)& wait $!
    # or 
    # (submitter=$! ; (sleep $tmo ; kill $submitter)& large-command)& wait $!
    #
    # maximum running time for DSX (m = min., s = sec.)
    local tmo=5m 
    # grace timeout (15 sec.)
    local gto=15s
    #
    # this is to deal with inconsistencies in the timeout command
    # across different versions of Ubuntu
    #
    #	This works in Ubuntu 11.10 (e.g. xistral)
    #
    toopt="-k $gto $tmo "
    #
    #	This works in Ubuntu 10.04.2 [seconds] (e. g. ngs)
    #
    #local toopt="300"


    echo "Scoring ligand poses ${lnam} with DSX .."

    # TOT
    if [ ! -e DSX_${rnam}_${lnam}.tot.txt ] ; then
        timeout $toopt $DSX \
	    -P $rnam.mol2 -L $lnam.mol2 -R $knam.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 1 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
        if [ $? -ne 124 ] ; then
            mv DSX_${rnam}_${lnam}.txt DSX_${rnam}_${lnam}.tot.txt
        else
            echo "ERROR: TOT DSX $rnam $lnam failed"
        fi
    fi

    # RMSD
    if [ ! -e DSX_${rnam}_${lnam}.rmsd.txt ] ; then
        timeout $toopt $DSX \
	    -P ${rnam}.mol2 -L ${lnam}.mol2 -R ${knam}.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 4 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
        if [ $? -ne 124 ] ; then
    	    mv DSX_${rnam}_${lnam}.txt DSX_${rnam}_${lnam}.rmsd.txt
        else
            echo "ERROR: RMSD DSX $rnam $lnam failed"
        fi
    fi

    # plain
    if [ ! -e DSX_${rnam}_${lnam}.txt ] ; then
        timeout $toopt $DSX \
	    -P ${rnam}.mol2 -L ${lnam}.mol2 -R ${knam}.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 0 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
        if [ $? -eq 124 ] ; then
            echo "ERROR: plain DSX $rnam $lnam failed"
        fi
    fi

    # Add scores to ligands MOL2 file for UCSF Chimera ViewDock
    add_dsx_score $lnam.mol2  DSX_${rnam}_${lnam}.txt > ${rnam}_${lnam}.d.mol2

    echo "Done ${rnam} x ${lnam}"
    echo ""
    
    ####
    # Repeat for receptor + known
    ####
    if [ "$knam" = "$lnam" ] ; then
        cd -
        return
    fi

    echo -n "Scoring reference ${knam} with DSX .."

    # TOT
    if [ ! -e DSX_${rnam}_${knam}.tot.txt ] ; then
        timeout $toopt $DSX \
	    -P ${rnam}.mol2 -L ${knam}.mol2 -R ${knam}.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 1 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
        if [ $? -ne 124 ] ; then
            mv DSX_${rnam}_${knam}.txt DSX_${rnam}_${knam}.tot.txt
        fi
    fi

    # RMSD
    if [ ! -e DSX_${rnam}_${knam}.rmsd.txt ] ; then
        timeout $toopt $DSX \
	    -P ${rnam}.mol2 -L ${knam}.mol2 -R ${knam}.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 4 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
        if [ $? -ne 124 ] ; then
    	    mv DSX_${rnam}_${knam}.txt DSX_${rnam}_${knam}.rmsd.txt
        fi
    fi

    # plain
    if [ ! -e DSX_${rnam}_${knam}.txt ] ; then
        timeout $toopt $DSX \
	    -P ${rnam}.mol2 -L ${knam}.mol2 -R ${knam}.mol2 \
	    -I 0 -D $DSX_POT -o -v -S 0 \
	    -T0 1.0 -T1 1.0 -T2 0.0 -T3 1.0 -c
    fi

    # Add scores to reference MOL2 file for UCSF Chimera ViewDock
    add_dsx_score $knam.mol2  DSX_${rnam}_${knam}.txt > ${rnam}_${knam}.d.mol2

    echo "Done ${rnam} x ${knam}"

    cd ..	# exit from ./dsx
}

score_dsx $*
