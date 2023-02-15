#!/bin/bash 
#
# NOTE: Amber optimization is losing the info on chains, that is a no-no
# for it will damage all subsequent computations! CHECK THIS
#
pdb=$1
f=`basename $pdb .pdb`

BASE=`dirname "$(readlink -f "$0")"`
AMBERMD_HOME=~/work/bin

if [ -e amber_${f}-H_310K/${f}_amber.pdb ] ; then echo "$f already done" ; exit ; fi

# remove hydrogens, conect records and warnings
grep -v ".\{76\} H\b" $pdb | \
grep -v "^CONECT " | \
grep -v "^WARNING" \
    > ${f}-H.pdb
pdb_noH=${f}-H.pdb
# and let amberMD add the H with GROMACS   

# now do the amber minimization in vacuo
${AMBERMD_HOME}/amberMD.bash -i $pdb_noH -O

# clean
if [ -d amber_${f}-H_310K ] ; then
    mv ${f}-*.* amber_${f}-H_310K
    # this includes $f-H.pdb $f-H.mol2 $f-H.pdb $f-dockprep.log $f-chimera.log
else
    mkdir amber_${f}-H_310K.KO
    mv ${f}-*.* amber_${f}-H_310K.KO
    echo "ERROR: Minimization of $f in vacuo FAILED!" >&2
fi
if [ -s amber_${f}-H_310K/em.pdb ] ; then
    cp amber_${f}-H_310K/em.pdb amber_${f}-H_310K/${f}_amber.pdb
    what=0 # System
    what=1 # Protein only
    echo $what \
    | gmx trjconv -f amber_${f}-H_310K/em.gro \
                  -s amber_${f}-H_310K/em.tpr \
                  -o amber_${f}-H_310K/${f}_amber_nosol.pdb
else
    echo "No em.pdb file found."
    echo "Something went wrong with minimization in vacuo of $f.pdb"
fi

# save last energy (and gradient) for quick inspection
lastE=`grep "^Potential Energy " amber_${f}-H_310K/em.log | tail -1` 
echo "$lastE" > "amber_${f}-H_310K/E="`echo "$lastE" | cut -d'=' -f2 | tr -d ' '`

echo "$f done"
