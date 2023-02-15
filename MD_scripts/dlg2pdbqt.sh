dlg=$1

grep '^DOCKED' $1 | cut -c9- > `basename $1 dlg`pdbqt
cut -c-66 $1 > `basename $1 qt`
