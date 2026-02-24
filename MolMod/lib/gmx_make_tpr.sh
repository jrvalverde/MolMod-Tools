md=${1:-md}
prev=${2:-mpt}
restraints=no

if [ ! -e $md.top ] ; then cp Complex.top $prev.top ; fi

if [ "$restraints" = "yes" ] ; then
    gmx grompp -f $md.mdp \
               -c $prev.gro \
               -r $prev.gro \
               -t $prev.cpt \
               -p $prev.top \
               -po ${md}_out.mdp \
               -pp ${md}.top \
               -o $md.tpr
else

    # Configure simulation
    #	NOTE: this should be a continuation run from previous npt or md runs
    #	NOTE: this should use $md.top instead of Complex.top
    #                           -t $md.trr???
    gmx grompp -maxwarn 3 \
               -f $md.mdp \
               -c $prev.gro \
               -t $prev.cpt \
               -p $prev.top \
               -po ${md}_out.mdp \
               -pp ${md}.top \
               -o $md.tpr

fi
