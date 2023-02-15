#!/bin/bash

banner split

R=$1
L=$2

comment=''
# this allows inline comments of the form
${comment# whatever (even multiline)}
# while
unset comment
# will allow inline comments of the form
${comment# whatever}
${comment+ whatever
	   (and even multiline comments) }

NUM_PROCS=8
njobs=0

for dir in aff ; do 
    mkdir -p $dir/clean
    mkdir -p $dir/chains 
    for model in $dir/models/*.pdb ; do
        # We will be running this in parallel.
        if (( njobs++ >= NUM_PROCS )); then
            # afterwardws, wait for one to finish before proceeding
            # with the next
            wait -n   # wait for one job to complete. Bash 4.3
            # we could decrease njobs here
        fi

        ( 	# Do everything in a subshell for parallel running
        
        echo $model
        name=`basename $model .pdb`
	# Create clean model
        # Remove MODEL marks (and possibly CONECT) records
	# Add any unassigned HETATM to $L (ligand) chain
	if [ ! -s $dir/clean/$name.pdb ] ; then
	    echo Cleaning $model
            cat $model \
            | sed -e '/^MODEL .*/d' \
        	  -e '/^ENDMDL/d' \
        	  ${comment# -e '/^CONECT /d' }\
        	  -e "/^HETATM/ s/^\(.\{21\}\) /\1$L/g" \
		  -e "/^.\{21\} /d" \
		  -e "/^.\{21\}Z/d" \
            > $dir/clean/$name.pdb 
	fi

	# now work with the clean file
	file=$dir/clean/$name.pdb
        
        # Extract all chains if there are no separate receptor/ligand files
	# if the mol2 files exist, then the PDB ones must also exist
        if [ ! -s $dir/chains/${name}_${R}.mol2 \
	  -o ! -s $dir/chains/${name}_${L}.mol2 ] ; then

	    echo "Splitting $file"
	    # split $file in chains
	    # identify chains and for each existing one
	    for chain in `grep -E "^(ATOM  |HETATM)" $file | \
			  cut -c 22 | \
        		  sort | \
        		  uniq` ; do
        	echo "Extracting chain $chain from $file as ${name}_${chain}.pdb"
		# check we can actually extract that chain
		if ! grep "^.\{21\}$chain" $file > $dir/chains/${name}_${chain}.pdb ; then
        	    echo "ERROR: Something went wrong! Chain ${chain} not extracted"
                    rm -f $dir/chains/${name}_${chain}.pdb
		else
                    # if the chain was successfully extracted
                    # check whether it contains any HETATM to decide which 
                    # charge model to use
		    if grep -q HETATM "$dir/chains/${name}_${chain}.pdb" ; then
		        charge=qtpie	# for drugs
		    else
		        charge=mmff94	# for peptides
		    fi
        	    echo "Converting chain $chain from $file to ${name}_${chain}.mol2"
        	    babel --partialcharge $charge \
        		  -ipdb  $dir/chains/${name}_${chain}.pdb \
        		  -omol2 $dir/chains/${name}_${chain}.mol2
		fi
	    done
        fi
        
        # Now check if R contains more than one chain letter
        # and if so, build a combined file as well
        if [ ${#R} -gt 1 ] ; then
            if [ ! -s $dir/chains/${name}_${R}.mol2 ] ; then
                echo "Building combined receptor ${name}_${R}.(pdb|mol2)"
		# set base commands
                cmd="babel -ipdb  --partialcharge mmff94 "
                cmd2="babel -imol2 --partialcharge mmff94 "
		# for all chain letters in $R add that input chain to the commands
                for (( n=0 ; n < ${#R} ; n++ )); do 
                    chains[n]=${R:n:1}
                    cmd="$cmd $dir/chains/${name}_${R:n:1}.pdb"
                    cmd2="$cmd2 $dir/chains/${name}_${R:n:1}.mol2"
		    if [ ! -s "$dir/chains/${name}_${R:n:1}.pdb" -o \
		         ! -s "$dir/chains/${name}_${R:n:1}.mol2" ] ; then
			echo "ERROR: ONE OR MORE RECEPTOR CHAINS DO NOT EXIST"
		    fi
                done
		# finally add the output file and the join option
                cmd="$cmd -opdb $dir/chains/${name}_${R}.pdb -j"
                cmd2="$cmd2 -omol2 $dir/chains/${name}_${R}.mol2 -j"
                #cho $cmd
                #cho $cmd2
                eval $cmd
                eval $cmd2
            fi
        fi

        # Next check if L contains more than one chain letter
        # and if so, build a combined file as well
        if [ ${#R} -gt 1 ] ; then
            if [ ! -s $dir/chains/${name}_${L}.mol2 ] ; then
                echo "Building combined ligand ${name}_${L}.(pdb|mol2)"
		# set base commands
                cmd="babel -ipdb  --partialcharge mmff94 "
                cmd2="babel -imol2 --partialcharge mmff94 "
		# for all chain letters in $R add that input chain to the commands
                for (( n=0 ; n < ${#L} ; n++ )); do 
                    chains[n]=${L:n:1}
                    cmd="$cmd $dir/chains/${name}_${L:n:1}.pdb"
                    cmd2="$cmd2 $dir/chains/${name}_${L:n:1}.mol2"
		    if [ ! -s "$dir/chains/${name}_${L:n:1}.pdb" -o \
		         ! -s "$dir/chains/${name}_${L:n:1}.mol2" ] ; then
			echo "ERROR: ONE OR MORE LIGAND CHAINS DO NOT EXIST"
		    fi
                done
		# finally add the output file and the join option
                cmd="$cmd -opdb $dir/chains/${name}_${L}.pdb -j"
                cmd2="$cmd2 -omol2 $dir/chains/${name}_${L}.mol2 -j"
                #cho $cmd
                #cho $cmd2
                eval $cmd
                eval $cmd2
            fi
        fi

	# Final sanity check (we check for mol2 since it implies PDB)
        if [ ! -s $dir/chains/${name}_${R}.mol2 ] ; then
            echo "ERROR: Couldn't build receptor $dir/chains/${name}_${R}.(pdb|mol2)"
        fi
        if [ ! -s $dir/chains/${name}_${L}.mol2 ] ; then
            echo "ERROR: Couldn't build ligand $dir/chains/${name}_${R}.(pdb|mol2)"
        fi

        
        ) &	# end of parallel job
        
    done 
done
