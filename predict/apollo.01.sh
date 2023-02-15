name=$1

mkdir -p models/$name

(
  ls cabs*/${name}/*/output_pdbs/model*.pdb ;\
  ls dncon2/${name}/out/confold1/stage2/*model*.pdb ; \
  ls dncon2/${name}/out/confold2-*${name}*.dncon2/top-models/top-4*.pdb ; \
  ls dncon2/${name}/out/unicon3d_models/*.pdb ; \
  ls i-tasser/${name}/model*.pdb ; \
  ls trRosetta/${name}/model*.pdb \
) | while read mod ; do 
    dest=models/${name}/`echo $mod | tr '/' '-'`
    #echo cp $mod $dest
    if [ ! -e $dest ] ; then
        cp $mod $dest
    fi
done

cd models
cp ../seq/${name}.fasta .
ls -1 ${name}/* > ${name}.mlist
mkdir -p ${name}.apollo

~/contrib/multicom_toolbox/apollo_pairwise.64bit/pairwise_qa_apollo \
    ${name}.mlist \
    ${name}.fasta \
    ~/contrib/multicom_toolbox/apollo_pairwise.64bit/tm_score/TMscore_64 \
    ${name}.apollo \
    ${name}

cd ..
