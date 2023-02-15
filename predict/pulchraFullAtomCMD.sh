
cg_gro=${1:-CG_posre.gro}
name=${cg_gro%.gro}

gmx trjconv -f $cg_gro -s $name.tpr -pbc mol -conect -o ${name}.CG.pdb 
grep ' BB ' ${name}.CG.pdb | sed -e 's/ BB / CA /g' > ${name}.CG-ca.pdb
~/contrib/UniCon3D/pulchra_306/pulchra -g -v ${name}.CG-ca.pdb
mv ${name}.CG-ca.rebuilt.pdb ${name}.FA.pdb
