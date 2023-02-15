for i in *A.pdb ; do
  bash ~/work/lenjuanes/script/score_xscore.sh $i `basename $i A.pdb`B.mol2  
  bash ~/work/lenjuanes/script/score_dsx.sh $i `basename $i A.pdb`B.mol2 `basename $i A.pdb`B.mol2
done
