#!/bin/bash

wt_pdb=${1:-wt.pdb}
chains=${2:-A}
mutant_list=${3:-mutant.list}

chimoptimize=`pwd`/chimera_dp_optimize_long.sh
obminimize=`pwd`/obminimize3.bash

declare -A aa_n_to_3
declare -A aa_3_to_n
declare -A aa_3_to_1
declare -A aa_1_to_3
declare -A aa_n_to_1
declare -A aa_1_to_n


while read aan aa3 aa1 ; do
    # set up associative arrays
    aa_n_to_3["$aan"]="$aa3"
    aa_3_to_n["$aa3"]="$aan"
    aa_3_to_1["$aa3"]="$aa1"
    aa_1_to_3["$aa1"]="$aa3"
    aa_n_to_1["$aan"]="$aa1"
    aa_1_to_n["$aa1"]="$aan"
done <<END
Amino.acid	Three.letter.code	One.letter.code	
alanine	ala	A
arginine	arg	R
asparagine	asn	N
aspartic_acid	asp	D
asparagine_or_aspartic_acid	asx	B
cysteine	cys	C
glutamic_acid	glu	E
glutamine	gln	Q
glutamine_or_glutamic_acid	glx	Z
glycine	gly	G
histidine	his	H
isoleucine	ile	I
leucine	leu	L
lysine	lys	K
methionine	met	M
phenylalanine	phe	F
proline	pro	P
serine	ser	S
threonine	thr	T
tryptophan	trp	W
tyrosine	tyr	Y
valine	val	V
END

#echo ${aa_1_to_n[@]}	# all values
#echo ${!aa_1_to_n[@]}	# all keys

cat $mutant_list | \
while read ori1 pos mut1 ; do
    mutant="$ori1$pos$mut1"
    mkdir -p "$mutant"
    out="raw$ori1$pos$mut1"
    if [ ! -e "$mutant/$out.pdb" ] ; then 
        mut3=${aa_1_to_3["$mut1"]}
		ori3=${aa_1_to_3["$ori1"]}
        echo "Mutating $ori1 ($ori3) to $mut1 ($mut3) at position $pos of chains $chains"
        if [ ! -e "$mutant/$out.pdb" ] ; then
            DISPLAY='' chimera --nogui >& $mutant/$out.log <<END
                open $wt_pdb
                swapaa $mut3 #0:$pos.$chains
                write format pdb 0 $mutant/$out.pdb
END
        fi
    fi
#done
#exit
#while 1 ; do
    cd $mutant
    if [ -e $out.pdb -a ! -e chim_${out}_amber/${out}_amber.pdb ] ; then
#    if [ -e $out.pdb -a ! -e chim_${out}_amber ] ; then
        echo "Optimizing $out.pdb with UCSF Chimera"
        $chimoptimize $out.pdb &
    fi
    if [ -e $out.pdb -a ! -e obm_${out}_gaff/$out.H_gaff.pdb ] ; then
#    if [ -e $out.pdb -a ! -e obm_${out}_gaff ] ; then
        echo "Optimizing $out.pdb with OpenBabel"
        $obminimize $out.pdb -i $out.pdb -f gaff -c gasteiger >& ${out}_gaff.log &
    fi
    cd -
done
