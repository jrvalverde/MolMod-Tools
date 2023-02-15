#!/bin/bash

banner stats

R=$1
L=$2

out=aff/stats
repdir=aff/repulsion

# find out number of models
nmodels=`grep -c '	#' $out/hbond-${R}_${L}.info`
# max model number is nmodels - 1
maxmodel=$((nmodels -1))

echo "Processing $nmodels models"
#et -x

# Note of the following should be needed any more
# -----------------------------------------------

if [ ! -s $out/hbond-${R}_${L}.cnt ] ; then
    echo "Preparing hbond-${R}_${L}.cnt"
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
    #done <<< $(grep '	' $out/hbond-${R}_${L}.info \
    done < <(grep '	' $out/hbond-${R}_${L}.info \
	| tr -d '#' \
	| sort -n 
	)

    #echo ARRAY
    for i in "${!name[@]}" ; do
	# for all keys in array 
	echo -n "" ; #echo "KEY $i = NAME ${name[$i]}:"
    done

    #this requires and "ALTOGETHER=YES" output
    for i in "${!name[@]}" ; do 
	echo -n "${name[$i]}	" 
	grep -c "^\#$i:" $out/hbond-${R}_${L}.info   
    done | sort > $out/hbond-${R}_${L}.cnt
fi


if [ ! -s $out/clash-${R}_${L}.cnt -o ! -s $out/contact-${R}_${L}.cnt ] ; then
    echo "Preparing clash-${R}_${L}.cnt and contact-${R}_${L}.cnt"
    # Now use the table of models written out when computing clashes and
    # contacts (this should be the same as above, but just in case...)
    unset name
    declare -A name
    while read no na ; do
	#echo READ $no '=' $na
	name[$no]+=$na
	#echo ">>> ${name[@]}"
    # this works depending on bash version
    #done <<< $(grep 'model id ' $out/ccmodels${R}${L}.lst \
    done < <(grep 'model id ' $out/ccmodels${R}${L}.lst \
	| sed -e 's/.*id #//g' -e 's/type .* name //g' \
	| sort -n
	)

    #echo ARRAY
    for i in "${!name[@]}" ; do
	echo -n "" ; #echo "$i = ${name[$i]}:"
    done

    for i in "${!name[@]}" ; do 
	echo -n "${name[$i]}	" 
	grep -c "^\#$i:" $out/clash-${R}_${L}.info   
    done | sort > $out/clash-${R}_${L}.cnt
    for i in "${!name[@]}" ; do 
	echo -n "${name[$i]}	" ; 
	grep -c "^\#$i:" $out/contact-${R}_${L}.info ; 
    done | sort > $out/contact-${R}_${L}.cnt
fi


# COMPUTE ELECTROSTATIC REPULSIONS
# I know, this is TERRIBLY SLOW and I can do much better than this, 
# but I don't have the time.
if [ ! -s $out/repulsion-${R}_${L}.tab ] ; then
    mkdir -p aff/repulsion
    echo "Preparing repulsion-${R}_${L}.tab"
    unset name
    declare -A name
    # we need to use the saved contact info and reference models by
    # their corresponding number
    while read no na ; do
	#echo READ $no '=' $na
	name[$no]+=$na
	#echo ">>> ${name[@]}"
    # this works depending on bash version
    #done <<< $(grep 'model id ' $out/ccmodels-${R}_${L}.lst \
    done < <(grep 'model id ' $out/ccmodels-${R}_${L}.lst \
	| sed -e 's/.*id #//g' -e 's/type .* name //g' \
	| sort -n
	)

    for i in "${!name[@]}" ; do 
	echo -n "COMPUTING REPULSIONS FOR ($i) ${name[$i]} " >&2
	echo -n "`basename ${name[$i]} .pdb`	" ; 
	tot=0
        if [ ! -s $repdir/${name[$i]} ] ; then
	    if [ -s $out/contact-${R}_${L}.info ] ; then
                grep "#$i:" $out/contact-${R}_${L}.info
	    else
                grep "^:" aff/contact/`basename ${name[$i]} .pdb`.contact
	    fi \
	    | while read atom1 atom2 overlap distance ; do
                a1resno=${atom1#*:} ; a1resno=${a1resno%.*}
                a1chain=${atom1#*.} ; a1chain=${a1chain%@*}
                a1name=${atom1#*@}

                a2resno=${atom2#*:} ; a2resno=${a2resno%.*}
                a2chain=${atom2#*.} ; a2chain=${a2chain%@*}
                a2name=${atom2#*@}

                # lookup charges in the mol2 files
                base=`basename ${name[$i]} .pdb`
                mol2=aff/chains/${base}_${a1chain}.mol2
                a1charge=`egrep "^ +[0-9]+ +$a1name .* $a1resno +[A-Z]+$a1resno " $mol2 \
                          | cut -c69-80`
                mol2=aff/chains/${base}_${a2chain}.mol2
                a2charge=`egrep "^ +[0-9]+ +$a2name .* $a2resno +[A-Z]+$a2resno " $mol2 \
                          | cut -c69-80`
                #echo "$a1resno $a1chain $a1name ($a1charge) x $a2resno $a2chain $a2name ($a2charge) $overlap $distance"

                # compute repulsion using Coulomb's law (q1 * q2 / d²)
                repulsion=`echo "scale=4 ; $a1charge * $a2charge / ($distance^2)" | bc -l `
                tot=`echo "scale=4 ; $tot + $repulsion" | bc -l`

		# by overwriting only the last value is kept
                echo "${name[$i]}	${tot}" > $repdir/${name[$i]}.repulsion
	        #break
	    done #|tail -1 | cut -d= -f2
        fi
        # read last accumulated total for this complex
	#total=`cat $repdir/${name[$i]} | cut -d= -f2`
        total=`ls $repdir/${name[$i]}=* | cut -d= -f2`
        echo " = $total" >&2	# send to stderr so it scapes to the screen
	echo "$total"
    done | cat -s | sort > $out/repulsion-${R}_${L}.tab
fi
