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

R=$1
L=$2

ONEBYONE=YES
ALLTOGETHER=NO

for d in aff ; do
    input=$d/clean
    output=$d/stats
    mkdir -p $output

   # This may be better when there are many models to process
   if [ "$ONEBYONE" == 'YES' ] ; then
	# DO ALL ONE BY ONE
	mkdir -p $d/hbond
	if [ ! -s $output/hbond.count ] ; then
    	    for i in $input/*.pdb ; do
	        name=`basename $i .pdb`
		echo "$name"
		if [ ! -s $d/hbond/$name.hbond ] ; then
		  DISPLAY='' chimera --nogui <<END
        	    open $i
        	    #echo "$i"
        	    select #*:*.$L
        	    findhbond intermodel false intramodel true intraMol false intraRes false selRestrict cross relax true saveFile $d/hbond/$name.hbond
        	    #findhbond intraMol false intraRes false selRestrict both relax true
END
		fi
	    done |& tee $d/stats/hbond$R$L.log
	    grep "^[0-9]\+ hydrogen bonds found" $d/hbond/* \
	    | uniq | cut -d' ' -f1 \
	    | sed -e 's/.hbond:/.pdb	/g' \
	    | sort > $output/hbond.count
            fi
    fi
exit
    
    # This is simpler when there are few models
    if [ "$ALLTOGETHER" == 'YES' ] ; then
	# DO ALL AT ONCE
	if [ ! -s hbond.cnt ] ; then
  	    if [ ! -e $output/hbond${R}${L}.info ] ; then
	      DISPLAY='' chimera --nogui $input/*.pdb <<END
                #open $i
                #echo "$i"
                select #*:*.$L
                findhbond intermodel false intramodel true intraMol false intraRes false selRestrict cross relax true saveFile $output/hbond${R}${L}.info
                #findhbond intraMol false intraRes false selRestrict both relax true
END
            fi
	    # MAKE hbond.cnt FILE    
	    # find out number of models
	    nmodels=`grep -c '	#' $output/hbond${R}${L}.info`
	    # max model number is nmodels - 1
	    maxmodel=$((nmodels -1))

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
	    #done <<< $(grep '	' $output/hbond${R}${L}.info \
	    done < <(grep '	' $output/hbond${R}${L}.info \
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
		grep -c "^\#$i:" $output/hbond${R}${L}.info   
	    done | sort > $output/hbond.cnt
        fi
    fi
    
    if [ ! -s $output/hbond.cnt ] ; then
        if  [ -s $output/hbond.count ] ; then
            cp $output/hbond.count $output/hbond.cnt
        fi
    fi

done
