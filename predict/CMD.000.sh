for i in cabscm* ; do
    name=1ENH			#extraer el nombre
    cm=../../dncon2/$name/out/$name.rr.raw
    cd $i/
    cd $name/
    if [ -e "$name.fasta" ] ; then 
    	sequence=$name.fasta
       	../../script/$i.sh $sequence $cm	#correr CABS
    	cd ../..				#salir de la carpeta
    fi
done 

