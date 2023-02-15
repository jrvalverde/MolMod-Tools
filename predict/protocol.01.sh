#!/bin/bash
#
#	A protocol for ab-initio protein structure prediction.
#
sequence=$1

sequence=`realpath $sequence`
name=${sequence%.*}
name=${name##*/}


maxmodels=5

myhome=~/work/amelones/script

# dncon2 will create a directory named $name/dncon2 to save its output
if [ ! -d ./dncon2/confold2-$name.dncon2/top-models ] ; then
    # this will save all the results in "./dncon2/"
    $myhome/dncon2.sh $sequence CONFOLD2
    #$myhome/dncon2.sh $sequence CONFOLD1
    #$myhome/dncon2.sh $sequence UNICON3D
fi

cd $name/dncon2/
# the resulting models will be in ./dncon2/confold2-$name.dncon2/top-models
# there may be a large amount of models (100+)
# we will use a quick score function
cd ./confold2-$name.dncon2/
if [ ! -d $name.apollo ] ; then
    $myhome/apollo.sh $sequence top-models
fi

if [ ! -e $name.apollo/top-models.avg ] ; then
   echo "ERROR: HORROR: I cannot find apollo scores for any DNCON2+CONFOLD2 model"
   exit 1
fi

# let us select the best $maxmodels models produced by CONFOLD2 and 
# store them named by score order
if [ ! -e ../models/1.*.pdb ] ; then
    mkdir -p ../models
    order=0
    cat $name.apollo/top-models.avg \
    | tail -n+5 \
    | head -n$maxmodels \
    | while read model score ; do
        order=$(( order + 1 ))
        cp top-models/$model ../models/$order.$model
    done
fi
cd ../..	# return to ./$name

# Prepare everything for CABS
if [ ! -d cabs ] ; then 
    mkdir cabs
fi
if [ ! -s cabs/`basename $sequence` ] ; then
    cp $sequence cabs
fi
# check if dncon2 generated a contact matrix and, if so, use it with CABS
if [ -s dncon2/$name.rr.raw ] ; then
    cm=$name.rr.raw
    cp dncon2/$cm cabs
else
    echo "ERROR: DNCON2 did not create a Contact Matrix $name.rr.raw"
    exit 1
fi

# check if dncon2 could generate any models and add them for CABS refinement
if [ -d dncon2/models ] ; then
    # the directory exists, so dncon2 did not fail to generate it
    # but it might be empty, let's check if it contains any models
#    if [ "$( ls -A dncon2/models )" ] ; then
#        # yes, copy the models to folder cabs for CABS to use as templates
#	cp -v dncon2/models/*.pdb cabs
#    fi
    # this is an alternative approach that gives us more freedom
    for i in `ls -A dncon2/models/*` ; do
        echo $i
        # add chain-ID to models and save them in cabs directory for
        # CABS to find them and refine them
        cat $i \
        | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
        > cabs/`basename $i`
    done
fi

cd cabs
$myhome/cabscm00.sh `basename $sequence` $cm
cd ..

exit
# This should probably be in the CABS script
#cp */solution-top/*pdb models_unscored
#cp [1-5].*.pdb models_unscored
