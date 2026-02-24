#!/bin/bash
#
#	This is an add-hoc command to compute all H-bonds
#
# AUTHOR
#	All the code is
#		(C) José R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#	and
#		Licensed under (at your option) either GNU/GPL v3 or EUPL v1.1
#

banner hbonds


ONEBYONE=YES
ALLTOGETHER=YES

function hbonds() {
    R=$1
    L=$2

    d=aff	# this is hardcoded for now.

    input=$d/clean
    output=$d/stats
    mkdir -p $output

   # This may be better when there are many models to process
   # Also, this may be parallelizable with a bit of care
   if [ "$ONEBYONE" == 'YES' ] ; then
	# DO ALL ONE BY ONE
	mkdir -p $d/hbond
	if [ ! -s $output/hbond-${R}_${L}.count ] ; then
    	    for i in $input/*.pdb ; do
	        name=`basename $i .pdb`
		echo "Finding H-bonds in $name"
		if [ ! -s $d/hbond/$name.hbond ] ; then
                  # Here we hope that any ligands will be in a single chain
		  DISPLAY='' chimera --nogui <<END
        	    open $i
        	    #echo "$i"
        	    select #*:*.$L
        	    findhbond intermodel false intramodel true intraMol false intraRes false selRestrict cross relax true saveFile $d/hbond/$name.hbond
        	    #findhbond intraMol false intraRes false selRestrict both relax true
END
		fi
	    done |& tee $output/hbond-${R}_${L}.log

#           This no longer works
#	    grep "^[0-9]\+ hydrogen bonds found" $d/hbond/*.hbond \
#	    | uniq | cut -d' ' -f1 \
#	    | sed -e 's/.hbond:/.pdb	/g' \
#	    | sort > $output/hbond-${R}_${L}.count
            echo "name	hbonds" > $output/hbond-${R}_${L}.count
	    grep -c "^:" $d/hbond/*.hbond \
            | sed -e 's|^.*/||g' \
            | sed -e 's/\.hbond//g' \
            | tr ':' '	' \
            | sort \
            >> $output/hbond-${R}_${L}.count

        fi	# ! -s $output/hbond-${R}_${L}.count
    fi		# "$ONEBYONE" == 'YES'

    
    # This is simpler when there are few models
    if [ "$ALLTOGETHER" == 'YES' ] ; then
	# DO ALL AT ONCE
	if [ ! -s $output/hbond-${R}_${L}.cnt ] ; then
  	    if [ ! -e $output/hbond-${R}_${L}.info ] ; then
	      DISPLAY='' chimera --nogui $input/*.pdb <<END
                #open $i
                #echo "$i"
                select #*:*.$L
                findhbond intermodel false intramodel true intraMol false intraRes false selRestrict cross relax true saveFile $output/hbond-${R}_${L}.info
                #findhbond intraMol false intraRes false selRestrict both relax true
END
            fi
	    # MAKE hbond.cnt FILE    
	    # find out number of models
	    nmodels=`grep -c '	#' $output/hbond-${R}_${L}.info`
	    # max model number is nmodels - 1
	    maxmodel=$((nmodels - 1))

	    echo "Processing $nmodels models"

	    # grep with an associative array
	    # we prefer this because it makes the association explicit
	    declare -A name

	    # fill it in, associating model number to model name
	    # using the association table produced within hbond.info
	    while read no na ; do
		#echo READ $no '=' $na
		name[$no]+=$na
		#echo ">>> ${name[@]}"
	    # this works on and off (depends on bash version
	    #done <<< $(grep '	' $output/hbond-${R}_${L}.info \
	    done < <(grep '	' $output/hbond-${R}_${L}.info \
		| tr -d '#' \
		| sort -n 
		)

	    #echo ARRAY for debugging
	    #for i in "${!name[@]}" ; do
	    #   # for all keys in array 
	    #   echo "KEY $i = NAME ${name[$i]}:"
	    #done

	    for i in "${!name[@]}" ; do 
		echo -n "${name[$i]}	" 
		grep -c "^\#$i:" $output/hbond-${R}_${L}.info   
	    done \
                 | sed -e 's|^.*/||g' \
                       -e 's/\.pdb	/	/g' \
                 | sort \
                 > $output/hbond-${R}_${L}.cnt
        fi
    fi		# "$ALLTOGETHER" == 'YES'
    
    if [ ! -s $output/hbond-${R}_${L}.cnt ] ; then
        if  [ -s $output/hbond-${R}_${L}.count ] ; then
            cp $output/hbond-${R}_${L}.count $output/hbond-${R}_${L}.cnt
        fi
    fi

}

hbonds $*
