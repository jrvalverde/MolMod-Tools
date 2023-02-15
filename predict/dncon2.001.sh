file=$1
FOLD=${2:-"CONFOLD2"}

if [ -z "$FOLD" ] ; then FOLD="CONFOLD2" ; fi
#FOLD="CONFOLD2"	# CONFOLD2 CONFOLD1 UNICON3D
#FOLD="UNICON3D"
#FOLD="CONFOLD1"

comment=''	# enable comments

if [ ! -e "$file" ] ; then echo "ERROR: $file does not exist"; exit 1; fi

#some/directory/file.1.fa
filename=${file##*/}	# remove everything until the last /
name=${filename%.*}	# remove the last . and whatever follows from file name

mkdir -p $name	#create working directory

# copy sequence to working directory
cp $file $name/$name.fasta

cd $name 	#move to working directory


if [ ! -s "$name.fasta" ] ; then
    cp "$file" "${name}.fasta"
fi

function backup_file {
    local f=$1
    i=0
    if [ ! -d bck ] ; then mkdir -p bck ; fi
    while [ -e bck/$f.`printf %03d $i` ] ; do
        i=$((i + 1))
    done
    echo saving $f as bck/$f.`printf %03d $i`
    cp $f bck/$f.`printf %03d $i`
}

# Save all output to a log file
log=zyglog.DNCON2.$FOLD.outerr
if [ -e $log ] ; then
    backup_file $log
fi
# Tee output and error to a log file
#appendlog='-a'
appendlog=''
exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")
# ... or to two separate files without screen output
#myname=`basename $0 .sh`
#stdout=./$name/zyglog.$myname.out
#stderr=./$name/zyglog.$myname.err
#exec > $stdout 2> $stderr


if [ ! -e ${name}.fasta ] ; then
    echo "Usage: $0 seqname"
    echo "       a file named 'seqname' with the protein sequence must exist"
    exit 1
fi

mkdir -p out
if [ ! -e out/${name}.rr.raw ] ; then
    echo "Running DNCON2 to generate contact matrix"
    ~/contrib/DNCON2/DNCON2/dncon2-v1.0.sh ${name}.fasta out
fi
cd out

if [ "$FOLD" == "CONFOLD2" ] ; then
    #mkdir -p confold2
    ~jr/contrib/CONFOLD/confold-v2.0/confold2-main.pl \
    	-rr ${name}.dncon2.rr \
        -ss ss_sa/${name}.ss \
        -mcount 5 \
        -out confold2
        
elif [ "$FOLD" == "CONFOLD1" ] ; then
    mkdir -p confold1
    # mcount is the number of models per job, 20 by default
    ~jr/contrib/confold/confold-v1.0/confold.pl \
        -rrtype ca \
        -stage2 1 \
        -mcount 5 \
        -seq ${name}.fasta \
        -ss  ss_sa/${name}.ss ${comment# must be in three-state} \
        -rr  ${name}.dncon2.rr \
        -o   confold1
        
elif [ "$FOLD" == "UNICON3D" ] ; then
    # use UNICON3D
    #xport LD_LIBRARY_PATH=~jr/contrib/UniCon3D/lib
    
    if [ ! -e ${name}.dncon2.cm ] ; then
        echo "Converting DNCON2 RR matrix to CM format"
        python2 ~jr/contrib/UniCon3D/scripts/rr2cm.py \
	    --fasta ${name}.fasta \
            --rr ${name}.rr.raw \
            --format 5 \
            > ${name}.dncon2.cm
    fi

    if [ ! -e ${name}_stats.txt ] ; then
        echo "Running UniCon3D to generate decoys"
        LD_LIBRARY_PATH=~jr/contrib/UniCon3D/lib \
        ~jr/contrib/UniCon3D/bin/linux/UniCon3D \
	    -i ${name} \
            -f ${name}.fasta \
            -s ss_sa/${name}.ss8 \
            -c ${name}.dncon2.cm \
            -m  ~jr/contrib/UniCon3D/lib/UniCon.iohmm \
            -d 10
    fi

    if [ -e ${name}_000001.pdb ] ; then
        echo "Running pulchra to generate models"
        mkdir -p unicon3d_decoys
        mkdir -p unicon3d_models
        for i in *.pdb ; do
            ~jr/contrib/UniCon3D/pulchra_306/pulchra -g -v $i
            mv $i unicon3d_decoys
            mv `basename $i .pdb`.rebuilt.pdb unicon3d_models
        done
    fi
else

    echo "ERROR: unknown fold method $FOLD"

fi
cd -
echo "Done. Now you should inspect and minimize the models in out/models/."
