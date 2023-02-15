#!/bin/bash

banner summary

R=$1
L=$2

#BASE=`(cd ../script ; pwd)`
BASE=`dirname "$(readlink -f "$0")"`


for m in aff ; do
#for i in aff ; do
    #m=$i #m=`ls -d $i`
    if [ ! -d $m ] ; then continue ; fi
    echo "GATHERING STATS IN $m" ; # continue
    
    # Prepare the final destination of all summary files
    outd=$m/summary
    mkdir -p $outd
    
    echo "E (in vacuo)"
    # minimization energy 'in vacuo'
    # if not already minimized
    if [ ! -d $m/vacmin/ ] ; then
        # minimize
        bash $BASE/vacmin.bash $R $L
        # and add the minimized files to the models
	for i in $m/vacmin/*/*_vacuo.pdb ; do
    	    if [ ! -s $m/models/`basename $i` ] ; then
	        cp $i $m/models/`basename $i`
            fi
        done
    fi
    # extract energies 'in vacuo'
    rm -f $m/stats/energy-${R}_${L}.info
    for mod in $m/vacmin/*/ ; do
        ene=`ls $mod/E=*`
        #remove up to last '='
        ene=${ene##*=}
        #echo $ene >&2
        model=${mod##*amber_}
        model=${model/-H_310K*/_amber_vacuo}
        #model=${model%/}
        #model=${model%_amber/}
        #echo $mod $model >&2
        echo "${model}.pdb	$ene" #>> stats/energy.dat
    done \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $m/stats/energy-${R}_${L}.info  
    sort $m/stats/energy-${R}_${L}.info > $outd/energy-${R}_${L}.tab


    echo "E (in solution)"
    # minimization energy in solution
    # if not already computed
    if [ ! -d $m/solmin ] ; then
        # minimized
        $BASE/solmin.bash
        #and add the minimized files to the models
        for i in $m/solmin/*/*_solvent.pdb ; do
           if [ ! -s $m/models/`basename $i` ] ; then
               # chain Z contains the solvent and ions
	       egrep -v '^.{20} Z' $i > $m/models/`basename $i`
           fi
       done
    fi
    # extract energies in solution
    rm -f $m/stats/Senergy-${R}_${L}.info
    for mod in $m/solmin/opls-aa_*_150mM/ ; do
        ene=`grep "^Potential Energy  =" $mod/em.log | cut -f2 -d= `
        model=${mod##*opls-aa_}
        model=${model%_150mM*}
        echo $mod $model >&2
        echo "${model}_solvent	$ene" #>> stats/Senergy.dat
    done \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $m/stats/Senergy-${R}_${L}.info
    sort $m/stats/Senergy-${R}_${L}.info > $outd/Senergy-${R}_${L}.tab


    echo "H-bonds, clashes and contacts"
    # create stats files
    mkdir -p $m/stats
    # if tables not already computed
    if [ ! -s $m/stats/hbond-${R}_${L}.cnt ] ; then
        # if H-bonds have not been computed yet
        if [ ! -s $m/stats/hbond-${R}_${L}.info ] ; then
            # compute them
            bash $BASE/hbonds.sh $R $L
        fi
        # if contacts and clashes have't been computed
        if [ ! -s $m/stats/contact-${R}_${L}.info ] ; then
            # compute clashes and contacts
            bash $BASE/clashcontact.sh $R $L 
        fi
        # build tables of H-bonds, clashes, contacts and repulsion
        bash $BASE/stats.sh $R $L
    fi

    # It is enough to just "copy" the data after cleaning file names
    cat $m/stats/hbond-${R}_${L}.cnt \
    | grep -v '^$' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/hbond-${R}_${L}.tab
    cat $m/stats/clash-${R}_${L}.cnt \
    | grep -v '^$' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/clash-${R}_${L}.tab
    cat $m/stats/contact-${R}_${L}.cnt \
    | grep -v '^$' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/contact-${R}_${L}.tab
    cat $m/stats/repulsion-${R}_${L}.tab \
    | grep -v '^$' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/repulsion-${R}_${L}.tab


    echo "scores (DSX and Xscore)"
    # Score receptor and ligand if not already done        
    if [ ! -d $m/chains ] ; then
        $BASE/split.sh $R $L
    fi
    if [ ! -e $m/stats/dsx-${R}_${L}.info \
         -o \
         ! -e $m/stats/xscore-${R}_${L}.info \
	 -o \
	 ! -e $m/stats/dlscore-${R}_${L}.info ] ; then
        $BASE/score.sh $R $L
        # if we do not score then create empty score files in $m/stats
        touch $m/stats/dsx-${R}_${L}.info
        touch $m/stats/xscore-${R}_${L}.info
        touch $m/stats/dlscore-${R}_${L}.info
    fi
    # clean the file name
    cat $m/stats/dsx-${R}_${L}.info \
    | tr -d ':' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort | tail -n +2 > $outd/dsx-${R}_${L}.tab
    cat $m/stats/xscore-${R}_${L}.info \
    | tr -d ':' \
    | sed -e 's|	kcal/mol||g' \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/xscore-${R}_${L}.tab
    # if we want to add .pdb to the file name we can use
    #| sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \

    tail -n +2 $m/stats/dlscore-${R}_${L}.info \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/dlscore-${R}_${L}.tab


    echo "RMSD"
    # Compute RMSD if not already done
    if [ ! -s $m/stats/RMSD$-${R}_${L}.tab ] ; then
        $BASE/rmsd3.sh $R $L
    fi
    tail -n +2 $m/stats/RMSD-${R}_${L}.tab \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/RMSD-${R}_${L}.tab
    
    tail -n +2 $m/stats/RMSD-${R}_${L}.ni.tab \
    | sed -e 's|.*/||g' -e 's/.pdb//g' \
    | sort > $outd/RMSD-${R}_${L}.ni.tab



    echo "Making joint summaries" 
    # Now create an all-together file
    # this one will only contain _amber entries
    join -t '	' -a 1 -e NA -o auto -j 1 $outd/clash-${R}_${L}.tab $outd/contact-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/hbond-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/repulsion-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/energy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/RMSD-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/RMSD-${R}_${L}.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/dsx-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/xscore-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/dlscore-${R}_${L}.tab \
    > $outd/summary.tab

    cat > $outd/summary+.tab <<END
model	clash	contact	hbond	repulsion	E (vacuo)	E (sol)	RMSD (all)	RMSD	DSX	PCS	SAS	Xscore (kcal/mol)	Vina ΔG (kcal/mol)	NNScore (pKd)	DLScore (pKd)
END
    join -t '	' -a 1 -e NA -o auto -j 1 $outd/clash-${R}_${L}.tab $outd/contact-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/hbond-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/repulsion-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/energy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/Senergy-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/RMSD-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/RMSD-${R}_${L}.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/dsx-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/xscore-${R}_${L}.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - $outd/dlscore-${R}_${L}.tab \
    >> $outd/summary+.tab

       

done
