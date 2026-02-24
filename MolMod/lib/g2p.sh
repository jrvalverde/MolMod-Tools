gro=$1
tpr=$2
pdb=$3

gmx trjconv -f $gro -s $tpr -o $pdb -pbc mol -center
