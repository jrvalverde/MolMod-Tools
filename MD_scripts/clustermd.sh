#!/bin/bash

# simple script for a Gromacs cluster from a molecular dynamic
# use the files generated in the MD of the script cmd.sh
# modification of a JR Valverde's script
# stay in the folder where MD files are in
 
# keep the cluster files into a new folder

mkdir clustermd

cp md_0-10ns.tpr -t clustermd

cp md_0-10ns_noPBC_prot.xtc -t clustermd

cd clustermd/

# clustering
# clustering of the protein

gmx cluster -s md_0-10ns.tpr -f md_0-10ns_noPBC_prot.xtc -cl mdclusterprot.pdb <<END

1


1

END

echo "Protein cluster finished" | tee proteincluster.end


#clustering of the system

gmx cluster -s md_0-10ns.tpr -f md_0-10ns_noPBC_prot.xtc -cl mdclustersystem.pdb <<END
0

0

END

echo "System cluster finished" | tee systemcluster.end











     
	
