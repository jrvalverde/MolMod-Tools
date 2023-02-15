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
    
    echo "E (in vacuo)"
    # minimization energy 'in vacuo'
    # if not already minimized
    if [ ! -d $m/ambermin/ ] ; then
        # minimize
        bash $BASE/ambermin.bash $R $L
        # and add the minimized files to the models
	for i in $m/ambermin/*/*_amber.pdb ; do
    	    if [ ! -s $m/models/`basename $i` ] ; then
	        cp $i $m/models/`basename $i`
            fi
        done
    fi
    # extract energies 'in vacuo'
    rm -f $m/stats/energy.info
    for mod in $m/ambermin/*/ ; do
        ene=`ls $mod/E=*`
        #remove up to last '='
        ene=${ene##*=}
        #echo $ene >&2
        model=${mod##*chim_}
        model=${model%/}
        #model=${model%_amber/}
        #echo $mod $model >&2
        echo "${model}.pdb	$ene" #>> stats/energy.dat
    done \
    | sort > $m/stats/energy.info  
    #sort energy.dat > energy.info && rm energy.dat
    sort $m/stats/energy.info > energy.tab


    echo "E (in solution)"
    # minimization energy in solution
    # if not already computed
    if [ ! -d $m/solmin ] ; then
        # minimized
        $BASE/solmin.bash
        #and add the minimized files to the models
        for i in $m/solmin/*/*_SolOpt.pdb ; do
           if [ ! -s $m/models/`basename $i` ] ; then
               # chain Z contains the solvent and ions
	       egrep -v '^.{20} Z' $i > $m/models/`basename $i`
           fi
       done
    fi
    # extract energies in solution
    rm -f stats/Senergy.info
    for mod in $m/solmin/opls-aa_*_150mM/ ; do
        ene=`grep "^Potential Energy  =" $mod/em.log | cut -f2 -d= `
        model=${mod##*opls-aa_}
        model=${model%_150mM*}
        echo $mod $model >&2
        echo "${model}_SolOpt.pdb	$ene" #>> stats/Senergy.dat
    done \
    | sort > $m/stats/Senergy.info
    #sort Senergy.dat > Senergy.info && rm Senergy.dat
    sort $m/stats/Senergy.info > Senergy.tab


    echo "H-bonds, clashes and contacts"
    # create stats files
    mkdir -p $m/stats
    # if tables not already computed
    if [ ! -s $m/stats/hbond.cnt ] ; then
        # if H-bonds have not been computed yet
        if [ ! -s $m/stats/hbond${R}${L}.info ] ; then
            # compute them
            bash $BASE/hbonds.sh $R $L
        fi
        # if contacts and clashes have't been computed
        if [ ! -s $m/stats/contact${R}${L}.info ] ; then
            # compute clashes and contacts
            bash $BASE/clashcontact.sh $R $L 
        fi
        # build tables of H-bonds, clashes, contacts and repulsion
        bash $BASE/stats.sh $R $L
    fi

    # It is enough to just "copy" the data
    cat $m/stats/hbond.cnt | grep -v '^$' | sort > hbond.tab
    cat $m/stats/clash.cnt | grep -v '^$' | sort > clash.tab
    cat $m/stats/contact.cnt | grep -v '^$' | sort > contact.tab
    cat $m/stats/repulsion.tab | grep -v '^$' | sort > repulsion.tab


    echo "scores (DSX and Xscore)"
    # Score receptor and ligand if not already done        
    if [ ! -d $m/chains ] ; then
        $BASE/split.sh $R $L
    fi
    if [ ! -e $m/stats/dsx${R}${L}.info \
         -o \
         ! -e $m/stats/xscore${R}${L}.info \
	 -o \
	 ! -e $m/stats/dlscore${R}${L}.info ] ; then
        $BASE/score.sh $R $L
        # if we do not score then create empty score files in $m/stats
        touch $m/stats/dsx${R}${L}.info
        touch $m/stats/xscore${R}${L}.info
        touch $m/stats/dlscore${R}${L}.info
    fi
    # do also add the .pdb to the file base name
    cat $m/stats/dsx${R}${L}.info \
    | tr -d ':' \
    | sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    | sort | tail -n +2 > dsx.tab
    cat $m/stats/xscore${R}${L}.info \
    | tr -d ':' \
    | sed -e 's|	kcal/mol||g' \
    | sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    | sort > xscore.tab
    tail -n +2 $m/stats/dlscore${R}${L}.info \
    | sed -e 's/\([A-Zrt]\)\t/\1.pdb\t/g' \
    | sort > dlscore.tab


    echo "RMSD"
    # Compute RMSD if not already done
    if [ ! -s $m/stats/RMSD${R}${L}.tab ] ; then
        $BASE/rmsd2.sh $R $L
    fi
    #tail -n +2 $m/stats/RMSD${R}${L}.tab | sed -e 's/.pdb//g' | sort > RMSD.tab
    #tail -n +2 $m/stats/RMSD${R}${L}.ni.tab | sed -e 's/.pdb//g' | sort > RMSD.ni.tab
    tail -n +2 $m/stats/RMSD${R}${L}.tab | sort > RMSD.tab
    tail -n +2 $m/stats/RMSD${R}${L}.ni.tab | sort > RMSD.ni.tab



    echo "Making joint summaries" 
    # Now create an all-together file
    # this one will only contain _amber entries
    join -t '	' -a 1 -e NA -o auto -j 1 clash.tab contact.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - hbond.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - repulsion.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - energy.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - RMSD.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - RMSD.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - dsx.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - xscore.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - dlscore.tab \
    > summary.tab

    join -t '	' -a 1 -e NA -o auto -j 1 clash.tab contact.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - hbond.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - repulsion.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - energy.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - Senergy.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - RMSD.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - RMSD.ni.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - dsx.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - xscore.tab \
    | join -t '	' -a 1 -e NA -o auto -j 1 - dlscore.tab \
    > summary+.tab


    echo "Cleaning up"
    # Place everything in its final destination
    mkdir -p summary

    mv hbond.tab clash.tab contact.tab repulsion.tab \
       energy.tab Senergy.tab \
       RMSD.tab RMSD.ni.tab \
       dlscore.tab dsx.tab xscore.tab \
       summary.tab summary+.tab \
       summary/
       
    cat > summary/header+.tab <<END
model	clash	contact	hbond	repulsion	E (vacuo)	E (sol)	RMSD (all)	RMSD	DSX	PCS	SAS	Xscore (kcal/mol)	Vina ΔG (kcal/mol)	NNScore (pKd)	DLScore (pKd)
END

done
