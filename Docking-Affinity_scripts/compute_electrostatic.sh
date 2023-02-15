#!/bin/bash

banner E_elec

R=$1
L=$2

out=aff/stats

if [ -s $out/repulsion-${R}_${L}.info ] ; then
    echo "$out/repulsion.tab already exists, skipping computation"
    echo ""
    echo "IF YOU WANT TO RECOMPUTE REPULSIONS, DELETE $out/repulsion-${R}_${L}.info"
    echo ""
    exit
fi

# First use the table of models written out when computing clashes and
# contacts to build an association between numbers and names
unset name
declare -A name
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

#echo ARRAY for debugging
for i in "${!name[@]}" ; do
    echo -n "" ; #echo "$i = ${name[$i]}:"
done


# compute electrostatic repulsions
# I know, this is TERRIBLY SLOW and I can do much better than this, 
# but I don't have the time.
#c=0
for i in "${!name[@]}" ; do 
#if [ $c -eq 10 ] ; then exit ; fi
#(( c++ ))
    base=`basename ${name[$i]} .pdb`
    echo "CHECKING CONTACT REPULSIONS FOR $i ${name[$i]}" >&2
    if [ ! -s aff/repulsion/${base}.repulsion ] ; then
        echo -n "`basename ${name[$i]} .pdb`	" 
        tot=0
        grep "#$i:" $out/contact-${R}_${L}.info \
        | while read atom1 atom2 overlap distance ; do
            a1resno=${atom1#*:} ; a1resno=${a1resno%.*}
            a1chain=${atom1#*.} ; a1chain=${a1chain%@*}
            a1name=${atom1#*@}

            a2resno=${atom2#*:} ; a2resno=${a2resno%.*}
            a2chain=${atom2#*.} ; a2chain=${a2chain%@*}
            a2name=${atom2#*@}

            # lookup charges in the mol2 files
            mol2=aff/chains/${base}_${a1chain}.mol2
            a1charge=`egrep "^ +[0-9]+ +$a1name .* $a1resno +[A-Z]+$a1resno " $mol2 \
                      | cut -c69-80`
            mol2=aff/chains/${base}_${a2chain}.mol2
            a2charge=`egrep "^ +[0-9]+ +$a2name .* $a2resno +[A-Z]+$a2resno " $mol2 \
                      | cut -c69-80`
#          echo "$a1resno $a1chain $a1name ($a1charge) x $a2resno $a2chain $a2name ($a2charge) $overlap $distance"

            # compute repulsion using Coulomb's law
            # NOTE: we are only considering contacting atoms. Other charges
            # may also have an effect
            repulsion=`echo "scale=4 ; $a1charge * $a2charge / ($distance^2)" | bc -l `
            tot=`echo "scale=4 ; $tot + $repulsion" | bc -l`
            # A better calculation might be to run over all atoms
            # and if distance is > H2O-radius, quench the interaction
            # by the dielectric constant of water
            ### Even better would be to know how much of the distance is
            # quenched by water and how much by protein and adjust...
            # Oh, well... maybe one of these days... ### XXX JR XXX ###

            #echo "repulsion=$repulsion"
#          echo "tot=$tot"
            # also save in a file, by overwriting, only the last value is kept
            echo "$base	$tot" > aff/repulsion/${base}.repulsion
        #break
        done
    fi
done

# now, once we have saved separate files, we may simply
cat aff/repulsion/* | sort > $out/repulsion-${R}_${L}.tab
