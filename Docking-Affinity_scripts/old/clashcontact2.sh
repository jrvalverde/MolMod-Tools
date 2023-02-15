#!/bin/bash
#
#	This is an add-hoc command to compute all clashes and contacts
#	within between chains A and B, A and C and between chains
#	B and C in a PDB file containing three chains.
#
#	This is not a generic script!
#
# AUTHOR
#	All the code is
#		(C) Jos´e R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#	and
#		Licensed under (at your option) either GNU/GPL v3 or EUPL v1.1

if [ $# -lt 2 ] ; then
    echo "$0 REC-CHAINS LIG-CHAINS"
    exit
fi

banner steric

#A-D C-B
R=$1
L=$2

ALLTOGETHER=YES
ONEBYONE=YES


function clashcontact() {
    R=$1
    L=$2
    
    wd=aff
    inpd=$wd/clean
    outd=$wd/stats
    mkdir -p $outd

    # this one is simpler for a small number of models
    if [ "$ALLTOGETHER" == "YES" ] ; then
        if [ ! -s $outd/contact-${R}_${L}.info -o \
             ! -s $outd/clash-${R}_${L}.info -o \
	     ! -s $outd/ccmodels-${R}_${L}.lst ] ; then

	  echo "Finding clashes and contacts"
	  unset DISPLAY
	  #chimera --nogui --script - <<PYTHONSCRIPTEND
	  chimera --nogui $inpd/*.pdb > $outd/ccmodels-${R}_${L}.lst <<END
		list models
        	findclash #*.*:*.$L test model overlapCutoff 0.6 hbondAllowance 0.4 log true intraMol false intraRes false saveFile $outd/clash-${R}_${L}.info
        	findclash #*.*:*.$L test model overlapCutoff -0.4 hbondAllowance 0.0 log true intraMol false intraRes false saveFile $outd/contact-${R}_${L}.info
END
#                findclash #*.*:*.$L test model overlapCutoff 0.6 hbondAllowance 0.4 log true interSubmodel true intraMol false intraRes false saveFile $outd/clash-${R}_${L}.info
#                findclash #*.*:*.$L test model overlapCutoff -0.4 hbondAllowance 0.0 log true interSubmodel true intraMol false intraRes false saveFile $outd/contact-${R}_${L}.info
#END
        fi

        echo "Building tables of clashes and contacts"
	# Now use the table of models written out
	unset name
	declare -A name
	while read no na ; do
	    #echo READ $no '=' $na
	    name[$no]+=$na
	    #echo ">>> ${name[@]}"
	# this works depending on bash version
	#done <<< $(grep 'model id ' $outd/ccmodels-${R}_${L}.lst \
	done < <(grep 'model id ' $outd/ccmodels-${R}_${L}.lst \
	    | sed -e 's/.*id #//g' -e 's/type .* name //g' \
	    | sort -n
	    )

	#echo ARRAY (for debugging only)
	for i in "${!name[@]}" ; do
	    echo -n "" ; #echo "$i = ${name[$i]}:"
	done

	for i in "${!name[@]}" ; do 
	    echo -n "`basename ${name[$i]} .pdb`	" 
	    grep -c "^\#$i:" $outd/clash-${R}_${L}.info   
	done | sed -e 's/\.pdb	/	/g' | sort > $outd/clash-${R}_${L}.cnt
	for i in "${!name[@]}" ; do 
	    echo -n "`basename ${name[$i]} .pdb`	" ; 
	    grep -c "^\#$i:" $outd/contact-${R}_${L}.info ; 
	done | sed -e 's/\.pdb	//g' | sort > $outd/contact-${R}_${L}.cnt
    
	echo "Done."
    fi		# "$ALLTOGETHER" == "YES"

    
    # this one may be more efficient for a large number of models
    if [ "$ONEBYONE" == "YES" ] ; then
        mkdir -p $wd/clash
	mkdir -p $wd/contact
        for i in $inpd/*.pdb ; do
          echo "CLASHES FOR MODEL $i"
	  name=`basename $i .pdb`
          if [ ! -s $wd/clash/$name.clash ] ; then
	    DISPLAY='' chimera --nogui <<END
                open $i
                findclash #0:*.$L test model overlapCutoff 0.6 hbondAllowance 0.4 log true saveFile $wd/clash/$name.clash
END
#                findclash #*.*:*.$L test model overlapCutoff 0.6 hbondAllowance 0.4 log true interSubmodel true intraMol false intraRes false saveFile $outd/clash-${R}_${L}.info
	  fi
          echo "CONTACTS FOR MODEL $i"
	  if [ ! -s $wd/contact/$name.contact ] ; then
            DISPLAY='' chimera --nogui <<END
	        open $i
                findclash #0:*.$L test model overlapCutoff -0.4 hbondAllowance 0.0 log true intraMol false intraRes false saveFile $wd/contact/$name.contact
#               findclash #*.*:*.$L test model overlapCutoff -0.4 hbondAllowance 0.0 log true interSubmodel true intraMol false intraRes false saveFile $outd/contact-${R}_${L}.info
END
	  fi
        done
	if [ -e $outd/clash-${R}_${L}.count ] ; then mv $outd/clash-${R}_${L}.count $outd/clash-${R}_${L}.count.sav ; fi
	if [ -e $outd/contact-${R}_${L}.count ] ; then mv $outd/contact-${R}_${L}.count $outd/contact-${R}_${L}.count.sav ; fi
	if [ ! -s $wd/stats/clash-${R}_${L}.count -o \
             ! -s $wd/stats/contact-${R}_${L}.count ] ; then
	    # generate the .count files
	    echo "Building tables"
	    truncate -s 0 $outd/clash-${R}_${L}.count
	    truncate -s 0 $outd/contact-${R}_${L}.count
	    truncate -s 0 $outd/clashes-${R}_${L}.count
	    truncate -s 0 $outd/contacts-${R}_${L}.count
            for i in $inpd/*.pdb ; do
		name=`basename $i .pdb`
		#echo $name $i
		echo -n $name"	" >> $wd/stats/clashes-${R}_${L}.count
		echo -n $name"	" >> $wd/stats/contacts-${R}_${L}.count
		grep "^[0-9]\+ contacts" $wd/clash/$name.clash \
		| uniq | cut -d' ' -f1 >> $outd/clashes-${R}_${L}.count
		grep "^[0-9]\+ contacts" $wd/contact/$name.contact \
		| uniq | cut -d' ' -f1 >> $wd/stats/contacts-${R}_${L}.count
		# just in case, we'll squeeze them later anyway
		echo "" >> $wd/stats/clashes-${R}_${L}.count
		echo "" >> $wd/stats/contacts-${R}_${L}.count
	    done
	    grep -v '^$' $outd/clashes-${R}_${L}.count | sort > $outd/clash-${R}_${L}.count
	    grep -v '^$' $outd/contacts-${R}_${L}.count | sort > $outd/contact-${R}_${L}.count
	fi

	echo "Rebuilding tables"
	# we may also do it faster
	grep "^[0-9]\+ contacts" $wd/clash/* | uniq | cut -d' ' -f1 \
	| sed -e 's/.clash:/	/g' -e 's|.*/||g'\
	| sort > $outd/clashes-${R}_${L}.counts 
	grep "^[0-9]\+ contacts" $wd/contact/* | uniq | cut -d' ' -f1 \
	| sed -e 's/.contact:/	/g'  -e 's|.*/||g'\
	| sort > $outd/contacts-${R}_${L}.counts
    fi

}

clashcontact $*

