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

# if unset from the external environment, use 'no'
CG=${CG:-no}

#source ~/contrib/gromacs-2020/bin/GMXRC.bash
source ~/contrib/gromacs/bin/GMXRC.bash


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
    if [ ! -e $startconf.gro ] ; then
        echo "ERROR: ( $name ) $startconf.gro does not exist!"
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
        # this is the first time we are run, make a backup copy of the
	# MDP file so we may resort to it if we need to readjust values
        cp $name.mdp $name.mdp.orig 
    fi
        
    # prepare run
    gmx grompp -f $name.mdp \
               -o $name.tpr \
               -c $startconf.gro \
               -r $startconf.gro \
               -p system.top -n index.ndx \
	        -maxwarn 2
    if [ $? == 255 ] ; then 
	echo "ERROR running grompp"
	return
    fi 
    # run MD simulation
    gmx mdrun -v -deffnm $name
    
    # Check if the simulation did end as expected and if not
    # repeat with dt = 1/2 dt
    if [ ! -e $name.gro ] ; then
	echo "WARNING: Simulation $name failed"
        echo "WARNING: retrying again with ½ dt and 2 × nsteps"
        echo ""
	# if the command failed, we'll assume it is because of a
        # calculation error, and re-run it with a smaller step
        # size and same time length (i.e. double nsteps)
        #
        # remove / back up old files
        for i in $name.cpt $name.edr $name.tpr $name.trr $name.log ; do
            # backup_file $i 
	    rm $i 
        done
        rm -f ./\#${name}* ./\#mdout.mdp*
        # reduce step size and increase simulation time
        #    get values of dt and nsteps
	#eval `grep "^dt " $name.mdp | tr -d ' '`
        #eval `grep "^nsteps " $name.mdp | tr -d ' '`
        dt=`grep "^dt " $name.mdp | tr -d ' ' | cut -d= -f2`
        nsteps=`grep "^nsteps " $name.mdp | tr -d ' ' | cut -d= -f2`
        echo "OLD: dt = $dt nsteps = $nsteps"
        #    set aside original file for backup (as a safeguard)
        backup_file $name.mdp 
        # create new configuration
	echo "dt     = " `echo "$dt/2" | bc -l` > $name.mdp.new
	echo "nsteps = " `echo "$nsteps*2" | bc -l` >> $name.mdp.new
        egrep -v "(^dt |^nsteps )" $name.mdp >> $name.mdp.new
        mv $name.mdp.new $name.mdp
	#and try it
        #	Note: we could call ourselves recursively but we would
        #	need a sane way to avoid infinite recursion. USE A LOOP!!!
        gmx grompp -f $name.mdp \
               -o $name.tpr \
               -c $startconf.gro \
               -r $startconf.gro \
               -p system.top -n index.ndx \
	        -maxwarn 2
    	if [ $? == 255 ] ; then 
	    echo "ERROR running grompp"
	    return 255
    	fi 
	# run new MD simulation
        gmx mdrun -v -deffnm $name     
    fi
    # we can check the output log file here to see how it fared
    if grep -q -i error $name.log ; then
        echo "ERROR: ( $name ) SOMETHING WENT TERRIBLY WRONG!"
        return 255
    elif [ ! -s $name.gro ] ; then
        echo "ERROR: ( $name ) SOMETHING WENT TERRIBLY WRONG!"
        return 255
    fi
}



function doNmd() {
    echo "doNmd: $1 $2 $3"
    cnt=1
    cntmax=${1:-10}
    name="$2"
    startconf="$3"

    # we need at least one MDP, for the reference run
    if [ ! -e $name.mdp ] ; then
        echo "ERROR: ( $name ) no MDP file present!"
        return
    fi
    if [ ! -e $startconf.gro ] ; then
        echo "ERROR: ( $name ) $startconf.gro does not exist!"
        return
    fi
    while [ ${cnt} -le ${cntmax} ] ; do
	if [ ! -e ${name}_${cnt}.trr ] ; then
	    # in some cases we get a single MDP file for all steps
	    # while in others we get one for each
            if [ ! -s ${name}_${cnt}.mdp ] ; then
	        cp ${name}.mdp ${name}_${cnt}.mdp
            fi
	    if [ ${cnt} == 1 ] ; then
        	domd ${name}_${cnt} $startconf
            else
        	prev=$((cnt - 1))
        	domd ${name}_${cnt} ${name}_${prev}
            fi
	else
            echo "INFO: ${md}_${cnt}.trr already exists, skipping"
	fi
	cnt=$((cnt + 1))
    done
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

# in CG, the input file is step5_assembly.box.pdb, in plain MD step5_input.gto
if [ -e step5_assembly.box.pdb ] ; then
    ln -s step5_assembly.box.pdb step5_input.gro
fi

# make an index file if none available (CG provides one, plain MD doesn't)
if [ ! -e index.ndx ] ; then 
    echo "q" | gmx make_ndx  -f step5_input.gro -o index.ndx
fi


#---------------------------------------
# disable warnings
export GMX_MAXCONSTRWARN=-1

#---------------------------------------
# Minimization
if [ ! -e step6.0_minimization.trr ] ; then
    # step6.0 - soft-core minimization
    domd step6.0_minimization step5_input
else
    echo 'INFO: "step6.0_minimization.trr" already exists!'
fi

#---------------------------------------
# equilibration
# step6.1
if [ ! -e step6.1_equilibration.trr ] ; then
    domd step6.1_equilibration step6.0_minimization
else
    echo 'INFO: "step6.1_equilibration.trr" already exists!'
fi
unset GMX_MAXCONSTRWARN

# Equilibration (successive steps)
cnt=2
cntmax=6
if [ "no" == "yes" ] ; then
while [ ${cnt} -le ${cntmax} ] ; do
    if [ ! -e step6.${cnt}_equilibration.trr -a \
         ! -e step6.${cnt}_equilibration.xtc ] ; then
        prev=$(( cnt - 1 ))
        domd step6.${cnt}_equilibration step6.${prev}_equilibration
    else
        echo "INFO: \"step6.${cnt}_equilibration.trr\" already exists!"
    fi
    cnt=$(( cnt + 1 ))
done
fi
#---------------------------------------
# Production
if [ "$CG" == "yes" ] ; then
    if [ ! -e step7_production.trr -a
     ! -e step7_production.xtc ] ; then
	domd step7_production step6.6_equilibration
    else
	echo 'INFO: "step7_production.trr" already exists!'
    fi
else
    cnt=1
    cntmax=10

    while [ ${cnt} -le ${cntmax} ] ; do
	if [ ! -e step7_${cnt}.trr ] ; then
	    # in some cases we get a single MDP file for all steps
	    # while in others we get one for each
            if [ ! -s step7_${cnt}.mdp ] ; then
	        cp step7_production.mdp step7_${cnt}.mdp
            fi
	    if [ ${cnt} == 1 ] ; then
        	domd step7_${cnt} step6.6_equilibration
            else
        	prev=$((cnt - 1))
        	domd step7_${cnt} step7_${prev}
            fi
	else
            echo "INFO: step7.${cnt}.trr already exists, skipping"
	fi
	cnt=$((cnt + 1))
    done
    
fi

#---------------------------------------
# Additional extended production runs
#
if [ "$HUGE" == "TRUE" ] ; then LONG=TRUE ; fi
if [ ! -e step8_10x.trr -a "$LONG" == "TRUE" ] ; then
   # multiply by 10 the number of steps and output saving intervals
    cat step7_production.mdp \
        | sed -e '/^nsteps / s/$/0/g' \
        > step8_10x.mdp
# if you add this it will divide output frames by 10
#              -e '/^nst.*out/ s/$/0/g'\
# it is better not to and, if required, change the stride on loading the
# trajectory.
	
    if [ "$CG" == 'yes' ] ; then
        domd step8_10x step7_production
    else
        domd step8_10x step7_10
    fi
    if [ -e step8_10x.gro ] ; then
    	# if there is a gro file then the MD run finished OK
        # create XTC file without PBC
	echo System  | gmx trjconv -f step8_10x.trr \
             -s step8_10x.tpr -o step8_10x_noPBC.xtc \
             -pbc mol -conect

	lastt=`gmx check -f step8_10x.xtc |& grep "Last frame" | sed -e 's/.* time//g'`
	echo System  | gmx trjconv -f step8_10x.trr \
             -s step8_10x.tpr -o step8_10x-last-conect.pdb \
             -pbc mol -conect -dump $lastt
    fi
else
    echo "INFO: step8_10x.trr already exists. Skipping"
fi


if [ ! -e step9_100x.trr -a "$HUGE" == "TRUE" ] ; then
   # multiply by 100 the number of steps and output saving intervals
    cat step7_production.mdp \
        | sed -e '/^nsteps / s/$/00/g' \
        > step9_100x.mdp
    domd step9_100x step8_10x
# if you add this it will divide output frames by 10
#        | sed -e '/^nst.*out/ s/$/0/g' \
# if you add this it will divide output frames by 100
#        | sed -e '/^nst.*out/ s/$/00/g' \
# it is better not to and, if required, change the stride on loading the
# trajectory.

    if [ -e step9_100x.gro ] ; then
    	# if there is a gro file then the MD finished OK
	echo System  | gmx trjconv -f step9_100x.trr \
             -s step9_100x.tpr -o step9_100x_noPBC.xtc \
             -pbc mol -conect

	lastt=`gmx check -f step9_100x.xtc |& grep "Last frame" | sed -e 's/.* time//g'`
	echo System  | gmx trjconv -f step9_100x.trr \
             -s step9_100x.tpr -o step9_100x-last-conect.pdb \
             -pbc mol -conect -dump $lastt
    fi
else
    echo "INFO: step9_100x.trr already exists. Skipping"
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

exit
