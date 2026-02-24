fgnuplot_xvg_plot() {
	local file=${1:-md_complex_rmsd.xvg}

	local title=`grep "@    title" $file | sed -e 's/.* "//g' | tr  -d '"' | tr '_' '+'`
	local xlabel=`grep "@    xaxis  label" $file | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local ylabel=`grep "@    yaxis  label" $file | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local legend=`grep "@ s0 legend" $file | sed -e 's/@ s0 legend//g' | tr -d '"' | tr '_' '+'`
	local subtitle=`grep "@ subtitle" $file | sed -e 's/@ subtitle //g' | tr -d '"' | tr '_' '+'`

	if [ "$legend" = "subtitle" ] ; then
    	legend=$subtitle
	else
    	title="$title: $subtitle"
	fi
	#echo "$title"
	#echo "$subtitle"
	#echo "$legend"
	#echo "$xlabel"
	#echo "$ylabel"

	# consider using --dataid --autolegend for multicolumn files
	# inserting legends as first row.
	
	# svg
	grep -v "^[#@]" $file \
	| feedgnuplot --domain \
            	  --lines \
				  --title "$title" \
				  --xlabel "$xlabel" \
				  --ylabel "$ylabel" \
				  --legend 0 "$legend" \
				  --hardcopy "${file%xvg}svg" \
            	  --terminal "svg size 1536,1024 dynamic"
				  
	# png
	grep -v "^[#@]" $file \
	| feedgnuplot --domain \
            	  --lines \
				  --title "$title" \
				  --xlabel "$xlabel" \
				  --ylabel "$ylabel" \
				  --legend 0 "$legend" \
				  --hardcopy "${file%xvg}png" \
            	  --terminal "pngcairo size 1536,1024 background \"white\""

	# pdf A4 landscape (297x210mm, 11.69x8.27in)
	grep -v "^[#@]" $file \
	| feedgnuplot --domain \
            	  --lines \
				  --title "$title" \
				  --xlabel "$xlabel" \
				  --ylabel "$ylabel" \
				  --legend 0 "$legend" \
				  --hardcopy "${file%xvg}pdf" \
            	  --terminal "pdfcairo size 11.69,8.27 background \"white\""

}

fgnuplot_xvg_plot $*
