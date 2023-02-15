#!/bin/bash


#comment=''
# this allows inline comments of the form
${comment# whatever (even multiline)}
# while this
unset comment
# will allow inline comments of the form
#${comment# whatever}
#${comment+ whatever
#	       (and even multiline comments) }


function CABS_refine() {

    # Check if the correct number of arguments was given
    if [ $# -lt 1 ] ; then errexit "structure.pdb [contactmap.rr5.raw]" 
    else notecont $* ; fi

    # Define the arguments of the function and their default values
    local pdb="$1"
    local cm=${2:-contactmap.rr5}
    
    local babel=`which obabel`		# openbabel (to generate fasta file)
    
    # Check if the pdb file of the model exists and isn't empty
    if [ ! -s $pdb ] ; then 
        errexit "$pdb does not exist"
    fi    
    # we have a file to refine
    local file=`abspath $pdb`		# get actual physical full-path file name
    local f="${file##*/}"		# remove path (leave XXXX.pdb or XXXX.pdb.gz)
    local ext="${f##*.}"		# extract LAST extension (remove everything up to the last dot)
    local nam="${f%.*}"		# remove anything after the last dot
    if [ "$ext" = "gz" ] ; then
        # remove BUTLAST extension as well
        ext="${nam##*.}"		# extract LAST extension from pruned name
        nam="${nam%.*}"
    fi
    # we will create all the output in a directory named after the file
    mkdir -p $nam
    # check the extension (after removing ".gz")
    if [ "$ext" = "pdb" ] ; then 
        cp $file $nam/
    # check for alternate extensions for PDB files
    elif [ "$ext" = "brk" -o "$ext" = "ent" ] ; then 
        cp $pdb $nam/
    else
        errexit "the file to refine ($pdb) has an unknown extension"
    fi
    
    local CONTACT_MAP_OPTIONS=''
    # Check if the contact matrix exists and prepare it for the refinement
    if [ -s "$cm" ] ; then
        # Prepare CA-rest-file
        # RR 5-column format is AA1 AA2 dist-min(0) dist-max(8) probability
        # CABS format is AA1 AA2 distance weight
        # Use the contact map with minimal distance
        # CABS needs a CM in CRF format, we generate it here from the RR5 file
        cat "$cm"  | cut -f 1,2,3,5 -d " " \
                   | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
                   > "$nam/$nam.0.crf"
        # Use a contact map with maximal distance 
        # this is commented out because it does not give good results
        #cat "$cm"  | cut -f1,2,4,5 -d' ' \
        #           | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
        #           > "$nam/$nam.8.crf"
    fi
    # check if we still have a contact map after conversion
    if [ -s $nam/$nam.0.crf ] ; then
            notecont "Using contact map $nam/$nam.0.crf"
            # using abspath avoid dependencies on current directory
            CONTACT_MAP_OPTIONS="--ca-rest-file "`abspath $nam/$nam.0.crf`
    else
        warncont "contact map not found or unusable, refinement will proceed without it"
    fi
        
    # Now we can carry out the refinement
    if [ -e "${nam}.done" -o -e "${nam}.doing" ] ; then
        notecont "Calculation finished or running according to"
        ls $nam.d* | sed -e 's/^/\t/g'
        notecont "If you want to force a new calculation, please"
        notecont "remove this file"
        return $OK
    else
        rm -f ${nam}.fail
        date -u > ${nam}.doing
        # XXX consider removing this 'if' later so the refinement is repeated
        # XXX or continued
        if [ ! -s ${nam}/output_pdbs/model_0.pdb ] ; then
            notecont "running CABSflex on $pdb, saving on $nam"
            # print the command used for the refinement in the shell
            notecont "command:" \
            CABSflex        ${comment# use CABSflex -h for help} \
                 -i ${pdb} \
    	         -w ${nam}  ${comment# work directory} \
                 -v 3       ${comment# verbose level (log)} \
                 -A 	    ${comment# make all atom models} \
                 -M 	    ${comment# make contact map} \
                 -f 1	    ${comment# 0 fully flexible backbone / 1 stiff bb)}  \
                 -a 40	    ${comment# mc-annealing cycles (def: 20)} \
                 -y 100	    ${comment# mc-cycles (def: 50)} \
                            ${comment# the trajectory will have} \
                            ${comment# 40x100=4000 frames} \
                 -t 3.5 1.0 ${comment# temperature start end (def: 1.4 1.4)} \
                 --weighted-fit 'gauss' \
                 -S 	    ${comment# save CABS files}\
                 ${comment# -L YYMMDDhhmmssfile.cls (load CABS file)} \
                 -C 	    ${comment# save config} \
                 $CONTACT_MAP_OPTIONS 
            # run CABSflex
            CABSflex        ${comment# use CABSflex -h for help} \
                 -i ${pdb} \
    	         -w ${nam}  ${comment# work directory} \
                 -v 3       ${comment# verbose level (log)} \
                 -A 	    ${comment# make all atom models} \
                 -M 	    ${comment# make contact map} \
                 -f 1	    ${comment# 0 fully flexible backbone / 1 stiff bb)}  \
                 -a 40	    ${comment# mc-annealing cycles (def: 20)} \
                 -y 100	    ${comment# mc-cycles (def: 50)} \
                            ${comment# the trajectory will have} \
                            ${comment# 40x100=4000 frames} \
                 -t 3.5 1.0 ${comment# temperature start end (def: 1.4 1.4)} \
                 --weighted-fit 'gauss' \
                 -S 	    ${comment# save CABS files}\
                 ${comment# -L YYMMDDhhmmssfile.cls (load CABS file)} \
                 -C 	    ${comment# save config} \
                 $CONTACT_MAP_OPTIONS \
                 |& tee ${nam}/${nam}.log 
        else
            notecont "Output model(s) already exit. NOT REPEATING CALCULATION"
        fi

        date -u >> ${nam}.doing
        # check if any model was produced
        if [ ! -s ${nam}/output_pdbs/model_0.pdb ] ; then
	    # if there is no model, then something went wrong, record it
            mv ${nam}.doing "${nam}.fail"
            echo "CABSflex $nam" >> FAIL
            return $ERROR			# NO NEED TO CONTINUE
        else
            # APOLLO will generate its results in a directory
            # named after the name of the sequence.
            # Generate the sequence from the original structure with OpenBabel
            #$babel -ipdb $pdb -ofasta $nam/$nam.fasta
            cp $sequence $nam/$nam.fasta
            cd $nam
              mkdir -p models
              if [ ! -s ${nam}.apollo/models.avg ] ; then
                  cp output_pdbs/model*.pdb models
                  # run apollo
                  $MYHOME/lib/apollo.bash $nam.fasta models |& tee ${nam}.apollo.log
              fi
              # check if we succeeded
              if [ ! -s ${nam}.apollo/models.avg ] ; then
                  warncont "apollo failed for $nam"
                  warncont "--------------------"
                  ls -1 `abspath models` | sed -e 's/^/	/g'
                  warncont "--------------------"
                  ls -1 `abspath ${nam}.apollo` | sed -e 's/^/	/g'
                  warncont "--------------------"
              fi
            cd ..

            date -u >> ${nam}.doing
        fi 		# [ -s ${nam}/output_pdbs/model_0.pdb ] 

	# We have hopefully completed the refinement
	# Extract the best model found (according to apollo or, if not, to CABS)
        if [ -e ${nam}/${nam}.apollo/models.avg ] ; then
            notecont ">>> ${nam} SCORED USING APOLLO"
            # if there is a score file, pick the model with best average score
            # get first line starting from line 5 (just after the header)
            best_model=${nam}/models/`cat ${nam}/${nam}.apollo/models.avg | tail -n+5 | head -n1 | cut -d " " -f 1`
        else
            notecont ">>> $nam SCORED USING CABS"
            best_model=${nam}/models/model_0.pdb
        fi
        notecont ">>>THE BEST MODEL FOR $nam IS $best_model (IS IT 'model_0.pdb'?)"
        # Check if the model exists and isn't empty
        if [ -s "$best_model" ] ; then
            cp ${best_model} ${nam}+.pdb
	else
	    # if there is no model, then something went wrong, record it
            mv ${nam}.doing "${nam}.fail"
            echo "CABSflex $nam" >> FAIL
            errexit ">>> THERE WAS AN ERROR GETTING OUT THE BEST MODEL"
        fi

        mv ${nam}.doing "${nam}.done"
        
    fi		# [ ! -e "${nam}.done" -o ! -s "${name}.doing" ]
    # at this point we should have a first stage refinement result ready
    # for the second stage refinement, so we can go on to the second step

    return $OK
}


function cabs_cm_00() {
    notecont "$*" 

    # get arguments
    local sequence=${1:-sequence.fasta}
    local cm=${2:-contactmap.rr5}
    local pdb=${3:-starting_structures}

    local usage_mgs="[sequence.fas] [contactmap.rr5] [starting_sutructure(s)]"
    local workdir=cabs
    local MAXJOBS=`nproc`
    MAXJOBS=$(( MAXJOBS / 3 ))
    #MAXJOBS=0
    export PATH=~/.local/bin:$PATH
    
    # Create the working directory
    mkdir -p workdir
    # Check if the sequence file exists and isn't empty
    if [ ! -s "$sequence" ] ; then errexit $usage_msg ; fi
    # Check if the contact matrix exists and isn't empty
    if [ -s dncon2/$cm ] ; then
        cp dncon2/$cm $workdir
    else
        warncont "called with no contact matrix, let's hope it is already available"
    fi
    # Check if the $pdb varaible exists and isn't empty and whether is a file or a directory
    if [ "$pdb" != "" -a -d $pdb ] ; then 
        # if it is a directory, copy all pdb file/cabs to workdir (cabs)
        cp $pdb/*pdb $workdir
    elif [ -s $pdb ] ; then
        # if it is a file, assume it is a PDB file to refine and copy it too
        cp $pdb $workdir
    else
        # if neither a directory nor a non-empty file, then just issue a
        # warning (we might have been called to continue an interrupted
        # previous run
        warncont "called with no PDB files to model"
    fi
    
    cd $workdir
    # call CABS_refine for each PDB file
    njobs=0
    for i in *.pdb ; do 
        #
        # we'll run a two-step refinement process, where the original file is
        # ORIG.pdb, the best result of the first refinement ORIG+.pdb and that of
        # the second refinement ORIG++.pdb
        #
        # Accordingly:
        #   
        # First we check if the file is the final result of a previous calculation
        if [[ "$i" == *"++.pdb" ]] ; then 
            # we are already done
            notecont ">>> skipping $i" 
            continue
        fi
        if [ $njobs -gt $MAXJOBS ] ; then
            wait -n		# wait for *one* slot to be free
            njobs=$((njobs - 1))
        fi
        notecont "JOBS RUNNING = $njobs"
        if [[ "$i" == *"+.pdb" ]] ; then
            notecont "Refining $i (pass 2)"
            # it is a pre-refined structure in need of the second refinement
            # spawn a job
            (
                CABS_refine $i $cm
            ) &
        else 
	    notecont "Refining $i (pass 1 and 2)"
           # it is an unrefined structure in need of both refinement steps
           # spawn a job
           (
               CABS_refine $i $cm
               nam=`basename $i .gz`
               nam=`basename $nam .pdb`
               if [ -e ${nam}+.pdb ] ; then
                   # the first refinement succeeded, proceed to the second
                   CABS_refine ${nam}+.pdb $cm
               fi
           )&
        fi
        njobs=$((njobs + 1))
    done
    
    wait	# wait for all remaining jobs to complete

    if [ ! -e FAIL ] ; then
        touch DONE
    fi
    cd ..
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

    VERBOSE=1
    command=`basename $0 .bash`
    $command $*
else
    export CABS='CABS'
fi
