sequence=$1
# modelfolder is the folder wich contains the models we are going to score. 
modelfolder="$2"

# this may happen if $2 is not given or empty
if [ "$modelfolder" = "" ] ; then exit ; fi

name=${sequence%.*}
name=${name##*/}

mkdir -p "$modelfolder"	# IT SHOULD ALREADY EXIST AND CONTAIN MODELS!!!

ls -1 ${modelfolder}/* > ${name}.mlist	# mlist is the model list
mkdir -p ${name}.apollo

if [ -x ~/contrib/multicom_toolbox/apollo_pairwise.64bit/pairwise_qa_apollo ] ; then
    apollo=~/contrib/multicom_toolbox/apollo_pairwise.64bit/pairwise_qa_apollo
fi

$apollo \
    ${name}.mlist \
    ${sequence} \
    ~/contrib/multicom_toolbox/apollo_pairwise.64bit/tm_score/TMscore_64 \
    ${name}.apollo \
    ${modelfolder}


