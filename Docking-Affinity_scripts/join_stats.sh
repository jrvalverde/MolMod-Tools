#!/bin/bash

banner summary

R=$1
L=$2

#BASE=`(cd ../script ; pwd)`
BASE=`dirname "$(readlink -f "$0")"`


for m in aff ; do
    stat=$m/stats
    out=$m/summary
    mkdir -p $out

    # we do not want header lines nor empty lines    
    echo "H-bonds clashes contacts repulsion"
    cat $stat/hbond-${R}_${L}.cnt | grep -v '^$' | sort -d > $out/hbond-${R}_${L}.tab
    cat $stat/clash-${R}_${L}.cnt | grep -v '^$' | sort -d > $out/clash-${R}_${L}.tab
    cat $stat/contact-${R}_${L}.cnt | grep -v '^$' | sort -d > $out/contact-${R}_${L}.tab
    cat $stat/repulsion-${R}_${L}.tab | grep -v '^$' | sort -d > $out/repulsion-${R}_${L}.tab


    echo "RMSD"
    #tail -n +2 $m/stats/RMSD${R}${L}.tab | sed -e 's/.pdb//g' | sort -d > RMSD.tab
    #tail -n +2 $m/stats/RMSD${R}${L}.ni.tab | sed -e 's/.pdb//g' | sort -d > RMSD.ni.tab
    #tail -n +2 $m/stats/RMSD${R}${L}.tab | sort -d > RMSD.tab
    #tail -n +2 $m/stats/RMSD${R}${L}.ni.tab | sort -d > RMSD.ni.tab
    cat $stat/RMSD-${R}_${L}.tab | grep -v '^$' | sort -d > $out/RMSD-${R}_${L}.tab
    cat $stat/RMSD-${R}_${L}.ni.tab | grep -v '^$' | sort -d > $out/RMSD-${R}_${L}.ni.tab
    
    echo "Energy"
    #cat aff/stats/energy.info \
    #| sed -e 's|.*/||g' \
    #| sed -e 's/ \+/	/g' \
    cat $stat/energy-${R}_${L}.info \
    | grep -v '^$' \
    | grep -v solvent \
    | sort -d \
    > $out/energy-${R}_${L}.tab
    cat $stat/energy-${R}_${L}.info \
    | grep -v '^$' \
    | grep solvent \
    | sort -d \
    > $out/Senergy-${R}_${L}.tab

    echo "Docking scores"
    # do also add the .pdb to the file base name
    #cat $m/stats/dsx${R}${L}.info \
    #| tr -d ':' \
    #| sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    #| sort -d | tail -n +2 > dsx.tab
    #cat $m/stats/xscore${R}${L}.info \
    #| tr -d ':' \
    #| sed -e 's|	kcal/mol||g' \
    #| sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    #| sort -d > xscore.tab
    #tail -n +2 $m/stats/dlscore${R}${L}.info \
    #| sed -e 's/mutant/@mutant/g' \
    #| tr '@' '\n' \
    #| grep -v '^$' \
    #| sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    #| sort -d > dlscore.tab
    # remove header line and copy the data
    tail -n +2 $stat/dlscore-${R}_${L}.info | grep -v '^$' | sort -d > $out/dlscore-${R}_${L}.tab
    tail -n +2 $stat/dsx-${R}_${L}.info | grep -v '^$' | sort -d > $out/dsx-${R}_${L}.tab
    tail -n +2 $stat/dsxR-${R}_${L}.info | grep -v '^$' | sort -d > $out/dsxR-${R}_${L}.tab
    cat $m/stats/xscore-${R}_${L}.info | grep -v '^$' | sort -d > $out/xscore-${R}_${L}.tab

    echo "Making joint summaries" 
    # Now create an all-together file
    # this one will only contain _amber entries
    join -t '	' -a 1 -e NA -o auto -j 1 $out/clash-${R}_${L}.tab $out/contact-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/hbond-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/repulsion-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/energy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/RMSD-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/RMSD-${R}_${L}.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/dsx-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/xscore-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/dlscore-${R}_${L}.tab \
    > $out/summary-${R}_${L}.tab

    cat > $out/summary-${R}_${L}+.tab <<END
model	clash	contact	hbond	repulsion	E (vacuo)	E (sol)	RMSD (all)	RMSD	DSX	PCS	SAS	Xscore (kcal/mol)	Vina ΔG (kcal/mol)	NNScore (pKd)	DLScore (pKd)
END
#
    join -t '	' -a 1 -e NA -o auto -j 1 $out/clash-${R}_${L}.tab $out/contact-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/hbond-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/repulsion-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/energy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/Senergy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/RMSD-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/RMSD-${R}_${L}.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/dsx-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/xscore-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $out/dlscore-${R}_${L}.tab \
    >> $out/summary-${R}_${L}+.tab
    
    
    cat > $out/header+.tab <<END
model	clash	contact	hbond	repulsion	E (vacuo)	E (sol)	RMSD (all)	RMSD	DSX	PCS	SAS	Xscore (kcal/mol)	Vina ΔG (kcal/mol)	NNScore (pKd)	DLScore (pKd)
END

done
