if [ "$file" == "" ] ; then
    file=${1:-"protein.fasta"}
fi

# get file directory
#	if $file is empty this will return "."
d=`dirname "$file"`

f="${file##*/}"
ext="${file##*.}"
n="${f%.*}"

echo "$0 $d/$n.$ext"

mkdir -p $d/i-tasser/$n
cp $file $d/i-tasser/$n/
cp $file $d/i-tasser/$n/seq.fasta

banner $n |& tee -a $d/i-tasser/$n/i-tasser.log
date -u   |& tee -a $d/i-tasser/$n/i-tasser.log

~/contrib/I-TASSER5.1/I-TASSERmod/runI-TASSER.pl \
        -pkgdir ~/contrib/I-TASSER5.1/ \
        -libdir ~/data/i-tasser \
        -runstyle gnuparallel \
        -datadir $d/i-tasser/$n \
        -outdir $d/i-tasser/$n \
        -seqname $n \
	-light true \
        -LBS \
        -EC \
        -GO \
	|& tee -a $d/i-tasser/$n/i-tasser.log

date -u |& tee -a $d/i-tasser/$n/i-tasser.log
