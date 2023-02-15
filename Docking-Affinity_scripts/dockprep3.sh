nam=`basename $1 .pdb`
nam=`basename $nam .mol2`

cat > dockprep.py <<END
import chimera
from chimera import runCommand
from DockPrep import prep
from WriteMol2 import writeMol2
import Midas

models = chimera.openModels.list(modelTypes=[chimera.Molecule])
#prep(models,    addHFunc=AddH.hbondAddHydrogens, hisScheme=None, 
#                mutateMSE=True, mutate5BU=True, mutateUMS=True, mutateCSL=True,
#                delSolvent=True, delIons=False, delLigands=False, 
#                delAltLocs=True, incompleteSideChains="rotamers", nogui=False, 
#                rotamerLib=defaults[INCOMPLETE_SC], rotamerPreserve=True)
prep(models, delIons=True, delLigands=True)
# write whole system
writeMol2(models, "${nam}-dp.mol2")
Midas.write(models, None, "${nam}-dp.pdb")
# write chain A DOES NOT WORK AS IS
#runCommand('sel #*:*.A')
#writeMol2(models, "${nam}-A-dp.mol2")
#Midas.write(models, None, "dp/${nam}-A-dp.pdb")
# write chain B
#runCommand('sel #*:*.B')
#writeMol2(models, "${nam}-B-dp.mol2")
#Midas.write(models, None, "${nam}-B-dp.pdb")
END

chimera --nogui $1 dockprep.py #&> ${nam}-dockprep.log

rm dockprep.py*

echo "DockPrep'ped $1"

