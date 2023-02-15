mkdir cabscm00cf2apollo
cd cabscm00cf2apollo

for i in ../seq/*.fasta ; do	
    echo "i=$i"
    filename=${i##*/}	#proteinname.fasta
    name=${filename%.*}	#protein name  
    cm=../dncon2/${name}/out/${name}.rr.raw #contact map
    #echo $name
    if [ ! -s "${name}" ] ; then 		#prove if there is already a folder
        #"Creatring ${name}"
    	mkdir -p ${name}			#create a new directory
    	cp ../seq/$filename ${name}/	#copy sequence
	cp ${cm} ${name}/	#copy contact map 
        found=0
        for M in 4 3 2 1 0 ; do		#look for the best confold2 model  
                #echo "    $M"
        	if [ $found -eq 1 ] ; then
           		break
        	fi
                for m in 9 8 7 6 5 4 3 2 1 0 ; do
                        #echo "        $m"
                	refstr=../dncon2/$name/out/confold2-$name.dncon2/top-models/"top-"$M"."$m"L-model-1.pdb"
                        ### NOT THE BEST ONE, THE FIRST ONE ###
			#echo $refstr
                        if [ -e ${refstr} ] ; then 
                        	# confold2 models do not have chain ID
                                # which is needed by CABS
                                #cp "$refstr" $name/dncon2-confold2.pdb
                                cat "${refstr}" \
                                | sed -e '/^ATOM  / s/\(.\{21\}\) /\1A/' \
                                > ${name}/dncon2-confold2.pdb
                                found=1
                                break
                        fi
                done	                       
	done
	cd ${name}
        
        #!/bin/bash

	if [ ! -e "$filename" ] ; then
    		echo "ERROR: sequence $filename does not exist"
    		echo "Usage: cabscm sequence.fasta contactmap.rr5"
    		exit 1
	fi
	if [ ! -e "$cm" ] ; then
    		echo "ERROR: contact map ${name}.cm.rr.raw does not exist"
    		echo "Usage: cabscm sequence.fasta contactmap.rr5"
    		exit 1
	fi


	comment=''
	# this allows inline comments of the form
	${comment# whatever (even multiline)}
	# while this
	unset comment
	# will allow inline comments of the form
	${comment# whatever}
	${comment+ whatever
	   (and even multiline comments) }

	# Generate various starting configurations
	#	we do not know which one may work better

	if [ ! -e helix.pdb ] ; then
    		python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
		-o helix.pdb -a
	fi

	if [ ! -e sheet.pdb ] ; then
    		python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
		-o sheet.pdb -b
	fi

	if [ ! -e coil.pdb ] ; then
    		python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
		-o coil.pdb -c
	fi

	if [ ! -e extended.pdb ] ; then
   		python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
		-o extended.pdb -e
	fi

	# for the next ones we need a secondary structure prediction and a
	# phi-psi angle prediction. We'll get both using our slightly modified
	# ANGLOR which first runs psipred (to get secondary structure predictions
	# and put them in fasta format) and then ANN and SVM to get phi-psi
	# angle predictions
	if [ ! -d anglor ] ; then
   	 ~jr/contrib/anglor/ANGLOR/anglor.pl $filename
	fi

	if [ ! -e ss.pdb ] ; then
  	  # check if anglor generated a ss fasta file
  		if [ -e anglor/seq.ss ] ; then
      	 	 python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
	    	 -o ss.pdb -s anglor/seq.ss
   		fi
	fi

	if [ ! -e pp.pdb ] ; then
   	 if [ -e anglor/seq.ann.phi -a -e anglor/seq.svr.psi ] ; then
        	python3 ${HOME}/work/amelones/script/PepBuild.py -i $filename \
	   	 -o pp.pdb -P anglor/seq.ann.phi -S anglor/seq.svr.psi
   	 fi
	fi

	# Additionally, we might try to use other auxiliary programs to get
	# better starting structures.


	# process each starting configuration in turn using two steps


	for j in *.pdb ; do
    	    	structure=`basename $j .pdb`
    
    	    	# Prepare CA-rest-file
    		# RR 5-column format is AA1 AA2 dist-min(0) dist-max(8) probability
    		# CABS format is AA1 AA2 distance weight
    		# Use with minimal distance
    		cat "$cm"  | cut -f1,2,3,5 -d' ' \
              	 | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
              	 > "$structure.0.crf"
    		# Use with maximal distance
    		cat "$cm"  | cut -f1,2,4,5 -d' ' \
              	 | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
              	 > "$structure.8.crf"
        
    		# carry out first simulation step
    		if [ ! -e "${structure}.done" ] ; then
        		date -u > ${structure}.doing
        		CABSflex 	${comment# use CABSflex -h for help} \
                	 -i ${structure}.pdb \
    	        	 -w ${structure} \
                	 -v 3   ${comment# verbose level (log)} \
                	 -A 	${comment# make all atom models} \
                	 -M 	${comment# make contact map} \
               	 	 -f 1	${comment# 0 fully flexible backbone / 1 stiff bb)}  \
                	 -a 40	${comment# mc-annealing (def: 20)} \
                	 -y 100	${comment# mc-cycles (def: 50)} \
                        	${comment# the trajectory will have 40x100=4000 frames} \
                	 -t 3.5 1.0 ${comment# temperature start end (def: 1.4 1.4)} \
                	 --weighted-fit gauss \
                	 -S 	${comment# save CABS files}\
                	 -C 	${comment# save config} \
               	 	 --ca-rest-file "$structure.0.crf" \
                	 ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
                	 |& tee ${structure}.log 
	        	date -u >> ${structure}.doing
        		if [ ! -s ${structure}/output_pdbs/model_0.pdb ] ; then
           		 mv ${structure}.doing "${structure}.fail"
           		 touch FAIL
        		else
           		 mv ${structure}.doing "${structure}.done"
        		fi
    		fi

    		### XXX JR XXX ###
    		# ESTO NO ESTÁ BIEN
	    	# Estamos escogiendo el primer modelo, pero podría ser mejor otro.
	    	###

	    	# carry out a second simulation step
	    	if [ ! -e "${structure}+.done" ] ; then
	        	if [ ! -s ${structure}/output_pdbs/model_0.pdb ] ; then
	           	 continue
	        	fi
	        	cp ${structure}/output_pdbs/model_0.pdb ${structure}+.pdb
	        	date -u > ${structure}+.doing
	        	CABSflex -i ${structure}+.pdb \
	    	         -w ${structure}+ \
	                 -v 3 \
	                 -A 	${comment# make all atom models} \
	                 -M 	${comment# make contact map} \
	                 -f 1	${comment# 0 fully flexible backbone / 1 stiff bb)}  \
	                 -a 40	${comment# mc-annealing (def: 20)} \
	                 -y 100	${comment# mc-cycles (def: 50)} \
	                 -t 3.5 1.0 ${comment# temperature initial final (def: 1.4 1.4)}\
	                  --weighted-fit gauss \
	                 -S 	${comment# save CABS files}\
	                 -C 	${comment# save config} \
	                 --ca-rest-file "$structure.0.crf" \
	                 ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
	                 |& tee ${structure}+.log 
	        	date -u >> ${structure}+.doing
	        	if [ ! -s ${structure}+/output_pdbs/model_0.pdb ] ; then
	           	 mv ${structure}+.doing "${structure}+.fail"
	           	 touch FAIL
	        	else
	          	 mv ${structure}+.doing "${structure}+.done"
	        	fi
		fi
	done

	if [ ! -e FAIL ] ; then
    		touch DONE
	fi
        
        # Score the models obtained 
        
        if [ ! -e score ] ; then
        	mkdir -p score
                cd score
                for k in ../*/output_pdbs/model*.pdb ; do 
                	ls $k | tr '/' '-'  
                done > ${name}.mlist
                
		cp ../../seq/${name}.fasta .

		~/contrib/multicom_toolbox/apollo_pairwise.64bit/pairwise_qa_apollo \
		    ${name}.fasta \
		    ~/contrib/multicom_toolbox/apollo_pairwise.64bit/tm_score/TMscore_64 \
		    ${name}

		cd ..
        fi
        cd ..
    fi
done

cd ..

