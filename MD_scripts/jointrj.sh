gmx trjcat \
	-f step7_?.trr step7_??.trr \
	-o step7.trr \
	-cat

cp step7_1.tpr step7.tpr

echo 0 \
| gmx trjconv \
	-f step7.trr \
	-s step7.tpr \
	-o step7_noPBC.xtc \
	-pbc mol \
	-conect

echo 1 \
| gmx trjconv \
	-f step7.trr \
	-s step7.tpr \
	-o step7_noPBC.p.xtc \
	-pbc mol \
	-conect

gmx eneconv \
	-f step7_?.edr step7_??.edr \
	-o step7.edr
