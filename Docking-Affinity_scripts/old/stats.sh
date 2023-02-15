#!/bin/bash

banner stats

R=$1
L=$2

out=aff/stats

# find out number of models
nmodels=`grep -c '	#' $out/hbond${R}${L}.info`
# max model number is nmodels - 1
maxmodel=$((nmodels -1))

echo "Processing $nmodels models"


if [ ! -s $out/hbond.cnt ] ; then
    echo "Preparing hbond.cnt"
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
    #done <<< $(grep '	' $out/hbond${R}${L}.info \
    done < <(grep '	' $out/hbond${R}${L}.info \
	| tr -d '#' \
	| sort -n 
	)

    #echo ARRAY
    for i in "${!name[@]}" ; do
	# for all keys in array 
	echo -n "" ; #echo "KEY $i = NAME ${name[$i]}:"
    done

    for i in "${!name[@]}" ; do 
	echo -n "${name[$i]}	" 
	grep -c "^\#$i:" $out/hbond${R}${L}.info   
    done | sort > $out/hbond.cnt
fi


if [ ! -s $out/clash.cnt -o ! -s $out/contact.cnt ] ; then
    echo "Preparing clash.cnt and contact.cnt"
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
	grep -c "^\#$i:" $out/clash${R}${L}.info   
    done | sort > $out/clash.cnt
    for i in "${!name[@]}" ; do 
	echo -n "${name[$i]}	" ; 
	grep -c "^\#$i:" $out/contact${R}${L}.info ; 
    done | sort > $out/contact.cnt
fi


# COMPUTE ELECTROSTATIC REPULSIONS
# I know, this is TERRIBLY SLOW and I can do much better than this, 
# but I don't have the time.
if [ ! -s $out/repulsion.tab ] ; then
    echo "Preparing repulsion.tab"
    unset name
    declare -A name
    # we need to use the saved contact info and reference models by
    # their corresponding number
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

    for i in "${!name[@]}" ; do 
	echo "COMPUTING REPULSIONS FOR ($i) ${name[$i]} " >&2
	echo -n "${name[$i]}	" ; 
	tot=0
	if [ -s $out/contact${R}${L}.info ] ; then
            grep "#$i:" $out/contact${R}${L}.info
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

            #echo "repulsion=$repulsion"
            echo "tot=$tot"
	#break
	done | tail -1 | cut -d= -f2
	# This may go wrong if there are no contacts at all (no ending newline)
	# we can add a new line and filter duplicated newlines afterwards
	echo ""
    done | sort | cat -s > $out/repulsion.tab
fi
