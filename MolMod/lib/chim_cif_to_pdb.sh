cif=$1
mol2=${cif%.cif}.ch.mol2
pdb=${cif%.cif}.ch.pdb

if [ ! -e $cif ] ; then echo "$cif doesn't exist, ignoring" ; fi
if [ -e $mol2 ] ; then mv $mol2 $mol2.bck ; fi
if [ -e $pdb ] ; then mv $pdb $pdb.bck ; fi

DISPLAY='' chimera --nogui --visual '' --screen '' <<END
    open $cif
    write format mol2 0 $mol2
    write format pdb 0 $pdb
END
