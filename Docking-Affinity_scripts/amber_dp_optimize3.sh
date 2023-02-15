#!/bin/bash 
#
# NOTE: Amber optimization is losing the info on chains, that is a no-no
# for it will damage all subsequent computations! CHECK THIS
#
pdb=$1
R=$2
L=$3

f=`basename $pdb .pdb`
name=$f

BASE=`dirname "$(readlink -f "$0")"`
AMBERMD_HOME=~/work/bin

# we run in aff/vacmin
# topologies are in $topo
topo=../../topo

# avoid repeating an already done minimization
target=amber_${f}_310K/${f}_vacuo.pdb
if [ -e $target ] ; then echo "$f already done" ; exit ; fi

        	
$BASE/fix_one_ligand_pdb3.sh $pdb $R $L

# and let amberMD add the H itself   

# we need to check if the pdb file contains any HETATM ligand
if grep -q "^HETATM" $pdb ; then
    # the PDB contains heteroatoms
    # we need to specify a topology for them
    # we identify the HET residue name from the PDB file name
    LIG=`echo $pdb | sed -e 's/.*_//g' -e 's/\.pdb$//g'`
    # retrieve topology files for $LIG
    # besides the ones that may be generated, we'll probe for
    # LigParGen, STaGE or other topologies
    # to keep everything in place and be able to work in parallel
    # we'll work in a subdirectory
    mkdir $f
    cp $pdb $f
    echo "$LIG	0" > LIGANDS
    mv LIGANDS $f
    if [ -e $topo/ligpargen/$LIG ] ; then
        cp -RuvL $topo/ligpargen/$LIG/*.gro $f/$LIG.gro
        cp -RuvL $topo/ligpargen/$LIG/*.itp $f/$LIG.itp
    elif [ -e $topo/stage/${LIG}_gaff ] ; then
        cp -RuvL $topo/stage/posre_$LIG.itp $f/
        cp -RuvL $topo/stage/${LIG}_gaff/$LIG/$LIG.itp
    fi
    # for now we only deal with zero-charge ligands
    # later on we will also consider charge (once we decide a 
    # convention).
    cd $f
      ${AMBERMD_HOME}/amberMD.bash -i $pdb -O -l LIGANDS -t $LIG.itp
      mv amber_${f}_310K ..
    cd ..
else
    # the model contains only valid residues, 
    # do the amber minimization in vacuo
    ${AMBERMD_HOME}/amberMD.bash -i $pdb -O
fi

# clean
if [ -d amber_${f}_310K ] ; then
    mv ${f}.* amber_${f}_310K
    # this includes $f-H.pdb and possibly $f-H.mol2 
else
    mkdir amber_${f}_310K.KO
    mv ${f}.* amber_${f}_310K.KO
    echo "ERROR: Minimization of $f in vacuo FAILED!" >&2
fi

# create properly named output files
if [ -s amber_${f}-H_310K/em.gro ] ; then
    #cp amber_${f}-H_310K/em.pdb amber_${f}_310K/${f}_vacuo.pdb
    what=System
    #what=Protein
    #what=non-Water
    echo $what \
    | gmx trjconv -f amber_${f}_310K/em.gro \
                  -s amber_${f}_310K/em.tpr \
                  -o amber_${f}_310K/${f}_vacuo.pdb \
		  -pbc nojump
else
    echo "No em.pdb file found."
    echo "Something went wrong with minimization in vacuo of $f.pdb"
fi

# save last energy (and gradient) for quick inspection
lastE=`grep "^Potential Energy " amber_${f}-H_310K/em.log | tail -1` 
echo "$lastE" > "amber_${f}_310K/E="`echo "$lastE" | cut -d'=' -f2 | tr -d ' '`

echo "$f done"
