#!/bin/bash

# get arguments
sequence=${1:-sequence.fasta}
cm=${2:-contactmap.rr5}

# SETUP base variables
export myname=`basename "${BASH_SOURCE[0]}"`
export mydir=`dirname "${BASH_SOURCE[0]}"`
export MYHOME=`realpath $mydir`

MAXJOBS=`nproc`
MAXJOBS=$(( MAXJOBS / 3 ))
#MAXJOBS=8

comment=''
# this allows inline comments of the form
${comment# whatever (even multiline)}
# while this
unset comment
# will allow inline comments of the form
${comment# whatever}
${comment+ whatever
	   (and even multiline comments) }


# NOTE: of the directory we are in already contains any PDB file, it will
# be refined too. This allows for the caller to "inject" additional models
# to try.
#

function generate_3D_templates()
{
    # this ensures that $sequence has a value (if none was given, then
    # it will be "sequence.fasta" by default
    sequence=${1:-sequence.fasta}
    
    if [ ! -s "$sequence" ] ; then
        echo "ERROR: sequence $sequence does not exist"
        # without a sequence we cannot make any templates
        return
    fi
    # Generate various starting configurations
    # ----------------------------------------
    #
    # NOTE: we do not know which one may work better, it will depend on the actual
    # structure of the target and its predominant features.
    #
    # NOTE: of the directory we are in already contains any PDB file, it will
    # be refined too. This allows for the caller to "inject" additional models
    # to try.
    #
    # We could have a starting model as a parameter, but this way we ensure that
    # we always generate a minimum set of trial models.
    #
    # PepBuild.py is an auxiliary script in Python than generates structures
    # using package PeptideBuilder
    #
    pepbuild=${MYHOME}/PepBuild.py
    anglor=${HOME}/contrib/anglor/ANGLOR/anglor.pl

    if [ ! -e helix.pdb ] ; then
        python3 $pepbuild -i $sequence \
	    -o helix.pdb -a
    fi

    if [ ! -e sheet.pdb ] ; then
        python3 $pepbuild -i $sequence \
	    -o sheet.pdb -b
    fi

    if [ ! -e coil.pdb ] ; then
        python3 $pepbuild -i $sequence \
	    -o coil.pdb -c
    fi

    if [ ! -e extended.pdb ] ; then
        python3 $pepbuild -i $sequence \
	    -o extended.pdb -e
    fi

    # for the next ones we need a secondary structure prediction and a
    # phi-psi angle prediction. We'll get both using our slightly modified
    # ANGLOR which first runs psipred (to get secondary structure predictions
    # and put them in fasta format) and then ANN and SVM to get phi-psi
    # angle predictions
    if [ ! -d anglor ] ; then
        $anglor $sequence
    fi

    if [ ! -e ss.pdb ] ; then
        # check if anglor generated a secondary structure fasta file
        if [ -e anglor/seq.ss ] ; then
            echo "Creating model based on Secondary Structure from ANGLOR"
            python3 $pepbuild -i $sequence \
	        -o ss.pdb -s anglor/seq.ss
        fi
    fi

    if [ ! -e pp.pdb ] ; then
        if [ -e anglor/seq.ann.phi -a -e anglor/seq.svr.psi ] ; then
            echo "Creating model based on Phi/Psi angles from ANGLOR"
            python3 $pepbuild -i $sequence \
	        -o pp.pdb -P anglor/seq.ann.phi -S anglor/seq.svr.psi
        fi
    fi

    # Additionally, we might try to use other auxiliary programs to get
    # better starting structures.
    # Or, alternatively, copy them into the current directory before
    # calling this script. Then this script will find them and process
    # them as well.
}

function fix_3D_templates() {
    # XXX JR XXX THIS IS AN UGLY HACK PENDING CORRECT REWRITING
    # THIS IS BECAUSE IN SOME CASES, PepBuilder results in negative coordinates
    # larger than -1000.000. This shifts all the coordinates one space right
    # and breaks the PDB format, leading to a failure of CABS.
    # Chimera can read the pdb file and "fix" the coordinates so we just
    # read the file and save it again. This does not actually FIX the file,
    # but distorts the X and Y coordinates so they fit in the box.
    # Thus, it results in a distorted starting structure, but we do not
    # care because any way, we will model it extensively with CABS.
    for i in helix sheet coil extended ss pp ; do
        cp $i.pdb $i.pdb.orig
        DISPLAY='' chimera --nogui <<END
            open $i.pdb
            write format pdb 0 $i.pdb
END
    done
}

if [ ! -e "$sequence" ] ; then
    echo "ERROR: sequence $sequence does not exist"
    echo "Usage: cabscm sequence.fasta contactmap.rr5"
    exit 1
fi
if [ ! -e "$cm" ] ; then
    echo "WARNING: contact map $cm does not exist"
    echo "Usage: cabscm sequence.fasta contactmap.rr5"
    echo "SWITCHING TO *NOT* USING A CONTACT MAP"
    USE_CM="NO"
else
    USE_CM="YES"
fi




generate_3D_templates $sequence

fix_3D_templates

# if $sequence does not exist, then we will not generate any templates
# and only pre-existing templates will be used, this is ugly, we should
# think this out

# process each starting configuration in turn using two steps


function run_CABS() {

    # This is a function to refine all the pdb files using the CABS algorithm
    # and predict their protein structure. It has only one argument
    # that will be called Contact_mat. This varaible can take two different values.
    # They will depend on wether after running DNCON2 a contact matrix for our protein
    # was obtained or not. Then this variable will be used to adjust the parameters
    # of the simulation and run the algorithm. 

njobs=0     	
Contact_mat=$1

if [[ $# -ne 1 ]] ; then
    echo "ERROR: function run_CABS requires only one argument"
fi
for i in *.pdb ; do
    if [[ "$i" == *"+.pdb" ]] ; then echo ">>> skipping $i" ; continue ; fi
    echo ">>> Refining $i"
    
    if [ $njobs -gt $MAXJOBS ] ; then
        wait -n		# wait for one slot to be free
        njobs=$((njobs - 1))
    fi

    (
        
        name=`basename $i .pdb`
        
        if [ $Contact_mat == "YES" ] ; then
            # Prepare CA-rest-file
            # RR 5-column format is AA1 AA2 dist-min(0) dist-max(8) probability
            # CABS format is AA1 AA2 distance weight
            # Use with minimal distance
            cat "$cm"  | cut -f1,2,3,5 -d' ' \
                       | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
                       > "$name.0.crf"
            # Use with maximal distance 
            # this is commented out because it does not give good results
            #cat "$cm"  | cut -f1,2,4,5 -d' ' \
            #           | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
            #           > "$name.8.crf"
            CONTACT_MAP_OPTIONS='--ca-rest-file "$name.0.crf"'
        else
            CONTACT_MAP_OPTIONS=''
        fi 
        
        # carry out first simulation step
        if [ ! -e "${name}.done" -o ! -s "${name}.doing" ] ; then
            rm -f ${name}.fail
            date -u > ${name}.doing
            # XXX remove this 'if' later
            if [ ! -e ${name}/output_pdbs/model_0.pdb ] ; then
            CABSflex 	${comment# use CABSflex -h for help} \
                     -i ${name}.pdb \
    	             -w ${name} \
                     -v 3   ${comment# verbose level (log)} \
                     -A 	${comment# make all atom models} \
                     -M 	${comment# make contact map} \
                     -f 1	${comment# 0 fully flexible backbone / 1 stiff bb)}  \
                     -a 40	${comment# mc-annealing (def: 20)} \
                     -y 100	${comment# mc-cycles (def: 50)} \
                            ${comment# the trajectory will have 40x100=4000 frames} \
                     -t 3.5 1.0 ${comment# temperature start end (def: 1.4 1.4)} \
                     --weighted-fit gauss \
                     -S 	${comment# save CABS files}\
                     -C 	${comment# save config} \
                     $CONTACT_MAP_OPTIONS \
                     ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
                     |& tee ${name}.log 
            fi
            date -u >> ${name}.doing
            if [ ! -s ${name}/output_pdbs/model_0.pdb ] ; then
                mv ${name}.doing "${name}.fail"
                echo "CABSflex $name" >> FAIL
            else
                # IMPORTANT: APOLLO will generate its results in a directory
                # named after the name of the sequence. Since the model we
                # are analyzing has a different (standardized) name, we want 
                # to use it (the model name) instead of the original name of 
                # the query sequence. After all, the mmodel we are analyzing
                # corresponds to the original sequence.
                cp $sequence $name/$name.fasta
                cd $name
                mkdir -p models
                if [ ! -s ${name}.apollo/models.avg ] ; then
                    cp output_pdbs/model*.pdb models
                    $MYHOME/apollo.sh $name.fasta models |& tee ${name}.apollo.log
                fi
                if [ ! -s ${name}.apollo/models.avg ] ; then
                    echo ">>>>>>>> [${name}]"
                    pwd
                    echo "--------"
                    ls
                    echo "--------"
                    ls -l ${name}.apollo
                    echo "--------"
                    echo ">>>> WARNING: apollo failed for $name"
                fi
                cd ..
                mv ${name}.doing "${name}.done"
            fi

        fi

        # carry out a second simulation step using the best first model 
        # produced in the previous step.
        if [ ! -e "${name}+.done" ] ; then
            if [ -e ${name}.apollo/models.avg ] ; then
                echo ">>> $name SCORED USING APOLLO"
                # if scoring went OK, pick the model with best average score
                best_model=`cat ${name}/${name}.apollo/models.avg | tail -n+5 | head -n1`
            else
                # pick first model if one exists
                best_model=${name}/models/model_0.pdb
            fi
            echo ">>>THE BEST MODEL FOR $name IS $best_model (IS IT 'model_0.pdb'???)"
            # We might consider doing both if they exist, the one
            # with best average Apollo score and the first one
            ### JR ### THINK ABOUT THIS
            
	    if [ -e "$best_model" ] ; then
                cp ${name}/output_pdbs/model_0.pdb ${name}+.pdb
                #cp $best_model ${name}+.pdb
                rm -f ${name}+.fail
                date -u > ${name}+.doing
                CABSflex -i ${name}+.pdb \
    	                 -w ${name}+ \
                         -v 3 \
                         -A 	${comment# make all atom models} \
                         -M 	${comment# make contact map} \
                         -f 1	${comment# 0 fully flexible backbone / 1 stiff bb)}  \
                         -a 40	${comment# mc-annealing (def: 20)} \
                         -y 100	${comment# mc-cycles (def: 50)} \
                         -t 3.5 1.0 ${comment# temperature initial final (def: 1.4 1.4)}\
                         --weighted-fit gauss \
                         -S 	${comment# save CABS files}\
                         -C 	${comment# save config} \
                         --ca-rest-file "$name.0.crf" \
                         ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
                         |& tee ${name}+.log 
                date -u >> ${name}+.doing
            else
                echo "WARNING: ${best_model} does not exists"
            fi
            if [ ! -s ${name}+/output_pdbs/model_0.pdb ] ; then
                mv ${name}+.doing "${name}+.fail"
                echo "CABSflex $name" >> FAIL
            else
                cp $sequence ${name}+/${name}+.fasta
                cd ${name}+
                mkdir -p models
                if [ ! -s ${name}+.apollo/models.avg ] ; then
                    cp output_pdbs/model*.pdb models
                    $MYHOME/apollo.sh ${name}+.fasta models |& tee ${name}+.apollo.log
                fi
                if [ ! -s ${name}+.apollo/models.avg ] ; then
                    echo ">>>>>>>> [${name}+]"
                    pwd
                    echo "--------"
                    ls
                    echo "--------"
                    ls -l ${name}+.apollo
                    echo "--------"
                    echo ">>>> WARNING: apollo failed for ${name}+"
                fi
                cd ..
                mv ${name}+.doing "${name}+.done"
            fi
        fi

    ) &

    njobs=$((njobs + 1))
    
done

}
run_CABS $USE_CM

wait

if [ ! -e FAIL ] ; then
    touch DONE
fi
