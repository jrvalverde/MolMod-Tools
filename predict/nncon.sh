# sequence must be in a fasta file, all in one line, without \n at the end
# NEdit adds a \n, joe doesn't. This is a requirement of UniCon3D only.
seq=$1


FOLD="UNICON3D"	# CONFOLD2 CONFOLD1 UNICON3D

mkdir -p nncon
cp $seq.faa nncon

# from now on, we work inside the output directory
cd nncon

# Run NNcon to get contact map
if [ ! -e ./${seq}_faa.cm8a ] ; then
    echo "Running NNcon to get contact map using ab-initio"
    export PATH=~jr/contrib/nncon/bin:$PATH
    LD_LIBRARY_PATH=~jr/contrib/nncon/lib \
    predict_ss_sa_cm.sh ${seq}.faa ./
fi

# Run Scratch to predict secondary structure using 16 threads
if [ ! -e ${seq}.ss8 ] ; then
    echo "Running SCRATCH to get secondary structure"
    export PATH=~jr/contrib/DNCON2/SCRATCH-1D_1.1/bin:$PATH
    run_SCRATCH-1D_predictors.sh ${seq}.faa ${seq} 16
fi

if [ "$FOLD" == "UNICON3D" ] ; then
    # Run UniCon3D
    if [ ! -e ${seq}_000010.pdb ] ; then
        echo "Running UniCon3D to get decoys"
        LD_LIBRARY_PATH=~jr/contrib/UniCon3D/lib \
          ~jr/contrib/UniCon3D/bin/linux/UniCon3D \
              -m ~jr/contrib/UniCon3D/lib/UniCon.iohmm \
              -i ${seq} -f ${seq}.faa -s ${seq}.ss8 -c ./${seq}_faa.cm8a \
              -d 10		# generate 10 decoys
    fi

    if [ ! -e ${seq}_000001.pdb ] ; then
        echo "UniCon3D failed"
        exit 1
    fi

    if [ ! -e ${seq}_000010.rebuilt.pdb ] ; then
        echo "Running pulchra to get models"
        for i in *.pdb ; do 
            ~jr/contrib/UniCon3D/pulchra_306/pulchra -g -v -p -q $i 
        done
    fi

    #mv ${seq}* nncon
    #cp nncon/${seq}.faa .
    
elif [ "$FOLD" == "CONFOLD2" ] ; then
    #mkdir -p confold2
    ~jr/contrib/CONFOLD/confold-v2.0/confold2-main.pl \
    	-rr ${seq}.dncon2.rr \
        -ss ss_sa/${seq}.ss \
        -mcount 5 \
        -out confold2
        
elif [ "$FOLD" == "CONFOLD1" ] ; then
    mkdir -p confold1
    # mcount is the number of models per job, 20 by default
    ~jr/contrib/confold/confold-v1.0/confold.pl \
        -rrtype ca \
        -stage2 1 \
        -mcount 5 \
        -seq ${seq}.fasta \
        -ss  ss_sa/${seq}.ss8 \
        -rr  ${seq}.rr.raw \
        -o   confold1
fi
