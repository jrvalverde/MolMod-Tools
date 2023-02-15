#!/bin/bash

banner score

R=$1
L=$2

ref=''
#ref='../../reference.pdb'

for i in aff ; do
    cd $i/chains
    # restart info files for rebuilding
    echo 'model	DSX	PCS	SAS' > ../stats/dsx${R}${L}.info
    echo 'model	DSX	PCS	SAS' > ../stats/dsxR${R}${L}.info
    echo -n '' > ../stats/xscore${R}${L}.info
    echo 'model	vina	nnscore	dlscore' > ../stats/dlscore${R}${L}.info
    for p in ../models/*.pdb ; do
        base=`basename $p .pdb`
        
	# we may eventually use only DLSCORE, NNScore or similar... until then
	if [ ! -d dlscore ] ; then mkdir -p dlscore ; fi
	dlscore_summary=dlscore/${base}_R=${R}_L=${L}
	if [ ! -s "${dlscore_summary}.csv" ] ; then
	    echo "DLSCORE $base"
	    ~/contrib/dlscore/dlscore \
	        --ligand ${base}_${L}.mol2 \
		--receptor ${base}_${R}.pdb \
		--output $dlscore_summary \
		--verbose 1 \
		|& tee $dlscore_summary.log
	fi
	echo -n "$base	" >> ../stats/dlscore${R}${L}.info
	cat $dlscore_summary.csv \
	| tr ',' '\t' \
	| grep -v dlscore \
	>> ../stats/dlscore${R}${L}.info
	#echo '' >> ../stats/dlscore${R}${L}.info
	
        if [ "$ref" != "" ] ; then
            if [ ! -d dsxR ] ; then mkdir -p dsxR ; fi
            dsxR_summary=dsxR/DSX_${base}_${R}_${base}_${L}.txt
            #ls -l $dsxR_summary
            if [ ! -e $dsxR_summary ] ; then
                # score_dsx will work in ./dsx
                if [ -d dsx ] ; then mv dsx dsx.sav ; fi
                bash ~/work/lenjuanes/script/score_dsx.sh \
        	    ${base}_${R}.mol2 \
                    ${base}_${L}.mol2 \
                    $ref
	        mv dsx/* dsxR
                rmdir dsx
                if [ -d dsx.sav ] ; then mv dsx.sav dsx ; fi
            fi
            #echo "grep ${base}_${L}.pdb $dsxR_summary | cut -c 54-64"
            name=${base}_${L}	# the name might be too large (or not)
            dscore=`grep  "| "${name:0:28} $dsxR_summary | cut -c 54-64`
            pcscore=`grep "| "${name:0:28} $dsxR_summary | cut -c 77-87`
            sascore=`grep "| "${name:0:28} $dsxR_summary | cut -c 102-112`
            #echo $base $dsxR_summary
            #echo "DSXR <$dscore>"
            echo "$base:	$dscore	$pcscore	$sascore" >> ../stats/dsxR${R}${L}.info
        fi
        
        # this one we always do (DSX without reference)
        dsx_summary=dsx/DSX_${base}_${R}_${base}_${L}.txt
        if [ ! -e $dsx_summary ] ; then
        bash ~/work/lenjuanes/script/score_dsx.sh \
        	${base}_${R}.mol2 \
                ${base}_${L}.mol2 
        fi
        #echo "grep ${base}_${L}.pdb $dsx_summary | cut -c 54-64"
        name=${base}_${L}
        dscore=`grep  "| "${name:0:28} $dsx_summary | cut -c 54-64`
        pcscore=`grep "| "${name:0:28} $dsx_summary | cut -c 77-87`
        sascore=`grep "| "${name:0:28} $dsx_summary | cut -c 102-112`
        #echo "DSX <$dscore> <$pcscore> <$sascore>"
        echo "$base:	$dscore	$pcscore	$sascore" >> ../stats/dsx${R}${L}.info
        
        # and we also always do Xscore
        xscore_summary=xscore/${base}_${R}_${base}_${L}_xscore.sum
        if [ ! -e $xscore_summary ] ; then
        bash ~/work/lenjuanes/script/score_xscore.sh \
        	${base}_${R}.mol2 \
                ${base}_${L}.mol2 
	fi
	if [ -e $xscore_summary ] ; then
	    xenergy=`grep energy $xscore_summary | cut -d' ' -f5`
            echo "$base:	$xenergy	kcal/mol" >> ../stats/xscore${R}${L}.info
        fi
    done
    
    echo ">>> $i done"
    cd -
done
