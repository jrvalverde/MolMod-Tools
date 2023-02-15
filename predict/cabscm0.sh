#!/bin/bash

sequence=$1
cm=$2

if [ ! -e "$sequence" ] ; then
    echo "ERROR: sequence $sequence does not exist"
    echo "Usage: cabscm sequence.fasta contactmap.rr5"
    exit 1
fi
if [ ! -e "$cm" ] ; then
    echo "ERROR: contact map $cm does not exist"
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
    python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	-o helix.pdb -a
fi

if [ ! -e sheet.pdb ] ; then
    python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	-o sheet.pdb -b
fi

if [ ! -e coil.pdb ] ; then
    python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	-o coil.pdb -c
fi

if [ ! -e extended.pdb ] ; then
    python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	-o extended.pdb -e
fi

# for the next ones we need a secondary structure prediction and a
# phi-psi angle prediction. We'll get both using our slightly modified
# ANGLOR which first runs psipred (to get secondary structure predictions
# and put them in fasta format) and then ANN and SVM to get phi-psi
# angle predictions
if [ ! -d anglor ] ; then
    ~jr/contrib/anglor/ANGLOR/anglor.pl $sequence
fi

if [ ! -e ss.pdb ] ; then
    # check if anglor generated a ss fasta file
    if [ -e anglor/seq.ss ] ; then
        python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	    -o ss.pdb -s anglor/seq.ss
    fi
fi

if [ ! -e pp.pdb ] ; then
    if [ -e anglor/seq.ann.phi -a -e anglor/seq.svr.psi ] ; then
        python3 ${HOME}/work/amelones/script/PepBuild.py -i $sequence \
	    -o pp.pdb -P anglor/seq.ann.phi -S anglor/seq.svr.psi
    fi
fi

# Additionally, we might try to use other auxiliary programs to get
# better starting structures.


# process each starting configuration in turn using two steps


for i in *.pdb ; do
    name=`basename $i .pdb`
    
    # Prepare CA-rest-file
    # RR 5-column format is AA1 AA2 dist-min(0) dist-max(8) probability
    # CABS format is AA1 AA2 distance weight
    # Use with minimal distance
    cat "$cm"  | cut -f1,2,3,5 -d' ' \
               | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
               > "$name.0.crf"
    # Use with maximal distance
    cat "$cm"  | cut -f1,2,4,5 -d' ' \
               | sed -e 's/^\([0-9]\+\) \([0-9]\+\) /\1:A \2:A /g' \
               > "$name.8.crf"
        
    # carry out first simulation step
    if [ ! -e "${name}.done" ] ; then
        date -u > ${name}.doing
        CABSflex 	${comment# use CABSflex -h for help} \
                 -i ${name}.pdb \
    	         -w ${name} \
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
                 --ca-rest-file "$name.0.crf" \
                 ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
                 |& tee ${name}.log 
        date -u >> ${name}.doing
        if [ ! -s ${name}/output_pdbs/model_0.pdb ] ; then
            mv ${name}.doing "${name}.fail"
        else
            mv ${name}.doing "${name}.done"
        fi
    fi

    ### XXX JR XXX ###
    # ESTO NO ESTÁ BIEN
    # Estamos escogiendo el primer modelo, pero podría ser mejor otro.
    ###

    # carry out a second simulation step
    if [ ! -e "${name}+.done" ] ; then
        if [ ! -s ${name}/output_pdbs/model_0.pdb ] ; then
            continue
        fi
        cp ${name}/output_pdbs/model_0.pdb ${name}+.pdb
        date -u > ${name}+.doing
        CABSflex -i ${name}+.pdb \
    	         -w ${name}+ \
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
                 ${comment# -L YYMMDDhhmmssfile.cbs (load CABS file)} \
                 |& tee ${name}+.log 
        date -u >> ${name}+.doing
        if [ ! -s ${name}+/output_pdbs/model_0.pdb ] ; then
            mv ${name}+.doing "${name}+.fail"
        else
            mv ${name}+.doing "${name}+.done"
        fi
    fi
done

