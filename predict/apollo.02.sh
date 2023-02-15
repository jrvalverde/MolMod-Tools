sequence=$1
modelfolder=$2

name=${sequence%.*}

mkdir -p $modelfolder

ls -1 ${modelfolder}/* > ${name}.mlist	# mlist is the model list
mkdir -p ${name}.apollo

~/contrib/multicom_toolbox/apollo_pairwise.64bit/pairwise_qa_apollo \
    ${name}.mlist \
    ${sequence} \
    ~/contrib/multicom_toolbox/apollo_pairwise.64bit/tm_score/TMscore_64 \
    ${name}.apollo \
    ${modelfolder}

cd ..
