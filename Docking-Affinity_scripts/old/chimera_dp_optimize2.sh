#!/bin/bash 

pdb=$1

f=`basename $pdb .pdb`

if [ -e chim_${f}_amber/$f_amber.pdb ] ; then echo "$f already done" ; exit ; fi

mkdir -p chim_${f}_amber

# remove hydrogens, conect records and warnings
grep -v ".\{76\} H\b" $pdb | \
grep -v "^CONECT " | \
grep -v "^WARNING" \
    > chim_${f}_amber/$f-H.pdb
pdb=chim_${f}_amber/$f-H.pdb

if [ ! -s chim_${f}_amber/${f}_amber.pdb ] ; then
    #chimera --nogui <<END | tee chim_${f}_amber/${f}_chimera.log
    chimera --nogui >& chim_${f}_amber/${f}_chimera.log <<END
        open $pdb
        # Prepare:
        addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
        #addcharge all chargeModel 12sb method am1
        #addcharge all chargeModel 02pol.r1 method am1
        addcharge all chargeModel 99sb method am1
        #
        # Minimize:
        #   we will use dockprep to prepare the system (prep true)
        #   we can "select" some atoms first and freeze them
        #   or we can "freeze" a specific atomspec directly
        #   default values for nsteps and cgsteps are 100 and 10 respectively
        #	ideally we would like at least 10 times more.
        #   add "interval" 1 to 100 to collect energies after each 1 to 100 steps
        minimize nogui true prep true nsteps 1000 cgsteps 100 freeze none interval 100
        write format mol2 0 chim_${f}_amber/${f}_amber.mol2
        write format pdb 0 chim_${f}_amber/${f}_amber.pdb
END
fi

# save last energy (and gradient) for quick inspection
lastE=`grep "^Potential energy: " chim_${f}_amber/${f}_chimera.log | tail -1` 
echo "$lastE" > "chim_${f}_amber/E="`echo "$lastE" | cut -d' ' -f3 | tr -d ','`

echo "$f done"
