ff=$1

alias ProFit=~/contrib/bioinf.org.ac.uk/ProFitV3.1/ProFit

for i in *.pdb ; do
    echo $i
    r=$i 
    b=`basename $i .pdb`
    m=$ff/obm_${b}_$ff/$b.H_$ff.pdb
    aarmsd=$ff/obm_${b}_$ff/$b.H_$ff.aa.rmsd
    ls $r $m 
    ~/contrib/bioinf.org.ac.uk/ProFitV3.1/ProFit <<END
    REFERENCE $r
    MOBILE $m
    FIT
    RESIDUE $aarmsd
END
    cat $aarmsd | cut -c1-7,37-42 > aa.rms
    ctioga2 aa.rms
    rm aa.rms
    mv Plot-000.pdf $ff/obm_${b}_$ff/$b.H_$ff.aa.pdf
done
