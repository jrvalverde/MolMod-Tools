#!/bin/bash

function martini(){
   
   local aux=~/work/amelones/martini    # this is where the files needed to run the simulation are stored
   local dssp=~/bin/dssp
   local pulchra=~/contrib/UniCon3D/pulchra_306/pulchra
   local workdir=martini
   local nt=1
   local SOLVATE="NO"  # change to "YES" if you want a minimization in solution

   # make work directory
   mkdir -p $workdir
   cd $workdir
   
   for i in *.pdb; do
       # create a directory with the name of the pdb structure
       local pdbf="$i"
       local nam=`basename $pdbf .pdb`
       local dir=${nam}-water
       mkdir -p $dir
       # copy the pdb structure to the directory
       cp $pdbf $dir/protein.pdb
       cd $dir

       # Prepare needed MARTINI files
       if [ ! -e martinize.py ] ; then cp $aux/martinize.py . ; fi
       if [ ! -e martini.itp ] ; then cp $aux/martini.itp . ; fi



       # Prepare simulation control files
       if [ ! -e minimization-vacuum.mdp ] ; then 
           cp $aux/minimization-vacuum.mdp . 
       fi
       if [ ! -e minimization.mdp ] ; then cp $aux/minimization.mdp . ; fi
       if [ ! -e equilibration.mdp ] ; then cp $aux/equilibration.mdp . ; fi
       if [ ! -e dynamic.mdp ] ; then cp $aux/dynamic.mdp . ; fi

       # prepare system

       # The pdb-structure can be used directly as input for the martinize.py script, 
       # to generate both a structure and a topology file. Have a look at the help 
       # function (i.e. run martinize.py -h) for the available options. Hint, valid for
       # any system simulated with Martini: during equilibration it might be useful to
       # have (backbone) position restraints to relax the side chains and their
       # interaction with the solvent; we are anticipating doing this by asking
       # martinize.py to generate the list of atoms involved. We are asking for 
       # version 2.2 of the force field. When using the -dssp option you'll need the 
       # dssp binary, which determines the secondary structure classification of the 
       # protein backbone from the structure. 

       if [ ! -e protein-CG.pdb ] ; then
           python ./martinize.py -f protein.pdb \
	                         -o system-vacuum.top \
	                         -x protein-CG.pdb \
	                         -dssp $dssp \
	                         -p backbone \
	                         -ff martini22
       fi

       # Do a short (ca. 10 steps is enough!) minimization in vacuum. Before you can
       # generate the input files with grompp, you will need to check that the topology
       # file (.top) includes the correct martini parameter file (.itp). If this is not
       # the case, change the include statement. Also, you may have to generate a box,
       # specifing the dimensions of the system, for example using editconf. You want to
       # make sure, the box dimensions are large enough to avoid close contacts between
       # periodic images of the protein, but also to be considerably larger than twice
       # the cut-off distance used in simulations. Try allowing for a minimum distance of
       # 1 nm from the protein to any box edge. Then, copy the example parameter file,
       # and change the relevant settings to do a minimization run. Now you are ready to
       # do the preprocessing and minimization run:

       if [ ! -e minimization-vacuum.gro ] ; then

           gmx editconf -f protein-CG.pdb \
                        -d 1.0 \
                        ${comment# -bt dodecahedron } \
	                ${comment# -bt cubic } \
                        -bt cubic \
	                -o protein-CG.gro

           cp protein-CG.gro system-vacuum.gro

           gmx grompp -f minimization-vacuum.mdp \
	              -p system-vacuum.top \
	              -c system-vacuum.gro \
	              -o minimization-vacuum.tpr

           #mdrun -deffnm minimization-vacuum -v 
           # NOTE: if this fails try setting $nt (number of threads) to a smaller number)
           gmx mdrun -deffnm minimization-vacuum -v #-nt $nt

       fi

       cp minimization-vacuum.gro minimized.gro
       cp minimization-vacuum.tpr minimized.tpr
       cp minimization-vacuum.trr minimized.trr
       cp minimization-vacuum.edr minimized.edr
       cp system-vacuum.top       minimized.top


       # Solvate the system with genbox (an equilibrated water box can be downloaded
       # here; it is called water.gro, in the command below, it is saved as
       # water-box-CG_303K-1bar.gro). Make sure the box size is large enough (i.e. 
       # there is enough water around the molecule to avoid periodic boundaries 
       # artifacts) and remember to use a larger van der Waals distance when 
       # solvating to avoid clashes, e.g.:

       if [ $SOLVATE == "YES" ] ; then
           if [ ! -e system-solvated.gro ] ; then

               gmx solvate -cp minimization-vacuum.gro \
	                   -cs water.gro \
	                   -radius 0.21 \
	                   -o system-solvated.gro |& tee solv.log

               nsolv=`grep "Generated solvent" solv.log | \
	              sed -e 's/^.* in //g' -e 's/ residues.*$//g'`

               cp system-vacuum.top system-solvated.top
               echo "" >> system-solvated.top
               echo "W             $nsolv" >> system-solvated.top

           fi


           # Do a short energy minimization and position restrained simulation of the
           # solvated system. Since the martinize.py script already generated position
           # restraints (thanks to the -p flag), all you have to do is specify define =
           # -DPOSRES in your parameter file (.mdp) and add the appropriate number of water
           # beads (the molecule name is W) to your system topology (.top); the number can be
           # seen in the output of the genbox command.

           if [ ! -e minimization.gro ] ; then

               gmx grompp -f minimization-solution.mdp \
	                  -c system-solvated.gro \
	                  -p system-solvated.top \
	                  -o minimization-solution.tpr

               #mdrun -deffnm minimization -v
               # NOTE: if this fails try setting $nt (number of threads) to a smaller number)
               gmx mdrun -deffnm minimization-solution -v #-nt $nt

           fi 

           cp minimization-solution.gro minimized.gro
           cp minimization-solution.tpr minimized.tpr
           cp minimization-solution.trr minimized.trr
           cp minimization-solution.edr minimized.edr
           cp system-solvated.top       minimized.top
       fi

       # minimized.* is the base data for subsequent steps

       if [ ! -e equilibration.gro ] ; then

           gmx grompp -f equilibration.mdp \
	              -c minimized.gro \
                      -r minimized.gro \
	              -p minimized.top \
	              -o equilibration.tpr

           #mdrun -deffnm equilibration -v
           # NOTE: if this fails try setting $nt (number of threads) to a smaller number)
           gmx mdrun -deffnm equilibration -v #-nt $nt

           cp equilibration.gro equilibrated.gro
           cp equilibration.tpr equilibrated.tpr
           cp equilibration.edr equilibrated.edr
           cp minimized.top     equilibrated.top

       fi

       # equilibrated.* is the base data for subsequent steps

       # Start production run (without position restraints!); if your simulation
       # crashes, some more equilibration steps might be needed.

       if [ ! -e dynamic.gro ] ; then

           gmx grompp -f dynamic.mdp \
	              -c equilibrated.gro \
	              -r equilibrated.gro \
	              -p equilibrated.top \
	              -o dynamic.tpr

           #mdrun -deffnm dynamic -v
           # NOTE: if this fails try setting $nt (number of threads) to a smaller number)
           gmx mdrun -deffnm dynamic -v #-nt $nt

           cp dynamic.gro        dynamized.gro
           cp dynamic.tpr        dynamized.tpr
           cp dynamic.edr        dynamized.edr
           cp equilibrated.top   dynamized.top

       fi

       # convert all .gro files to .pdb preserving (pseudo)bonds and use pulchra to
       # obtain the full atom structure

       for i in *ed.gro ; do
           if [ ! -e `basename $i gro`CG.pdb ] ; then
               # ideally we would like to add -conect as well
               echo "System" | gmx trjconv -f $i \
        	                           -s `basename $i gro`tpr \
                                           -o `basename $i gro`CG.pdb \
                                           -pbc mol -conect 
           fi
       done

       # modify the pdb file by changing BB (backbone) for CA (carbon-alpha) 
       for i in *ed.CG.pdb ; do
           name=`basename $i .pdb`
           if [ ! -e `basename $i pdb`CG-ca.pdb ] ; then
               grep ' BB ' ${i} | sed -e 's/ BB / CA /g' > ${name}-ca.pdb
           fi
       done

       # use pulchra to reconstruct the full-atom model   
       for i in *CG-ca.pdb ; do
           name=`basename $i .CG-ca.pdb`
           if [ ! -e `basename $i CG-ca.pdb`FA.pdb ] ; then
               $pulchra -g -v $i
               mv ${name}.CG-ca.rebuilt.pdb ${name}.FA.pdb
           fi
       done

       # we are done
       cd ..
   done
   
   cd ..
}

martini

#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    # this may be either a command or a library function
    if [ -d "$LIB/lib" ] ; then
        LIB="$LIB/lib"
    fi
    [[ -v FS_FUNCS ]] || source $LIB/fs_funcs.bash
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash

    martini "$@"
else
    export MARTINI='MARTINI'
fi
