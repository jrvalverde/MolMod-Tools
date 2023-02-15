#!/bin/bash 
#5.x version of gromacs#
#based on gromacs lysozyme tutorial 2018#
#search .end files in your MD folder to check the ended steps#

#Previous steps
# first of all copy the needed files and put them into the work file#
# It's important to this script that 
# you copy the protein file and rename it like Protein.pdb #


# number of simultaneous jobs to run
# BE CAREFUL WITH THIS NUMBER because the calc time could be too slow
# NOTE prouve different numbers 
# 150 for a peptide between xxxx amino acids
# a higher number if the molecule is bigger

job=150




# prepare the config files


# clean up
rm *.log *.out *.err *.gro *.top *.end *.edr ./\#*

#echo 15 | stdbuf -o 0 gmx pdb2gmx -f Protein.pdb -o Protein_processed.gro -water spce | tee pdb2gmx.log 
#stdbuf -o 0 and | ... extra#

# convert to gromacs
echo 15 | gmx pdb2gmx \
          -ignh -f Protein.pdb \
          -o Protein_processed.gro -water spce

# create PBC box
gmx editconf -f Protein_processed.gro -o Protein_newbox.gro  \
	     -c -d 1.0 -bt cubic

# add water
# use gromacs 4. NOTE: check how is it done now
# note: we should use gmx solvate and gmx insert-molecules
#	so, we need to re-read the manual
genbox -cp Protein_newbox.gro  -cs spc216.gro -o Protein_solv.gro \
       -p topol.top


# prepare to add ions
gmx grompp -f ions.mdp -c Protein_solv.gro -p topol.top -o ions.tpr

# add ions
gmx genion -s ions.tpr -o Protein_solv_ions.gro -p topol.top -pname NA -nname CL -nn 6 <<END
13
END

# prepare minimzation
gmx grompp -f minim.mdp -c Protein_solv_ions.gro -p topol.top -o em.tpr

# do minimization
gmx mdrun -nt $job -v -deffnm em

#Energy minimization not slow#


# analyze progress of minimization using potential energy
gmx energy -f em.edr -o potential.xvg <<END
10

END

echo "Energy minimization done" | tee em.end

# prepare for equilibration in NVT
gmx grompp -f nvt.mdp -c em.gro -p topol.top -o nvt.tpr

# do equilibration in NVT
gmx mdrun -nt $job -deffnm nvt

# analyze progres of equilibration in NVT using energy
gmx energy -f nvt.edr <<END
15


END

echo "NVT done" | tee nvt.end

# prepare for equilibration in NPT
gmx grompp -f npt.mdp -c nvt.gro -t nvt.cpt -p topol.top -o npt.tpr

# do equilibration in NPT
gmx mdrun -nt $job -deffnm npt |& tee npt.out



# ==> to send different data generated by the program to two separated files:
#	> file	send standard output to the following 'file'
#	2> file	send standard error to the following 'file'
#	2>&1	send standard error to the same place as standard output
# ANOTHER OPTION
# stdout > filename.txt
# stderr 2> filename.txt

# analyze progress of NPT equilibration using the energy
gmx energy -f npt.edr -o pressure.xvg <<END
16

END

# analyze progress of NPT equilibration using the density of the system
gmx energy -f npt.edr -o density.xvg <<END
22

END

#equilibration done#

echo "NPT done" | tee npt.end


# prepare production Molecular Dynamics using PBC
gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0-10ns.tpr

# do MD
gmx mdrun -nt $job -deffnm md_0-10ns

# gmx mdrun -deffnm md_0-10ns -nb gpu use this command to run it in a GPU#

#molecular dynamics done#

echo "Molecular dynamics done" | tee md.end


# Remove potential distorsions due to PBC and geneate
#	an equivalent trajectory with the whole system
gmx trjconv -s md_0-10ns.tpr -f md_0-10ns.xtc -o md_0-10ns_noPBC.xtc \
            -pbc mol -ur compact <<END
0

0

END
#system

#	a trajectory with only the protein
gmx trjconv -s md_0-10ns.tpr -f md_0-10ns.xtc -o md_0-10ns_noPBC_prot.xtc \
            -pbc mol -ur compact <<END
1

1

END
#protein

#	a trajectory with the backbone
gmx trjconv -s md_0-10ns.tpr -f md_0-10ns.xtc -o md_0-10ns_noPBC_bb.xtc \
            -pbc mol -ur compact <<END
4

4

END

# Compute RMSD
#	of the backbone w.r.t. the initial configuration
gmx rms -s md_0-10ns.tpr -f md_0-10ns_noPBC.xtc -o rmsd.xvg -tu ns <<END
4

4

END
#backbone

#	of the whole system w.r.t. the minimized system
gmx rms -s em.tpr -f md_0-10ns_noPBC.xtc -o rmsd_xtal.xvg -tu ns <<END
0

0

END
#System

#	of the protein w.r.t. the minimized system
gmx rms -s em.tpr -f md_0-10ns_noPBC.xtc -o rmsd_xtal.xvg -tu ns <<END
1

1

END
#protein

# Calculate radius of gyration
#	of the whole system w.r.t. the initial conformation
gmx gyrate -s md_0-10ns.tpr -f md_0-10ns_noPBC.xtc -o gyrate.xvg <<END
0

0

END
#system

#	of the protein w.r.t. the initial conformation
gmx gyrate -s md_0-10ns.tpr -f md_0-10ns_noPBC.xtc -o gyrate.xvg <<END
1

1

END
#protein

#	of the backbone w.r.t. the initial conformation
gmx gyrate -s md_0-10ns.tpr -f md_0-10ns_noPBC.xtc -o gyrate.xvg <<END
4

4

END

#analysis#


echo "Simple analysis done" | tee simple_analysis.end

echo "Process finished"

# LAST MODIFICATION: March 6th 2018 #