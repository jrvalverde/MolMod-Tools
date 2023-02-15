#!/bin/bash

banner split

R=$1
L=$2

NUM_PROCS=8
NUM_PROCS=1
chimera=`which chimera`
method="chimera"

comment=''
# this allows inline comments of the form
${comment# whatever (even multiline)}
# while
unset comment
# will allow inline comments of the form
${comment# whatever}
${comment+ whatever
	   (and even multiline comments) }

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

        ( 	# Do everything in a subshell for parallel execution
        
        echo $model
        name=`basename $model .pdb`
	# Create clean model
        # Remove MODEL/ENDMDL marks (and possibly CONECT) records
        # Remove unassigned ( ) and solvent(Z) ATOMs
	# Add all HETATM to $L (ligand) chain
        # THIS SHOULD NOT BE NEEDED. SEE pdb-rename_chain.sh,
        # pdb_fix_ligand.sh and fixmodels.sh
	if [ ! -s $dir/clean/$name.pdb ] ; then
	    echo Cleaning $model
            cat $model \
            | sed -e '/^MODEL .*/d' \
        	  -e '/^ENDMDL/d' \
		  -e "/^ATOM  .\{15\} /d" \
		  -e "/^ATOM  .\{15\}Z/d" \
        	  -e "/^HETATM/ s/^\(.\{21\}\)./\1$L/g" \
        	  ${comment# -e '/^CONECT /d' } \
            > $dir/clean/$name.pdb 
	fi

	# now work with the clean file
	file=$dir/clean/$name.pdb
        
        # Extract all chains
	echo "Splitting $file in component chains"
	# split $file in all its component chains
	# identify chains and, for each existing one, extract it
	for chain in `grep -E "^(ATOM  |HETATM)" $file | \
		      cut -c 22 | \
        	      sort | \
        	      uniq` ; do
            # first get it as PDB
            if [ ! -s $dir/chains/${name}_${chain}.pdb ] ; then
        	echo "Extracting chain $chain from $file as ${name}_${chain}.pdb"
		if [ "$method" == "shell" ] ; then
                    # check we can actually extract that chain
		    if ! grep "^.\{21\}$chain" $file > $dir/chains/${name}_${chain}.pdb ; then
                        echo "ERROR: HORROR"
        	        echo "ERROR: Something went wrong! Chain ${chain} not extracted"
                        echo "ERROR; HORROR"
                        rm -f $dir/chains/${name}_${chain}.pdb
                        continue
		    fi
                elif [ "$method" == "chimera" ] ; then
		    DISPLAY='' $chimera --nogui <<END
                        open $file
                        # this shuld not be needed
                        #addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
                        # the next is too costly (due to AM1) so we mat prefer 
                        # to use babel instead to assign charges
                        #addcharge all chargeModel 99sb method am1
                        sel #0:*.${chain}
                        write selected format pdb 0 ${dir}/chains/${name}_${chain}.pdb
                        write selected format mol2 0 ${dir}/chains/${name}_${chain}.mol2
END
		    # check it worked
                    if [ ! -s ${dir}/chains/${name}_${chain}.pdb ] ; then
                        echo "ERROR: HORROR"
        	        echo "ERROR: Something went wrong! Chain ${chain} not extracted"
                        echo "ERROR; HORROR"
                        rm -f $dir/chains/${name}_${chain}.pdb
                        rm -f $dir/chains/${name}_${chain}.mol2
                        continue
                    fi
                fi
            fi
            # Now, create the MOL2 files with charges
            # if the chain was successfully extracted
            # check whether it contains any HETATM to decide which 
            # charge model to use
            if [ ! -s $dir/chains/${name}_${chain}.mol2 ] ; then
		if grep -q HETATM "$dir/chains/${name}_${chain}.pdb" ; then
		    charge="--partialcharge qtpie"	# for drugs
		else
		    charge=""	# for peptides
		fi
        	echo "Converting chain $chain from $file to ${name}_${chain}.mol2"
        	echo "babel $charge \
        	      -ipdb  $dir/chains/${name}_${chain}.pdb \
        	      -omol2 \
                      -O     $dir/chains/${name}_${chain}.mol2"
        	babel $charge \
        	      -ipdb  $dir/chains/${name}_${chain}.pdb \
        	      -omol2 \
                      -O     $dir/chains/${name}_${chain}.mol2
            fi
	done
        
        # Now check if $R contains more than one chain letter
        # and if so, build a combined file as well
        if [ ${#R} -gt 1 ] ; then
            if [ ! -s $dir/chains/${name}_${R}.mol2 ] ; then
              echo "Building combined receptor ${name}_${R}.(pdb|mol2)"
              if [ "YES" == "YES" ] ; then
                for (( n=0 ; n < ${#R} ; n++ )); do 
		    if [ ! -s "$dir/chains/${name}_${R:n:1}.pdb" -o \
		         ! -s "$dir/chains/${name}_${R:n:1}.mol2" ] ; then
			echo "ERROR: ONE OR MORE RECEPTOR CHAINS DO NOT EXIST"
		    fi
                done
                # this is the simplest way
                babel -ipdb $dir/chains/${name}_[$R].pdb \
                      -opdb -O $dir/chains/${name}_$R.pdb
                babel --partialcharge mmff94 \
                      -imol2 $dir/chains/${name}_[$R].mol2 \
                      -omol2 -O $dir/chains/${name}_$R.mol2
              else
                # This is too convoluted 
                ### JR ### to be removed eventually
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
                cmd="$cmd -opdb -O $dir/chains/${name}_${R}.pdb -j"
                cmd2="$cmd2 -omol2 -O $dir/chains/${name}_${R}.mol2 -j"
                echo "**************"
                echo $cmd
                echo $cmd2
                echo "**************"
                eval $cmd
                eval $cmd2
              fi
            fi
        fi

        # Next check if L contains more than one chain letter
        # and if so, build a combined file as well
        if [ ${#L} -gt 1 ] ; then
            if [ ! -s $dir/chains/${name}_${L}.mol2 ] ; then
                echo "Building combined ligand ${name}_${L}.(pdb|mol2)"
              if [ "YES" == "YES" ] ; then
                for (( n=0 ; n < ${#R} ; n++ )); do 
		    if [ ! -s "$dir/chains/${name}_${L:n:1}.pdb" -o \
		         ! -s "$dir/chains/${name}_${L:n:1}.mol2" ] ; then
			echo "ERROR: ONE OR MORE LIGAND CHAINS DO NOT EXIST"
		    fi
                done
                # this is the simplest way
                babel -ipdb $dir/chains/${name}_[$L].pdb \
                      -opdb -O $dir/chains/${name}_$L.pdb
                babel --partialcharge mmff94 \
                      -imol2 $dir/chains/${name}_[$L].mol2 \
                      -omol2 -O $dir/chains/${name}_$L.mol2
              else
                # This is too convoluted 
                ### JR ### to be removed eventually
		# set base commands
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
        fi

	# Final sanity checks (we check for mol2 since it implies PDB)

        if [ ! -s $dir/chains/${name}_${R}.mol2 ] ; then
            echo "ERROR: Couldn't build receptor $dir/chains/${name}_${R}.(pdb|mol2)"
        fi
        if [ ! -s $dir/chains/${name}_${L}.mol2 ] ; then
            echo "ERROR: Couldn't build ligand $dir/chains/${name}_${L}.(pdb|mol2)"
        fi

        
        ) &	# end of parallel job
        
    done 
done
