#!/bin/bash
#
#	A protocol for ab-initio protein structure prediction.
#
input_sequence=$1

VERBOSE=1

input_sequence=`realpath $input_sequence`	# use full path name to avoid trouble
sequence=`basename $input_sequence`
name=${sequence%.*}		# remove suffix (.fasta/.fas/.faa/...)
name=${name##*/}		# remove pathname (leave only sequence name)

maxmodels=5			# Maximum number of models to carry forward

myname=`basename "${BASH_SOURCE[0]}"`	# identify out source directory
MYNAME=`realpath "$myname"`
mydir=`dirname "${BASH_SOURCE[0]}"`
MYHOME=`realpath "$mydir"`
#myhome=~/work/amelones/script
myhome=`dirname "$0"`
myhome=`realpath "$myhome"`	# should be the same as $MYHOME

# Load utility functions
export FUNCS_BASE="$myhome"/lib
source "$FUNCS_BASE"/fs_funcs.bash
source "$FUNCS_BASE"/util_funcs.bash
source "$FUNCS_BASE"/split_fasta.bash       # defines split_fasta_seq_to_dir()
source "$FUNCS_BASE"/i-tasser.bash          # defines i-tasser()
source "$FUNCS_BASE"/alphafold.bash         # defines alphafold()
source "$FUNCS_BASE"/dncon2.bash            # defines dncon2()
source "$FUNCS_BASE"/apollo.bash            # defines apollo()
source "$FUNCS_BASE"/pepbuild.bash          # defines pepbuild()
source "$FUNCS_BASE"/cabs_cm_00.bash        # defines cabs_cm_00()
source "$FUNCS_BASE"/fix_3D_templates.bash  # defines fix_3D_templates()
source "$FUNCS_BASE"/martini.bash           # defines martini()
#declare -F			       # list all known functions for debugging
#declare -F | awk '{print $NF}' | sort | egrep -v "^_" 

if [ -x "$FUNCS_BASE"/modellerscr.sh ] ; then
    source "$FUNCS_BASE"/modellerscr.sh
fi                                     # defines modellerscr() 

if [ "$name" = "" ] ; then
    errexit "$input_sequence results in an empty sequence name"
fi

# we will save all output in a directory named after the sequence
out="$name"

# create initial output folders
mkdir -p "$out"
mkdir -p "$out"/starting_models
mkdir -p "$out/log"

# send all output to a log file inside the output folder
redirect_std_out_err "$out/log" "$myname"."$out"

# save a copy of the sequence in the output folder
cp "$input_sequence" "$out"

# if the sequence is too large, split it into pieces
if [ "YES" = "NO" ] ; then
    split_fasta_seq_to_dir $out/$sequence $out
    nchunks=$?
    if [ $nchunks -gt 1 ] ; then
        # if we got several overlapping pieces, process each separately
        cd $out
        # run this script ($0) on each of the subsequences    
        for i in *overlap.fasta ; do
            $0 $i
        done
        # at this point we should have models for each of the overlapping
        # subsequences
        # now we need to run modeller using as templates the models selected
        # for each of the subsequences to get a full model for the whole 
        # protein
        # Create the directory where modeller will be run
        mkdir -p modeller
        # Copy the protein sequence in that folder
        cp $sequence modeller/sequence.fasta
        for i in *.overlap.fasta ; do	# copy templates to modeller folder
            piece_out=`basename $i .fasta`
            cp $piece_out/model/model1.pdb modeller/
        done
        cd modeller
    #    modellerscr modeller/sequence.fasta 
        exit
    fi
fi

######################################################################
#                                                                    #
# First, generate some (hopefully) realistic/useful models           #
#                                                                    #
######################################################################

# we will use at this step a set of tools that have proven valid in CASP
# i-tasser
#	(ideally we would like to also run Sparks and RaptorX)
# DNCon2
#	only with CONFOLD2 as it works better than CONFOLD1 and UNICON3D
# Alphafold2
#
# Multicom
#	(ideally we would include Quark, C-Quark and Rosetta as well)
# PepBuild
#	To ensure we at least have some naïve initial models to refine
# 	Phi-Psi-prediction
# 	Secondary structure prediction
# 	naïve structures (alpha, beta, coiled-coil, extended, random)
#

# I-TASSER
# --------
# Try to generate an homology model using I-TASSER inside
# the $out directory
# if the directory does not exist we have not run i-tasser yet
    # if there is not at least one model, try again
if [ ! -e "$out/i-tasser/$out/model1.pdb" ] ; then
    cd $out
    eval i-tasser $sequence $LOG
    cd ..
else
    notecont "Using already existing I-TASSER predictions"
fi
# try to copy models to the starting models folder
if [ ! -s $out/starting_models/i-tasser-model_1.pdb ] ; then
    # I-TASSER has already ranked the models
    for ((i=1;i<=$maxmodels;i++)); do
        if [ -s $out/i-tasser/$out/model$i.pdb ] ; then
            #cp $out/i-tasser/$out/model$i.pdb   $out/starting_models/i-tasser-model_$i.pdb
            # add chain ID
            cat $out/i-tasser/$out/model$i.pdb \
            | sed -e '/^ATOM  / s/^\(.\{21\}\) /\1A/' \
            > $out/starting_models/i-tasser-model_$i.pdb
        fi
    done
fi


# ALPHAFOLD
# ---------
# Try to generate an ab-initio model using alphafold inside
# the $out directory
# If alphafold hasn't been run yet there will be no directory
if [ ! -e $out/alphafold/$out ] ; then
    if [ -x ~/contrib/alphafold/bin/alphafold ] ; then
        cd $out
	eval alphafold $sequence $LOG
        cd ..
    else
	warncont "Not using AlphaFold2 because it is not installed"
        #exit 1
    fi
else
    notecont "Using already existing AlphaFold2 predictions"
fi

# copy resulting models (AlphaFold produces up to three sets of varying quality)
# We prefer the ranked, optimized models whenever possible
if [ ! -s $out/starting_models/$out/af_model_1.pdb ] ; then
    for ((i=0;i<$maxmodels;i++)); do
        if [ -s $out/alphafold/$out/ranked_$i.pdb ] ; then
            # add chain ID
            cat $out/alphafold/$out/ranked_$i.pdb   \
            | sed -e '/^ATOM  / s/^\(.\{21\}\) /\1A/' \
            >  $out/starting_models/af_model_$((i + 1)).pdb
        fi
    done
fi
# try again: maybe the models could not be ranked by alphafold but could be optimized
if [ ! -s $out/starting_models/$out/af_model_1.pdb ] ; then
    for ((i=1;i<=$maxmodels;i++)); do
        if [ -s $out/alphafold/$out/relaxed_model_$i.pdb ] ; then
            cat $out/alphafold/$out/relaxed_model_$i.pdb   \
            | sed -e '/^ATOM  / s/^\(.\{21\}\) /\1A/' \
            >  $out/starting_models/af_model_$i.pdb
        fi
    done
fi
# try again: maybe they could not be optimized but some were still generated
# (we do not care because we will optimize them anyway)
if [ ! -s $out/starting_models/$out/af_model_1.pdb ] ; then
    for ((i=1;i<=$maxmodels;i++)); do
        if [ -s $out/alphafold/$out/unrelaxed_model_$i.pdb ] ; then
            cat $out/alphafold/$out/unrelaxed_model_$i.pdb   \
            | sed -e '/^ATOM  / s/^\(.\{21\}\) /\1A/' \
            >  $out/starting_models/af_model_$i.pdb
        fi
    done
fi


# DNCON2
# ------
# dncon2 will create a directory named $out/dncon2 to save its output
# that's why we start it from above $out (no need to enter into it)
if [ ! -e $out/dncon2 ] ; then
    notecont "Running DNCON2"
    cd $out
    eval dncon2 $sequence $LOG
    #dncon2 $sequence CONFOLD2	     # works best, and is now the default
    #dncon2 $sequence CONFOLD1       # we considered doing these too
    #dncon2 $sequence UNICON3D       # but they were worse
    cd ..
else
    notecont "Using already existing DNCON2 predictions"
fi

# the resulting models will be in $out/dncon2/$out
if [ ! -s $out/starting_models/1.dncon2.*.pdb ] ; then
    # dncon2 has already ranked the models
    for ((i=1;i<=$maxmodels;i++)); do
        if [ -s $out/dncon2/$out/$i.dncon2.*.pdb ] ; then
            # add chain ID
            cat $out/dncon2/$out/$i.dncon2.*.pdb \
            | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
            > $out/starting_models/`basename $out/dncon2/$out/$i.dncon2.*.pdb`
        fi
    done
fi

cd $out
    for i in starting_models/*dncon2*.pdb ; do
        cp $i $i.orig
            if grep -q 'ATOM.................AA' $i.orig ; then
                cat $i.orig \
                | sed -e 's/ AA\([ 0-9]\)/ A \1/' \
                >  $i
            fi
    done
cd ..

# basic models built with PepBuild
if isempty $out/pepbuild/$out ; then
    cd $out
    eval pepbuild $sequence $LOG
    cd ..
fi
if ! isempty $out/pepbuild/$out ; then
    mkdir -p $out/starting_models
    cp $out/pepbuild/$out/*pdb $out/starting_models/
fi



######################################################################
#                                                                    #
# Prepare everything for CABS                                        #
#                                                                    #
######################################################################

# we will work inside $out to keep everything contained in a single directory
if [ ! -d $out/cabs ] ; then 
    mkdir -p $out/cabs
fi

# add the sequence if not already there
if [ ! -s $out/cabs/`basename $sequence` ] ; then
    cp $sequence $out/cabs/`basename $sequence`
fi


# check if dncon2 generated a contact matrix and, if so, use it with CABS
if [ -s $out/dncon2/$out.rr.raw ] ; then
    cm=$out.rr.raw
else
    warncont "DNCON2 did not create a Contact Matrix $out.rr.raw"
    #exit 1   #comment this line in case you detect scarce alignments 
    #during the execution of dncon2 for your protein
fi

# copy all starting models to the CABS folder
cp $out/starting_models/*pdb $out/cabs/


######################################################################
#                                                                    #
# Now do a structure refinement using CABS                           #
#                                                                    #
######################################################################


cd $out
eval cabs_cm_00 `basename $sequence` $cm $LOG
cd ..

if [ ! -d $out/cabs/models_unscored ] ; then 
    mkdir -p $out/cabs/models_unscored
fi

cd $out
cp cabs/*.pdb cabs/models_unscored
eval apollo $sequence cabs/models_unscored
cd ..
# Copy the best models in the directory based on the apollo scores


# This should probably be in the CABS script
#cp */solution-top/*pdb models_unscored
#cp [1-5].*.pdb models_unscored
#apollo $sequence models_unscored

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
# Prepare everything for MARTINI                                     #
#                                                                    #
######################################################################

# Create a directory inside $out where we will run Martini for the 5 best
# best models obtained from the cabs simulation, scored by apollo 
if [ ! -d $out/martini ] ; then 
    mkdir -p $out/martini
fi

#Check if apollo worked and copy the 5 best models to the martini directory
cd $out
if [ -s cabs/${nam}.apollo/models_unscored.avg ] ; then
    cat cabs/${nam}.apollo/models_unscored.avg \
    | tail -n+5 \
    | head -n5 \
    | while read model score ; do
          if [ -s cabs/models_unscored/$model ] ; then
              cp cabs/models_unscored/$model ./martini
          else
              warncont "$model does not exist or is empty"
          fi
      done
fi
cd ..

# copy the five best models models to the MARTINI folder
#cp $out/best_models/*pdb $out/martini/

######################################################################
#                                                                    #
# Now do a structure refinement using MARTINI                        #
#                                                                    #
######################################################################

cd $out
eval martini $LOG
cd ..


######################################################################
#                                                                    #
# Now do a structure refinement using an atomistic force field       #
#                                                                    #
######################################################################


