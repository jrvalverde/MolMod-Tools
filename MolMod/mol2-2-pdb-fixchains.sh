# $1 is a mol2 file

f=$1

#obabel -imol2 $f -opdb \
#  | sed \
#      -e '2508iTER              PHE A 162'
#      -e '2508,5022s/^\(.\{20\}\) A/\1 B/g' \
#      -e '5022iTER              ALA B 325' \
#      -e "s/UNK A/UNK C/g" \
#      
#      -e 's/ATOM   2506/TER\nATOM   2506/g' \
#  > `basename $f .mol2`-ob.pdb

obabel -imol2 $f -opdb   \
  | sed \
        -e "s/UNK A/UNK C/g" \
	-e "s/ZIN A/UNK C/g" \
	-e "s/<0> A/UNK C/g" \
	-e '2508iTER              PHE A 162' \
        -e '2508,5022s/^\(.\{20\}\) A/\1 B/g' \
        -e '5022iTER              ALA B 325' \
  > `basename $f .mol2`.pdb
