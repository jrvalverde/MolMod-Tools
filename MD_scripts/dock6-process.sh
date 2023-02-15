#!/bin/bash

scripts=~/work/mtabone/script
knl=~/work/karthika/known/1JDH_B_dockprep.mol2
DOCKPREP='yes'

for i in *.pdb ; do
    nam=`basename $i .pdb`
    echo "Processing $nam"
    if [ "$DOCKPREP"='yes' ] ; then
        if [ ! -s ${nam}-C.mol2 ] ; then
            echo "Running DockPrep on $nam"
            cat > $nam.py <<END
import chimera
from DockPrep import prep
models = chimera.openModels.list(modelTypes=[chimera.Molecule])
#prep(models,    addHFunc=AddH.hbondAddHydrogens, hisScheme=None, 
#                mutateMSE=True, mutate5BU=True, mutateUMS=True, mutateCSL=True,
#                delSolvent=True, delIons=False, delLigands=False, 
#                delAltLocs=True, incompleteSideChains="rotamers", nogui=False, 
#                rotamerLib=defaults[INCOMPLETE_SC], rotamerPreserve=True)
prep(models, delIons=True, delLigands=False)
from WriteMol2 import writeMol2
writeMol2(models, "${nam}-C.mol2")
import Midas
Midas.write(models, None, "${nam}-C.pdb")
END
	    chimera --nogui $i $nam.py 
        fi
        echo "Extracting components of $nam"
	chimera --nogui <<END
            open ${nam}-C.mol2
            #open $nam.pdb
            #addcharge all chargeModel 99sb method am1
            #write format mol2 ${nam}.mol2
            select protein
            write selected format pdb 0 ${nam}-R.pdb
            write selected format mol2 0 ${nam}-R.mol2
            select ~protein
            write selected format pdb 0 ${nam}-L.pdb
            write selected format mol2 0 ${nam}-L.mol2
            close 0
END
    elif [ "$ALLATONCE" = 'yes' ] ; then
	chimera --nogui <<END
            open $nam.pdb
            addcharge all chargeModel 99sb method am1
            write format pdb 0 ${nam}-C.pdb
            write format mol2 0 ${nam}-C.mol2
            select protein
            write selected format pdb 0 ${nam}-R.pdb
            write selected format mol2 0 ${nam}-R.mol2
            select ~protein
            write selected format pdb 0 ${nam}-L.pdb
            write selected format mol2 0 ${nam}-L.mol2
            close 0
END
    else
	chimera --nogui <<END
            open $nam.pdb
            select protein
            write selected format pdb 0 ${nam}-R.pdb
            select ~protein
            write selected format pdb 0 ${nam}-L.pdb
	    close 0
	    open ${nam}-R.pdb
	    addcharge all chargeModel 99sb method gasteiger
            write format mol2 0 ${nam}-R.mol2
            close 0
            open ${nam}-L.pdb
	    addcharge all chargeModel 99sb method am1
            write format mol2 0 ${nam}-L.mol2
	    close 0
END
    fi
    # last resource, use babel if possible
    if [ -s ${nam}-R.pdb -a ! -s ${nam}-R.mol2 ] ; then
        babel -ipdb ${nam}-R.pdb -omol2 ${nam}-R.mol2
    fi
    if [ -s ${nam}-L.pdb -a ! -s ${nam}-L.mol2 ] ; then
        babel -ipdb ${nam}-L.pdb -omol2 ${nam}-L.mol2
    fi
    if [ ! -s ${nam}-R.pdb -o ! -s ${nam}-L.mol2 ] ; then
        echo "ERROR: ($nam) COULD NOT EXTRACT LIGAND AND RECEPTOR"
        continue
    fi
    if [ ! -s knl.mol2 ] ; then cp $knl knl.mol2 ; fi
    echo "Doing DSX score"
    bash $scripts/score_dsx.sh ${nam}-R.pdb ${nam}-L.mol2 knl.mol2
    echo "Doing Score score"
    bash $scripts/score_score.sh ${nam}-R.pdb ${nam}-L.mol2 knl.mol2
    echo "Doing Xscore score"
    bash $scripts/score_xscore.sh ${nam}-R.pdb ${nam}-L.mol2 knl.mol2
done

