#!/bin/bash
#
#	We don't take any arguments and do work on the current directory
#
# Based on the file generated by CHARMM-GUI (http://www.charmm-gui.org)
#
# 	Always use latest Gromacs to run these simulations (and at least >= 5.1)
#
# Reminder
#	dt	picoseconds
# equilibration (step6 * 6)
#	nstep	125000 ( * 0.001 = 125 ps )
#	nstep	250000 ( * 0.002 = 500 ps )
#	total: (3 * 125) + (3 * 500) = 1875 ps = 1.875 ns 
# production (step 7 * 10)
#	nstep	250000 ( * 0.004 = 1000 ps = 1 ns )
#	total	10 ns
# long production (step 8)
#	nstep	2500000 ( * 0.004 = 10000 ps = 10 ns )
# huge production (step 9)
#	nstep	25000000 ( * 0.004 = 100000 ps = 100 ns )
#
# NOTEs:
# There are differences between CHARMM-GUI generated scripts depending
# on the tool used. This script currently works for CG and membrane
# models. The main spotted differences are:
#	In CG the topology is 'system.top', in membrane MD 'topol.top'
#	In CG there is an index.ndx file, in membrane MD not
#	in CG the initial file is step5_assembly.box.pdb , in membrane
#   MD, it is step5_input.pdb
#	in CG there is only one production step, in membrane MD the
#   production step is continued 10 times, hence for membraneMD, the 
#   LONG=TRUE environment variable must be set.
#	MAYBE WE SHOULD ITERATE 10 TIMES INSTEAD AND USE A DECISOR VARIABLE?
#
# (c) José R. Valverde, CNB-CSIC
#     2016-2020
#
# Licensed under EU-GPL or GNU-GPL
#
#set -x

COARSE_GRAIN=TRUE

source ~/contrib/gromacs-2020/bin/GMXRC.bash


function backup_file {
    local f=$1
    i=0
    if [ ! -d bck ] ; then mkdir -p bck ; fi
    while [ -e bck/$f.`printf %03d $i` ] ; do
        i=$((i + 1))
    done
    echo saving $f as bck/$f.`printf %03d $i`
    cp $f bck/$f.`printf %03d $i`
}

function domd() {
    echo "domd: $1 $2"
    name="$1"
    startconf="$2"
    if [ ! -e $name.mdp ] ; then
        echo "ERROR: ( $name ) no MDP file present!"
        return
    fi
    if [ ! -e $startconf ] ; then
        echo "ERROR: ( $name ) $startconf does not exist!"
        return
    fi
    # clean up any previous (assumed bad) files
    #	they should be bad if the previous run did not succeed
    rm -f $name.cpt $name.edr $name.tpr $name.trr $name.log
    rm -f ./\#${name}* ./\#mdout.mdp*
    # start afresh
    if [ -e $name.mdp.orig ] ; then 
        mv $name.mdp.orig $name.mdp
    else
        cp $name.mdp $name.mdp.orig
    fi
    
    gmx grompp -f $name.mdp \
               -o $name.tpr \
               -c $startconf \
               -r $startconf \
               -p system.top -n index.ndx
    if [ $? == 255 ] ; then 
	echo "ERROR running grompp"
	return
    fi 
    gmx mdrun -deffnm $name
    if [ ! -e $name.gro ] ; then
	echo "WARNING: Simulation $name failed"
        echo "WARNING: retrying again with ½ dt and 2 × nsteps"
        echo ""
	# if the command failed, we'll assume it is because of a
        # calculation error, and re-run it with a smaller step
        # size and same time length (i.e. double nsteps)
        #
        # remove # back up old files
        for i in $name.cpt $name.edr $name.tpr $name.trr $name.log ; do
            rm $i # backup_file $i 
        done
        rm -f ./\#${name}* ./\#mdout.mdp*
        # reduce step size and increase simulation time
        #    get values of dt and nsteps
	#eval `grep "^dt " $name.mdp | tr -d ' '`
        #eval `grep "^nsteps " $name.mdp | tr -d ' '`
        dt=`grep "^dt " $name.mdp | tr -d ' ' | cut -d= -f2`
        nsteps=`grep "^nsteps " $name.mdp | tr -d ' ' | cut -d= -f2`
        echo "dt = $dt nsteps = $nsteps"
        #    set aside original file for backup (as a safeguard)
        backup_file $name.mdp 
        # create new configuration
	echo "dt     = " `echo "$dt/2" | bc -l` > $name.mdp.new
	echo "nsteps = " `echo "$nsteps*2" | bc -l` >> $name.mdp.new
        egrep -v "(^dt |^nsteps )" $name.mdp >> $name.mdp.new
        mv $name.mdp.new $name.mdp
	#and try it
        #	Note: we could call ourselves recursively but we would
        #	need a sane way to avoid infinite recursion
        gmx grompp -f $name.mdp \
               -o $name.tpr \
               -c $startconf \
               -r $startconf \
               -p system.top -n index.ndx
    	if [ $? == 255 ] ; then 
	    echo "ERROR running grompp"
	    return
    	fi 
        gmx mdrun -deffnm $name     
    fi
    # we can check the output log file here to wee how it fared
    if grep -q -i error $name.log ; then
        echo "ERROR: ( $name ) SOMETHING WENT TERRIBLY WRONG!"
        return
    fi
}

#---------------------------------------
# Prepare output log file
log=zyglog.outerr
if [ -e $log ] ; then
    backup_file $log
fi
# Tee output and error to a log file
#appendlog='-a'
appendlog=''
exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")
# ... or to two separate files
#stdout=./$name/log.$myname.out
#stderr=./$name/log.$myname.err
#exec > $stdout 2> $stderr


#---------------------------------------
# Ensure that all environments are alike
# in CG MD the topology is called system.top, in plain MD topol.top
if [ ! -e system.top -a -e topol.top ] ; then 
    ln -s topol.top system.top 
fi

# make an index file if none available (CG provides one, plain MD doesn't)
if [ ! -e index.ndx ] ; then 
    echo "q" | gmx make_ndx  -f $name.tpr -o index.ndx
fi

# in CG, the input file is step5_assembly.box.pdb, in plain MD step5_input.gto
if [ -e step5_assembly.box.pdb ] ; then
    ln -s step5_assembly.box.pdb step5_input.gro
fi

#---------------------------------------
# disable warnings
export GMX_MAXCONSTRWARN=-1

#---------------------------------------
# Minimization
if [ ! -e step6.0_minimization.gro ] ; then
    # step6.0 - soft-core minimization
    domd step6.0_minimization step5_input.gro
else
    echo 'INFO: "step6.0_minimization.gro" already exists!'
fi

#---------------------------------------
# equilibration
# step6.1
if [ ! -e step6.1_equilibration.gro ] ; then
    if [ ! -e step6.0_equilibration.gro -a -e step6.0_minimization.gro ] ; then
        cp step6.0_minimization.gro step6.0_equilibration.gro
    fi
    domd step6.1_equilibration step6.0_equilibration.gro
else
    echo 'INFO: "step6.1_equilibration.gro" already exists!'
fi
unset GMX_MAXCONSTRWARN

# Equilibration (successive steps)
cnt=2
cntmax=10

while [ ${cnt} -le ${cntmax} ] ; do
    if [ ! -e step6.${cnt}_equilibration.gro ] ; then
        prev=$(( cnt - 1 ))
        domd step6.${cnt}_equilibration step6.${prev}_equilibration.gro
    else
        echo "INFO: \"step6.${cnt}_equilibration.gro\" already exists!"
    fi
    cnt=$(( cnt + 1 ))
done

#---------------------------------------
# Production
if [ ! -e step7_production.gro ] ; then
    domd step7_production step6.6_equilibration.gro
else
    echo 'INFO: "step7_production.gro" already exists!'
fi

if [ "$CG" == "no" ] ; then
cnt=1
cntmax=10

while [ ${cnt} -le ${cntmax} ] ; do
    if [ ! -e step7.${cnt}_production.gro ] ; then
        if [ ${cnt} == 1 ] ; then
            cp step7_production.mdp step7.${cnt}_production.mdp
            domd step7.${cnt}_production step6.6_equilibration.gro
        else
            prev = $((cnt - 1))
            domd step7.${cnt}_production step7.${prev}_production.gro 
        fi
    else
        echo "INFO: step7.${cnt}_production.gro already exists, skipping"
    fi
    cnt=$((cnt + 1))
done
fi

#---------------------------------------
# Additional extended production runs
#
if [ "$HUMONGOUS" == "TRUE" ] ; then HUGE=TRUE ; fi
if [ "$HUGE" == "TRUE" ] ; then LONG=TRUE ; fi

if [ ! -e step8_10x.gro -a "$LONG" == "TRUE" ] ; then
   # multiply by 10 the number of steps and output saving intervals
    cat step7_production.mdp \
        | sed -e '/^nsteps / s/$/0/g' \
              -e '/^nst.*out/ s/$/0/g'\
        > step8_10x.mdp
    domd step8_10x step7_production.gro

    if [ -e step8_10x.gro ] ; then
	echo System  | gmx trjconv -f step8_10x.trr \
             -s step8_10x.tpr -o step8_10x_noPBC.xtc \
             -pbc mol -conect

	lastt=`gmx check -f step8_10x.xtc |& grep "Last frame" | sed -e 's/.* time//g'`
	echo System  | gmx trjconv -f step8_10x.trr \
             -s step8_10x.tpr -o step8_10x-last-conect.pdb \
             -pbc mol -conect -dump $lastt
    fi
fi

if [ ! -e step9_100x.gro -a "$HUGE" == "TRUE" ] ; then
   # multiply by 100 the number of steps and output saving intervals
    cat step7_production.mdp \
        | sed -e '/^nsteps / s/$/00/g' \
        | sed -e '/^nst.*out/ s/$/00/g' \
        > step9_100x.mdp
    domd step9_100x step8_10x.gro

    if [ -e step9_100x.gro ] ; then
	echo System  | gmx trjconv -f step9_100x.trr \
             -s step9_100x.tpr -o step9_100x_noPBC.xtc \
             -pbc mol -conect

	lastt=`gmx check -f step9_100x.xtc |& grep "Last frame" | sed -e 's/.* time//g'`
	echo System  | gmx trjconv -f step9_100x.trr \
             -s step9_100x.tpr -o step9_100x-last-conect.pdb \
             -pbc mol -conect -dump $lastt
    fi
fi

if [ ! -e step10_1000x.gro -a "$HUMONGOUS" == "TRUE" ] ; then
   # multiply by 100 the number of steps and output saving intervals
    cat step7_production.mdp \
        | sed -e '/^nsteps / s/$/000/g' \
        > step10_1000x.mdp
#        | sed -e '/^nst.*out/ s/$/00/g' \
    domd step10_1000x step8_10x.gro

    if [ -e step10_1000x.gro ] ; then
	echo System  | gmx trjconv -f step10_1000x.trr \
             -s step10_1000x.tpr -o step10_1000x_noPBC.xtc \
             -pbc mol -conect

	lastt=`gmx check -f step10_1000x.xtc |& grep "Last frame" | sed -e 's/.* time//g'`
	echo System  | gmx trjconv -f step10_1000x.trr \
             -s step10_1000x.tpr -o step10_1000x-last-conect.pdb \
             -pbc mol -conect -dump $lastt
    fi
fi



for i in *.gro ; do
    if [ ! -e `basename $i gro`pdb ] ; then
        # ideally we would like to add -conect as well
        #gmx editconf -f $i -o `basename $i gro`pdb -pbc yes
        echo "System" | gmx trjconv -f $i \
        	-s `basename $i gro`tpr \
                -o `basename $i gro`pdb \
                -pbc mol -conect
    fi
done
