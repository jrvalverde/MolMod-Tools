#!/bin/bash

banner score

R=$1
L=$2

echo "score $R $L"

ref='./reflig.mol2'		# we'll fix it to absolute path name later
#ref='./reference.pdb'		# once function realfile has been defined

dlscore=$HOME/contrib/dlscore/dlscore
score_dsx=~/work/lenjuanes/script/score_dsx.sh
score_xscore=~/work/lenjuanes/script/score_xscore.sh

# Other methods to get the number of available processors:
#=$(grep -c processor /proc/cpuinfo)
# grep 'cpu cores' /proc/cpuinfo
# hwinfo --cpu --short
# getconf _NPROCESSORS_ONLN
# sudo dmidecode -t 4
# sudo dmidecode -t 4 | egrep -i 'core (count|enabled)|thread count|Version'
AVAIL_PROCS=`nproc`
#NUM_PROCS=$AVAIL_PROCS
#NUM_PROCS=$((AVAIL_PROCS / 3))
#NUM_PROCS=64
NUM_PROCS=1

nproc=0

# get the real absolute path name of a file
function realfile () {
   if [ -x `which readlink` ] ; then
        readlink -e $1
    elif [ -x `which realpath` ] ; then
        realpath $1
    else
        local target=`lastlink $1`
        local tname=${target##*/}
        local tdir=`dirname $target`
        echo $(cd $tdir ; pwd -P)"/$tname"
    fi
}

ref=`realfile $ref`


function score() {
#for dir in aff ; do
    R=$1
    L=$2
    local dir=aff

#c=0
    for p in $dir/models/*.pdb ; do
#if [ $c -eq 1000 ] ; then echo "KO"; return ; fi
#(( c++ ))
#echo $c
#echo $p
        # ${string#match} remove prefix (# shortest ##longest) match
        # ${string%match} remove suffix (% shortest %%longest) match
	# ${parameter/pattern/string} pattern substitution
        local base=`basename $p .pdb`
        
        if (( nproc++ >= NUM_PROCS )); then
	    # if there are already too many jobs running, wait for one to 
	    # finish before procceeding
            wait -n   # wait for one job to complete. Bash 4.3
            # we can decrease nproc here, but once we have reached
	    # the maximum we'll substitute jobs one by one.
	    (( nproc-- ))
        fi

	(
            # DLSCORE also computes vina and NNScore
	    if [ ! -d $dir/dlscore ] ; then mkdir -p $dir/dlscore ; fi
	    local dlscore_summary=$dir/dlscore/${base}_R=${R}_L=${L}
            # check required files
            if [ ! -s  $dir/chains/${base}_${R}.pdb ] ; then
                echo "ERROR DLSCORE: $dir/chains/${base}_${R}.pdb does not exist"
            elif [ ! -s $dir/chains/${base}_${L}.mol2 ] ; then
                echo "ERROR DLSCORE: $dir/chains/${base}_${L}.pdb does not exist"
            elif [ ! -s "${dlscore_summary}.csv" ] ; then
		#echo "DLSCORE $base"
		$dlscore \
	            --ligand $dir/chains/${base}_${L}.mol2 \
		    --receptor $dir/chains/${base}_${R}.pdb \
		    --output ${dlscore_summary} \
		    --verbose 1 \
		    |& tee ${dlscore_summary}.log
	    else
                echo "'${dlscore_summary}.csv' done"
            fi
            # save scores in separate files to avoid overwriting
            # during parallel processing; they will all be collated 
            # at the end
            # We do this always because it is light weight
	    echo -n "$base	" \
            > ${dlscore_summary}.inf
	    if [ ! -s "${dlscore_summary}.csv" ] ; then
	        echo "	NA	NA	NA" \
                >> ${dlscore_summary}.inf
	    else
		cat ${dlscore_summary}.csv \
		| grep -v dlscore \
		| tr ',' '\t' \
		>> ${dlscore_summary}.inf
	    fi

            # score_dsx and score_xscore will create ./dsx and ./xscore

            # if we can access the reference structure
	    if [ -s "$ref" ] ; then
	        cd $dir/
        	if [ ! -d dsxR ] ; then mkdir -p dsxR ; fi
                # score_dsx will generate  $dsxR_dummary.txt
        	local dsxR_summary=dsxR/DSX_${base}_${R}_${base}_${L}
        	#ls -l $dsxR_summary
        	if [ ! -e ${dsxR_summary}.txt ] ; then
		    $score_dsx \
        		chains/${base}_${R}.mol2 \
                	chains/${base}_${L}.mol2 \
                	"$ref"
                    # since we specify a reference output goes to 'dsxR'
                else
                    echo "'${dsxR_summary}.txt' done"
        	fi
		# extract scores
        	#local name=${base}_${L}	# the name might be too large (>28 char)
        	#local dscore=`grep  "| "${name:0:28} $dsxR_summary | cut -c 54-64`
        	#local pcscore=`grep "| "${name:0:28} $dsxR_summary | cut -c 77-87`
        	#local sascore=`grep "| "${name:0:28} $dsxR_summary | cut -c 102-112`
        	#echo $base $dsxR_summary
        	#echo "DSXR <$dscore>"
                if [ ! -s ${dsxR_summary}.txt ] ; then
                    echo "dsxR ERROR: No ${dsxR_summary}.txt produced"
                    echo "$base:	NA	NA	NA" \
                    > ${dsxR_summary}.inf
                else
        	    scores=`cat ${dsxR_summary}.txt | tail -2 | head -1`
                    dscore=`echo "$scores" | cut -d'|' -f4`
                    pcscore=`echo "$scores" | cut -d'|' -f6`
                    torscore=`echo "$scores" | cut -d'|' -f7`
                    sascore=`echo "$scores" | cut -d'|' -f8`
                    # save scores in separate files to avoid parallel overwrites
                    # we will collate them all later
                    echo "$base:	$dscore	$pcscore	$sascore" \
                         > ${dsxR_summary}.inf
                fi
                echo -n "score: "; cd -
	    fi

            # this one we always do (DSX without reference)
            cd $dir
            if [ ! -d dsx ] ; then mkdir -p dsx ; fi
            local dsx_summary=dsx/DSX_${base}_${R}_${base}_${L}
            if [ ! -e ${dsx_summary}.txt ] ; then
                $score_dsx \
        	    chains/${base}_${R}.mol2 \
                    chains/${base}_${L}.mol2 
                # since we do not specify a reference output goes to 'dsx'
            else
                echo "'${dsx_summary}.txt' done"
            fi
            # extract scores
            #local name=${base}_${L}	# the name might be too large (>28 char)
            #local dscore=`grep  "| "${name:0:28} $dsxR_summary | cut -c 54-64`
            #local pcscore=`grep "| "${name:0:28} $dsxR_summary | cut -c 77-87`
            #local sascore=`grep "| "${name:0:28} $dsxR_summary | cut -c 102-112`
            #echo $base $dsxR_summary
            #echo "DSXR <$dscore>"
            if [ ! -s ${dsx_summary}.txt ] ; then
                echo "dsx ERROR: No ${dsx_summary}.txt produced"
                echo "$base:	NA	NA	NA" \
                > ${dsx_summary}.inf
            else
                scores=`cat ${dsxR_summary}.txt | tail -2 | head -1`
                dscore=`echo "$scores" | cut -d'|' -f4`
                pcscore=`echo "$scores" | cut -d'|' -f6`
                torscore=`echo "$scores" | cut -d'|' -f7`
                sascore=`echo "$scores" | cut -d'|' -f8`
                #echo "DSX <$dscore> <$pcscore> <$sascore>"
                # save scores in separate files to avoid parallel overwrites
                # we will collate them all later
                echo "$base:	$dscore	$pcscore	$sascore" \
                > ${dsx_summary}.inf
		#
		# other way to do it
		echo -n "$base:	" > ${dsx_summary}.INF
		grep "^ 0 " ${dsxR_summary}.txt \
		  | cut -d'|' -f 4,6,8 \
		  | tr -d ' ' \
		  | sed -e 's/|/\t/g' -e 's/ \+//g' \
		  >> ${dsx_summary}.INF
		
            fi
	    echo -n "score: "; cd -

	    cd $dir
            # and we also do always do Xscore
            local xscore_summary=xscore/${base}_${R}_${base}_${L}_xscore
            if [ ! -e "${xscore_summary}.sum" ] ; then
                $score_xscore \
        	    chains/${base}_${R}.pdb  \
                    chains/${base}_${L}.mol2 
	    else
                echo "'${xscore_summary}.sum' done"
            fi
	    # extract scores
            # save scores in separate files to avoid parallel overwrites
            # we will collate them all later
	    if [ -e "${xscore_summary}.sum" ] ; then
		local xenergy=`grep energy "${xscore_summary}.sum" | cut -d' ' -f5`
        	echo "$base:	$xenergy	kcal/mol" \
                > ${xscore_summary}.inf
            else
                echo "score ERROR: No ${xscore_summary}.sum produced"
                echo "$base:	NA	kcal/mol" \
                > ${xscore_summary}.inf
            fi
	    cd -
	    	    
	) &
                                                                               	                      
    done
    wait

    # update info files in the statitistics directory
    echo 'model	vina	nnscore	dlscore' > $dir/stats/dlscore-${R}_${L}.info
    cat $dir/dlscore/*.inf >> $dir/stats/dlscore-${R}_${L}.info

    echo 'model	DSX	PCS	SAS' > $dir/stats/dsxR-${R}_${L}.info
    cat $dir/dsxR/*.inf >> $dir/stats/dsxR-${R}_${L}.info

    echo 'model	DSX	PCS	SAS' > $dir/stats/dsx-${R}_${L}.info
    cat $dir/dsx/*.inf >> $dir/stats/dsx-${R}_${L}.info
    cat $dir/dsx/*.INF >> $dir/stats/dsx-${R}_${L}.INFO
    # even easier yet: do all at once
    grep "^ 0 " *.tot.* \
      | cut -d'|' -f 1,4,6,8 \
      | tr -d ' ' \
      | sed -e 's/|/\t/g' -e 's/^.*AB_//g' -e 's/_C[^\t]*//g' \
      | sort > ../stats/dsx.INFOK

    # we don't add a header to the info file for xscore
    truncate -s 0 $dir/stats/xscore-${R}_${L}.info
    cat $dir/xscore/*.inf >> $dir/stats/xscore-${R}_${L}.info
                       
    echo ">>> score: directory '$dir' done"
    
    #cd -
#done
}

score $R $L

