#!/bin/bash
#
#	A protocol for ab-initio protein structure prediction.
#
sequence=$1

sequence=`realpath $sequence`
name=${sequence%.*}
name=${name##*/}


maxmodels=5

myname=`basename "${BASH_SOURCE[0]}"`
mydir=`dirname "${BASH_SOURCE[0]}"`
MYHOME=`realpath $mydir`
myhome=~/work/amelones/script
myhome=`dirname $0`
myhome=`realpath $myhome`

# Utilities
export FUNCS_BASE=$myhome/lib
source $FUNCS_BASE/fs_funcs.bash
source $FUNCS_BASE/util_funcs.bash
source $FUNCS_BASE/split_fasta.sh
source $FUNCS_BASE/modellerscr.sh

redirect_std_out_err $name/log $myname.$name

VERBOSE=1

######################################################################
#                                                                    #
# First, generate some (hopefully) realistic models                  #
#                                                                    #
######################################################################

# we will use at this step a set of tools that have proven valid in CASP
# i-tasser
#	(ideally we would like to also run Sparks and RaptorX)
# DNCon2
#	with various methods (confold1, confold2 and unicon3d)
# Alphafold2
#
# Multicom
#	(ideally we would include Quark, C-Quark and Rosetta as well)
#
# Phi-Psi-prediction
# Secondary structure prediction
# naïve structures (alpha, beta, coiled-coil, extended, random)


mkdir -p $name		# (should have already been created for the log file)
# save a copy of the sequence
cp $sequence $name
cp $sequence $name/sequence.fasta

split_fasta_seq_to_dir $name/sequence.fasta $name
nchunks=$?
if [ $nchunks -gt 1 ] ; then
    cd $name
    # run this script on each of the subsequences    
    for i in *overlap.fasta ; do
        $0 $i
    done
    # at this point we should have models for each of the overlapping
    # subsequences
    # now we need to run modeller using as templates the models selected
    # for each of the subsequences to get a full model for the whole 
    # protein
    mkdir -p modeller
    cp $sequence modeller/sequence.fasta
    cd modeller
    build_model_from_pieces modeller/sequence.fasta 
    exit
fi


# I-TASSER
# --------
# Try to generate an homology model using I-TASSER inside
# the $name directory
# if the directory does not exist we have not run i-tasser yet
if [ ! -d $name/i-tasser/$name ] ; then
    # if there is not at least one model, try again
    if [ ! -e $name/i-tasser/$name/model1.pdb ] ; then
        cd $name
        # this will save i-tasser-specific output to detailed log files
        eval i-tasser `basename $sequence` $LOG
        cd ..
    fi
fi

# ALPHAFOLD
# ---------
# Try to generate an ab-initio model using alphafold inside
# the $name directory
# If alphafold hasn't been run yet there will be no directory
if [ ! -e $name/alphafold/$name ] ; then
    if [ -x ~/contrib/alphafold/bin/alphafold ] ; then
        cd $name
        # this will save alphafold-specific output to detailed log files
	eval ~/contrib/alphafold/bin/alphafold $sequence $LOG
        cd ..
    else
	echo "Not using AlphaFold2 because it is not installed"
        #exit 1
    fi
fi


# DNCON2
# ------
# dncon2 will create a directory named $name/dncon2 to save its output
# that's why we start it from above $name (no need to enter into it)
if [ ! -d ./$name/dncon2/confold2-$name.dncon2/top-models ] ; then
    echo "Running DNCON2"
    # this will save all the results in "./dncon2/"
    eval $myhome/dncon2.sh $sequence CONFOLD2 $LOG
    #$myhome/dncon2.sh $sequence CONFOLD1	# we considered doing these too
    #$myhome/dncon2.sh $sequence UNICON3D	# but they were worse
fi

# the resulting models will be in ./dncon2/confold2-$name.dncon2/top-models
# there may be a large amount of models (100+)
# we will use a quick score function
# first we check if confold2 was run
if [ -d $name/dncon2/confold2-$name.dncon2/ ] ; then
    # remember current position for later and 'cd' to the confold2 directory
    pushd $name/dncon2/confold2-$name.dncon2/		# google this for info
    
    # check if apollo has already been run
    if [ ! -s $name.apollo/top-models.avg ] ; then
	echo "Running apollo on CONFOLD2 top-models"
	eval $myhome/apollo.sh $sequence top-models $LOG
    fi

    # check if apollo run successfully
    if [ ! -e $name.apollo/top-models.avg ] ; then
       echo "ERROR: HORROR: I cannot find apollo scores for any DNCON2+CONFOLD2 model"
       exit 1
    fi

    # let us select the best $maxmodels models produced by CONFOLD2 and 
    # store them named by score order
    if [ ! -e ../models/1.*.pdb ] ; then
	echo "Selecting $maxmodels best CONFOLD2 models"
	mkdir -p ../models
	order=0
	cat $name.apollo/top-models.avg \
	| tail -n+5 \
	| head -n$maxmodels \
	| while read model score ; do
            order=$(( order + 1 ))
            #cp top-models/$model ../models/$order.confold2.$model
	    cp top-models/$model ../models/$order.$model
	done
    fi
    # recover our last saved position and return to it
    popd	# return to where we came from (above $name)
fi



######################################################################
#                                                                    #
# Prepare everything for CABS                                        #
#                                                                    #
######################################################################

# we will work inside $name to keep everything contained in a single directory
pushd $name
if [ ! -d cabs ] ; then 
    mkdir cabs
fi

# add the sequence if not already there
if [ ! -s cabs/`basename $sequence` ] ; then
    cp $sequence cabs
fi

# check if there are any models generated by I-TASSER and copy up to
# $maxmodels to the cabs folder for further refinement
#for i in ((i=1;i<=maxmodels;i++)) ; do
if [ ! -s cabs/1.i-tasser-model1.pdb ] ; then
    echo "Selecting $maxmodels best I-TASSER models"
    END=$maxmodels
    for ((i=1;i<=END;i++)); do
        if [ -s i-tasser/$name/model$i.pdb ] ; then
            # we cannot just copy because i-tasser does not define chain-IDs
	    #cp i-tasser/$name/model$i.pdb cabs/$i.i-tasser-model$i.pdb
            # add chain-ID to models and save them in cabs directory
            cat i-tasser/$name/model$i.pdb \
            | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
            > cabs/$i.i-tasser-model$i.pdb
        fi
    done
fi

# check if alphafold generated any models and copy them to the cabs folder
if [ -s alphafold/$name/ranked_1.pdb ] ; then
    # ranked are relaxed models renumbered by quality
    # so their numbers may not match
    for i in 0 1 2 3 4 ; do
        f=alphafold/$name/ranked_$i.pdb
        cp $f cabs/`echo $f | sed -e 's/relaxed_model/alphafold/g'`
    done
else
    # unrelaxed are as output by alphafold
    # relaxed are the unrelaxed after AMBER optimization
    # so, we prefer first relaxed and if there is none, unrelaxed
    for i in 1 2 3 4 5 ; do
        fr=alphafold/$name/relaxed_model_$i.pdb
        fu=alphafold/$name/unrelaxed_model_$i.pdb
        if [ -s $fr ] ; then
            cp $fr cabs/alphafold_opt_$i.pdb
        elif [ -s $fu ] ; then
            cp $fu cabs/alphafold_raw_$i.pdb
        fi
    done
fi

# check if dncon2 generated a contact matrix and, if so, use it with CABS
if [ -s dncon2/$name.rr.raw ] ; then
    cm=$name.rr.raw
    cp dncon2/$cm cabs
else
    echo "ERROR: DNCON2 did not create a Contact Matrix $name.rr.raw"
    #exit 1   #comment this line in case you detect scarce alignments 
    #during the execution of dncon2 for your protein
fi

# check if CONFOLD2 could generate any models and add them for CABS refinement
if [ -d dncon2/models ] ; then
    # the directory exists, so dncon2 did not fail to generate it
    # but it might be empty, let's check if it contains any models
#    if [ "$( ls -A dncon2/models )" ] ; then
#        # yes, copy the models to folder cabs for CABS to use as templates
#	 # NOTE: this will fail because these models lack chain-ID (see below)
#	 cp -v dncon2/models/*.pdb cabs
#    fi
    # this is an alternative approach that gives us more freedom
    for i in `ls -A dncon2/models/*` ; do
        #echo $i
        # add chain-ID to models and save them in cabs directory so that
        # CABS will find them and refine them
        cat $i \
        | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
        > cabs/`basename $i`
    done
fi



######################################################################
#                                                                    #
# Now do a structure refinement using CABS                           #
#                                                                    #
######################################################################


cd cabs
eval $myhome/cabscm00.03.sh `basename $sequence` $cm $LOG

cd ..

# we are done with CABS, go back to where we came from (above $name)
popd

exit
# This should probably be in the CABS script
#cp */solution-top/*pdb models_unscored
#cp [1-5].*.pdb models_unscored


######################################################################
#                                                                    #
# Now do a structure refinement using UNRES                          #
#                                                                    #
######################################################################



######################################################################
#                                                                    #
# Now do a structure refinement using Rosetta                        #
#                                                                    #
######################################################################



######################################################################
#                                                                    #
# Now do a structure refinement using MARTINI                        #
#                                                                    #
######################################################################



######################################################################
#                                                                    #
# Now do a structure refinement using an atomistic force field       #
#                                                                    #
######################################################################


