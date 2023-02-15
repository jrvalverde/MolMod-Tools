for i in *.gro ; do 
    n=`basename $i .gro`
    if [ ! -e $n.pdb ] ; then
#        gmx editconf -f $i -o $n.pdb -pbc 
	if [ ! -s $n.tpr ] ; then tpr=step7_1.tpr ; else tpr=$n.tpr ; fi
        gmx trjconv -s $tpr -f $n.gro -o $n.pdb \
            -pbc whole -conect
    fi
done
