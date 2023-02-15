
function dncon2() {
    # USAGE: dncon2 seqfile.fas [REFINE-METHOD]
    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "seqfile.fas [CONFOLD2|UNICON3D@CONFOLD1]" 
    else notecont $* ; fi
        
    # Define the arguments of the function and their default values
    local file=$1
    local FOLD=${2:-"CONFOLD2"}	# default refine method is CONFOLD2

    local myhome=`dirname $0`
    # Define the path where the dncon2 command is stored 
    local DNCON2_COMMAND=~/contrib/DNCON2/DNCON2/dncon2-v1.0.sh
    # Define the paths where the CONFOLD2 and CONFOLD1 commands are stored
    local CONFOLD2_COMMAND=~/contrib/confold/confold-v2.0/confold2-main.pl
    local CONFOLD1_COMMAND=~/contrib/confold/confold-v1.0/confold.pl
    # Define the path where the RR2CM command to elaborate a contact matrix is stored
    local RR2CM_COMMAND="python2 ~/contrib/UniCon3D/scripts/rr2cm.py"
    # Define the paths where the UNICON3D and PULCHRA commands are stored
    local UNICON3D_DIR=~/contrib/UniCon3D
    local UNICON3D_COMMAND="LD_LIBRARY_PATH=$UNICON3D_DIR/lib $UNICON3D_DIR/bin/linux/UniCon3D"
    local PULCHRA_COMMAND="$UNICON3D_DIR/pulchra_306/pulchra"
    # Define the path where the bable command is stored
    local BABEL_COMMAND=`which babel`

#    local ANACONDA=$HOME/contrib/miniconda3
#    . $ANACONDA/etc/profile.d/conda.sh
#    conda activate
    
    # Check if the variable FOLD exists and is empty
    if [ -z "$FOLD" ] ; then FOLD="CONFOLD2" ; fi
    #FOLD="CONFOLD2"	# CONFOLD2 CONFOLD1 UNICON3D
    #FOLD="UNICON3D"
    #FOLD="CONFOLD1"

    local comment=''	# enable comments

    # Check if the file exists
    if [ ! -e "$file" ] ; then echo "ERROR: $file does not exist"; exit 1; fi
    # Get the absolute path of the file
    file=`abspath $file`	# from fs_funcs.bash

    #some/directory/file.1.fa
    local filename=${file##*/}	# remove everything until the last /
    local name=${filename%.*}	# remove the last . and whatever follows from file name
    
    # Create working directory
    mkdir -p dncon2

    # Save all output to a log file in dncon2
    local log=dncon2/zyglog.DNCON2.$name.$FOLD.std
    notecont "log (stdout and stderr) will be saved to $log"
    if [ -e $log ] ; then
        version_file $log
    fi
    appendlog=''
    exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")


    # copy sequence to working directory
    if [ ! -s "dncon2/$name.fasta" ] ; then	# this should never happen     
        cp "$file" "dncon2/${name}.fasta"
    fi

    # check it worked
    if [ ! -s dncon2/${name}.fasta ] ; then
        echo "Usage: $0 seqname"
        echo "       a file named 'seqname' with the protein sequence must exist"
        exit $ERROR
    fi

    # Note, we do a lot of cd in and out, but this will always guarantee
    # that when we exit, we are at the original folder

    # Run DNCON2 to get a good contact matrix
    if [ ! -e dncon2/${name}.rr.raw ] ; then
        echo "Running DNCON2 to generate contact matrix"
        $DNCON2_COMMAND ${name}.fasta dncon2
    fi
    
    # Check if a contact matrix was obtained
    if [ ! -s dncon2/${name}.dncon2.rr -o ! -s dncon2/${name}.rr.raw ] ; then
        warncont " dncon2/${name}.dncon2.rr does not exist!"
        warncont " This means that there was an error running DNCON2"
        warncont " or that DNCON2 could not build a contact matrix."
        warncont " The folder"
        warncont "	dncon2/confold2-${name}.dncon2/top-models"
        warncont " does not exist either!"
        warncont " We cannot create it with CONFOLD2 without the RR file."
        warncont " We will create an empty"
        warncont "	dncon2/confold2-${name}.dncon2/top-models"
        warncont " folder to avoid future warnings."
        warncont ""
        warncont " If you still want a DNCON2 prediction, check the log"
        warncont " file, fix any issues with DNCON2 (if possible), delete"
        warncont " the dncon2 output folder(s) and rerun this script."
        
        # Create the directory where the best models will be stored
        mkdir -p ./dncon2/confold2-${name}.dncon2/top-models
    fi


    # Use the DNCON2 contact matrix to generate models using the specified method
    if [ "$FOLD" == "CONFOLD2" ] ; then
        if ! isempty dncon2/confold2-${name}.dncon2/top-models ; then
            notecont "CONFOLD2 already run"
            notecont "remove directory '${name}/confold2-${name}.dncon2/top-models'"
            notecont "if you want to repeat the calculations"
        else
            # enter dncon2
            cd dncon2
            # run confold2
            # this will create a folder dncon2/confold2-$name.dncon2
            $CONFOLD2_COMMAND \
    	        -rr ${name}.dncon2.rr   ${comment# Contact matrix file} \
                -ss ss_sa/${name}.ss \
                -mcount 5 \
                -out confold2           ${comment# Output directory}
	    cd -
        fi        

        # check if it worked
        # the resulting models should be in dncon2/confold2-$name.dncon2/top-models
        if isempty dncon2/confold2-${name}.dncon2/top-models ; then
            errexit "CONFOLD2 did not generate any models"
        else
            cd dncon2
            ln -s confold2-$name.dncon2/top-models unranked_models
            cd -
        fi
        
        # Check if confold1 has been already run
    elif [ "$FOLD" == "CONFOLD1" ] ; then
        if [ -e dncon2/confold1/stage2/${name}_model1.pdb ] ; then
            notecont "CONFOLD1 already run"
            notecont "remove directory dncon2/confold1 if you want to"
            notecont "repeat the calculations"
            exit $OK
        fi

        # run confold1
        cd dncon2
        mkdir -p confold1
        # mcount is the number of models per job, 20 by default
        $CONFOLD1_COMMAND \
            -rrtype ca \
            -stage2 1 \
            -mcount 5 \
            -seq ${name}.fasta      ${comment# protein sequence} \
            -ss  ss_sa/${name}.ss   ${comment# must be in three-state} \
            -rr  ${name}.dncon2.rr  ${comment# Contact matrix file} \
            -o   confold1           ${comment# output directory} \
        cd -
        
        # Check if it worked
        if isempty dncon2/confold1/stage2 ; then
            errexit "CONFOLD1 did not generate any decoys"
        else
            cd dncon2
            ln -s confold1/stage2 unranked_models
            cd -
        fi
        
    elif [ "$FOLD" == "UNICON3D" ] ; then
        # use UNICON3D
        #xport LD_LIBRARY_PATH=~jr/contrib/UniCon3D/lib
        
        # Convert the contact matrix file to a proper format to run unicon3d
        if [ ! -e dncon2/${name}.dncon2.cm ] ; then
            notecont "Converting DNCON2 RR matrix to CM format"
            cd dncon2
            $RR2CM_COMMAND \
	        --fasta ${name}.fasta \
                --rr ${name}.rr.raw \
                --format 5 \
                > ${name}.dncon2.cm
            cd -
        fi

        if [ ! -e dncon2/${name}_stats.txt ] ; then
            notecont "Running UniCon3D to generate decoys"
            cd dncon2
            # run unicon3d
            $UNICON3D_COMMAND \
	        -i ${name} \
                -f ${name}.fasta          ${comment# protein sequence} \
                -s ss_sa/${name}.ss8 \
                -c ${name}.dncon2.cm      ${comment# Contact matrix file} \ 
                -m $UNICON3D_DIR/lib/UniCon.iohmm \
                -d 10
            cd -
        fi
        
        # Check if it worked and run pulchra to generate the final models
        if [ -e dncon2/${name}_000001.pdb ] ; then
            notecont "Running pulchra to generate models"
            cd dncon2
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
            ln -s unicon3d_models unranked_models
            cd -
        else
            errexit "UNICON3D did not generate any decoys"
        fi

    else

        errexit "ERROR: unknown fold method $FOLD"

    fi
    
    # the pdb files generated by CONFOLD2 sometimes have some mistakes leading to a failure
    # when they are going to be refined by CABS. We will use a function tu fix them so 
    # now CABS won't fail.
    
    #cd dncon2/unranked_models
    #fix_3D_templates
    #cd -
        
    # score unranked models
    # there may be a large amount of models (100+)
    # we will use a quick scoring function to rank them (apollo)
    cd dncon2
      # check if apollo has been already run
      if isempty $name.apollo ; then
          notecont "Running apollo on CONFOLD2 top-models"
          eval apollo $file unranked_models $LOG	# from apollo.bash
      fi
      # check if apollo did run successfully
      if [ ! -e $name.apollo/unranked_models.avg ] ; then
         errexit "I cannot find apollo scores for any DNCON2+CONFOLD2 model"
      fi
    cd -	# return to our former place

    # Now we only need to copy the ranked models to the output model folder
    # dncon2/$name
    # Define where apollo has been run
    local apollo_ranking="dncon2/$name.apollo/unranked_models.avg"
    # Define where unranked models are stored
    local unranked_models=dncon2/unranked_models
    # Define the output directory
    local modeldir="dncon2/$name"
    if [ -d "$unranked_models" ] ; then
        # check if there are any models to copy (do an ls and count them)
        nmodels=`/bin/ls -1A $unranked_models/*.pdb 2> /dev/null | wc -l`
        if [ "$nmodels" -gt 0 ] ; then
            mkdir -p $modeldir
            if isempty $apollo_ranking ; then
                notecont "apollo ranking not found, using unranked models"
                notecont "if you still want ranked models, remove $name/apollo"
                notecont "and try again"
                cd dncon2
                ln -s $unranked_models $modeldir
                cd ..
                exit $OK
            fi

            # let us select the decoys produced and 
            # store them named by score order
            if [ ! -e $modeldir/1.dncon2.*.pdb ] ; then
	        notecont "Selecting ranked DNCON2 models"
	        order=0
	        cat $apollo_ranking \
	        | tail -n+5 \
                | grep -v "^END$" \
	        | while read model score ; do
                    order=$(( order + 1 ))
                    if [ -s $unranked_models/$model ] ; then
                        # add chain ID
                        cat $unranked_models/$model \
                        | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
                        > $modeldir/${order}.dncon2.$model
                    else
                        warncont "DNCON2 $model does not exist or is empty"
                    fi
	        done
            fi
        fi
    fi


    notecont "Done. Now you should inspect and minimize the models in dncon2/models/."

#    conda deactivate
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
    [[ -v FS_FUNCS ]] || source $LIB/fs_funcs.bash
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash
    [[ -v APOLLO ]] || source $LIB/apollo.bash
    [[ -v FIX_3D_TEMPLATES ]] || source $LIB/fix_3D_templates.bash

    dncon2 "$@"
else
    export DNCON2='DNCON2'
fi
