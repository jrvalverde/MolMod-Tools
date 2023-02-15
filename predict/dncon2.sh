
function dncon2() {
    # USAGE: dncon2 seqfile.fas [REFINE-METHOD]
    file=$1
    FOLD=${2:-"CONFOLD2"}	# default refine method is CONFOLD2

    myhome=`dirname $0`
    DNCON2_COMMAND=~/contrib/DNCON2/DNCON2/dncon2-v1.0.sh
    CONFOLD2_COMMAND=~/contrib/confold/confold-v2.0/confold2-main.pl
    CONFOLD1_COMMAND=~/contrib/confold/confold-v1.0/confold.pl
    RR2CM_COMMAND="python2 ~/contrib/UniCon3D/scripts/rr2cm.py"
    UNICON3D_COMMAND="LD_LIBRARY_PATH=~/contrib/UniCon3D/lib ~/contrib/UniCon3D/bin/linux/UniCon3D"
    PULCHRA_COMMAND="jr/contrib/UniCon3D/pulchra_306/pulchra"
    BABEL_COMMAND=babel

    if [ -z "$FOLD" ] ; then FOLD="CONFOLD2" ; fi
    #FOLD="CONFOLD2"	# CONFOLD2 CONFOLD1 UNICON3D
    #FOLD="UNICON3D"
    #FOLD="CONFOLD1"

    comment=''	# enable comments

    if [ ! -e "$file" ] ; then echo "ERROR: $file does not exist"; exit 1; fi
    file=`abspath $file`	# from fs_funcs.bash

    #some/directory/file.1.fa
    filename=${file##*/}	# remove everything until the last /
    name=${filename%.*}	# remove the last . and whatever follows from file name

    mkdir -p $name	#create working directory 
    mkdir -p $name/dncon2

    # Save all output to a log file in $name/dncon2
    log=dncon2/zyglog.DNCON2.$name.$FOLD.std
    if [ -e $log ] ; then
        version_file $log
    fi
    appendlog=''
    exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")


    cd $name 	#move to working directory

    # copy sequence to working directory
    if [ ! -s "$name.fasta" ] ; then	# this should never happen     
        cp "$file" "${name}.fasta"
    fi


    if [ ! -s ${name}.fasta ] ; then
        echo "Usage: $0 seqname"
        echo "       a file named 'seqname' with the protein sequence must exist"
        exit 1
    fi

    # Run DNCON2 to get a good contact matrix
    if [ ! -e dncon2/${name}.rr.raw ] ; then
        echo "Running DNCON2 to generate contact matrix"
        $DNCON2_COMMAND ${name}.fasta dncon2
    fi

    # XXX JR XXX Check this and below under UNICON3D (is it $name.rr.raw?)
    if [ ! -s ${name}.dncon2.rr -o ! -s ${name}.rr.raw ] ; then
        echo "Warning: ${name}.dncon2.rr does not exist!"
        echo "Warning: This means that there was an error running DNCON2"
        echo "Warning: or that DNCON2 could not build a contact matrix."
        echo "Warning: The folder"
        echo "Warning:	./confold2-${name}.dncon2/top-models"
        echo "Warning: does not exist either!"
        echo "Warning: We cannot create it with CONFOLD2 without the RR file."
        echo "Warning: We will create an empty"
        echo "Warning:	./confold2-${name}.dncon2/top-models"
        echo "Warning: folder to avoid future warnings."
        mkdir -p ./confold2-${name}.dncon2/top-models
        echo "Warning:"
        echo "Warning: If you still want a DNCON2 prediction, check the log"
        echo "Warning: file, fix any issues with DNCON2 (if possible), delete"
        echo "Warning: the dncon2 output folder(s) and rerun this script."
        exit 0
    fi


    # Use the DNCON2 contact matrix to generate models using the specified method
    cd dncon2
    if [ "$FOLD" == "CONFOLD2" ] ; then
        if [ -d ./confold2-${name}.dncon2/top-models ] ; then
            echo "CONFOLD2 already run"
            echo "remove directory 'top-models' if you want to"
            echo "repeat the calculations"
            exit 0
        fi

        # this will create a folder confold2-$name.dncon2
        $CONFOLD2_COMMAND \
    	    -rr ${name}.dncon2.rr \
            -ss ss_sa/${name}.ss \
            -mcount 5 \
            -out confold2

        # the resulting models will be in ./confold2-$name.dncon2/top-models
        # there may be a large amount of models (100+)
        # we will use a quick score function to rank them
        cd ./confold2-$name.dncon2/
          if [ ! -d $name.apollo ] ; then
              $myhome/apollo.sh $sequence top-models	### XXX JR XXX ###
          fi
        cd ..
    elif [ "$FOLD" == "CONFOLD1" ] ; then
       if [ -e ./confold1/stage2/${name}_model1.pdb ] ; then
           echo "CONFOLD1 already run"
           echo "remove directory dncon2/confold1 if you want to"
           echo "repeat the calculations"
           exit 0
       fi

        mkdir -p confold1
        # mcount is the number of models per job, 20 by default
        $CONFOLD1_COMMAND \
            -rrtype ca \
            -stage2 1 \
            -mcount 5 \
            -seq ${name}.fasta \
            -ss  ss_sa/${name}.ss ${comment# must be in three-state} \
            -rr  ${name}.dncon2.rr \
            -o   confold1

        # the resulting output models will be in ./confold1/stage2/
        cd ./confold1/
        if [ ! -d $name.apollo ] ; then
            $myhome/apollo.sh $sequence stage2	### XXX JR XXX ###
        fi
        cd ..

    elif [ "$FOLD" == "UNICON3D" ] ; then
        # use UNICON3D
        #xport LD_LIBRARY_PATH=~jr/contrib/UniCon3D/lib

        if [ ! -e ${name}.dncon2.cm ] ; then
            echo "Converting DNCON2 RR matrix to CM format"
            $RR2CM_COMMAND \
	        --fasta ${name}.fasta \
                --rr ${name}.rr.raw \
                --format 5 \
                > ${name}.dncon2.cm
        fi

        if [ ! -e ${name}_stats.txt ] ; then
            echo "Running UniCon3D to generate decoys"
            $UNICON3D_COMMAND \
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
            mkdir -p unicon3d_pulchra
            mkdir -p unicon3d_models
            for i in *.pdb ; do
                mv $i unicon3d_decoys
               $PULCHRA_COMMAND -g -v unicon3d_decoys/$i
                mv unicon3d_decoys/`basename $i .pdb`.rebuilt.pdb \
                   unicon3d_pulchra/
                # pulchra does not add hydrogens, add them using babel
                $BABEL_COMMAND -h -c \
                      -ipdb unicon3d_pulchra/`basename $i .pdb`.rebuilt.pdb \
                      -opdb unicon3d_models/`basename $i .pdb`.rebuilt.pdb
            done
        fi

        # score the models using APOLLO
        if [ ! -d $name.apollo ] ; then
            $myhome/apollo.sh $sequence unicon3d_models		### XXX JR XXX ###
        fi

    else

        echo "ERROR: unknown fold method $FOLD"

    fi
    cd -
    echo "Done. Now you should inspect and minimize the models in dncon2/models/."

}



#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    # this may be either a command or a library function
    if [ -d "$LIB/lib" ] ; then
        LIB="$LIB/lib"
    fi
    source $LIB/fs_funcs.bash
    source $LIB/util_funcs.bash

    dncon2 "$@"
else
    export DNCON2
fi
