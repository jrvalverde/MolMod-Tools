#!/bin/bash

FGP_XVG_PLOT="FGP_XVG_PLOT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include gmx_setup_cmds.bash


feedgnuplot_xvg_plot() {
	local file=${1:-md_complex_rmsd.xvg}
	local format=${2:-all}

    # this is highly inefficient, but we don't care because files
    # are small and will be cached so re-reading them is fast enough
	local title=`grep "@    title" $file | sed -e 's/.* "//g' | tr  -d '"' | tr '_' '+'`
	local xlabel=`grep "@    xaxis  label" $file | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local ylabel=`grep "@    yaxis  label" $file | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local legend=`grep "@ s0 legend" $file | sed -e 's/@ s0 legend//g' | tr -d '"' | tr '_' '+'`
	local lgndopt=`grep "@ s" "$file" | while read l ; do l=${l/legend /} ; echo -n "--legend ${l#@ s} "; done`
	local subtitle=`grep "@ subtitle" $file | sed -e 's/@ subtitle //g' | tr -d '"' | tr '_' '+'`

	if [ "$legend" = "" ] ; then
    	legend=$subtitle
	else
    	title="$title: $subtitle"
	fi
	#echo "$title"
	#echo "$subtitle"
	#echo "$legend"
	#echo "$xlabel"
	#echo "$ylabel"

	# consider using --autolegend for multicolumn files
	# or inserting legends as first row.
	#echo $format
	if [ "$format" = "all" -o "$format" = "svg" -a ! -s "${file%xvg}svg" ] ; then
	    if [ ! -s "${file%xvg}svg" ] ; then
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
        fi
	fi				  
	if [ "$format" = "all" -o "$format" = "png" -a ! -s "${file%xvg}png" ] ; then
	    if [ ! -s "${file%xvg}png" ] ; then
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
        fi
	fi
	if [ "$format" = "all" -o "$format" = "pdf" -a ! -s "${file%xvg}pdf" ] ; then
	    if [ ! -s "${file%xvg}pdf" ] ; then
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
        fi
    fi
}


function fgp_xvg_plot_nxy() {
# some xvg files contain more than one XY plot, in this case,
# s0 .. sN-1 are the legends and the values are columnated after each X
# we can retrieve the N labels as a series of options and use these
# to label the plot
# then, the case of only one column (a simple XY plot) becomes a special
# case of this and the same function can be used for both kinds of XVG
# files
    local file=${1:-md_complex_rmsd.xvg}
	local format=${2:-all}

    # this is highly inefficient, but we don't care because files
    # are small and will be cached so re-reading them is fast enough
	local title=`grep "@    title" "$file" | sed -e 's/.* "//g' | tr  -d '"' | tr '_' '+'`
	local xlabel=`grep "@    xaxis  label" "$file" | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local ylabel=`grep "@    yaxis  label" "$file" | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
	local lgndopt=`grep "@ s" "$file" | while read l ; do l=${l/legend /} ; echo -n "--legend ${l#@ s} "; done`
    #lgndopt=${lgndopt//\"/}
	local subtitle=`grep "@ subtitle" "$file" | sed -e 's/@ subtitle //g' | tr -d '"' | tr '_' '+'`
    
    #echo -e "t=$title\nst=$subtitle\nx=$xlabel\ny=$ylabel\nl=$lgndopt\n"
    
    # we can't use a generic loop because size units vary for different devices
	if [ "$format" = "all" -o "$format" = "svg" -a ! -s "${file%xvg}svg" ] ; then
	    if [ ! -s "${file%xvg}svg" ] ; then
			# svg
            lgndopt=${lgndopt//\"/\'}
            command="grep -v '^[#@]' $file \
            | feedgnuplot --domain \
                         --lines \
                         --title '$title' \
                         --xlabel '$xlabel' \
                         --ylabel '$ylabel' \
                         $lgndopt \
                         --hardcopy '${file%xvg}svg' \
                         --terminal 'svg size 1536,1024 dynamic'"
                          
            #echo "$command"
            eval $command
        fi
	fi				  
	if [ "$format" = "all" -o "$format" = "png" -a ! -s "${file%xvg}png" ] ; then
	    if [ ! -s "${file%xvg}png" ] ; then
			# png
			command="grep -v \"^[#@]\" $file \
                    | feedgnuplot --domain \
                        --lines \
                        --title \"$title\" \
                        --xlabel \"$xlabel\" \
                        --ylabel \"$ylabel\" \
                        $lgndopt \
                        --hardcopy \"${file%xvg}png\" \
                        --terminal \"pngcairo size 1536,1024 background \\\"white\\\"\""

            #echo "$command"
            eval $command
        fi
	fi
	if [ "$format" = "all" -o "$format" = "pdf" -a ! -s "${file%xvg}pdf" ] ; then
	    if [ ! -s "${file%xvg}pdf" ] ; then
			# pdf A4 landscape (297x210mm, 11.69x8.27in)
            lgndopt=${lgndopt//\"/\'}
			command="grep -v '^[#@]' $file \
			| feedgnuplot --domain \
            			  --lines \
						  --title '$title' \
						  --xlabel '$xlabel' \
						  --ylabel '$ylabel' \
						  $lgndopt \
						  --hardcopy '${file%xvg}pdf' \
            			  --terminal 'pdfcairo size 11.69,8.27 background \"white\"'"
            #echo "$command"
            eval $command
        fi
    fi
}

function fgp_xvg_plot() {
    fgp_xvg_plot_nxy "$@"
}

if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    # [[ -v VAR ]] tests if a variable is set
    # [[ -z "$VAR" ]] tests if length of $VAR is zero
    LIB=`dirname $0`
    source $LIB/include.bash
    include util_funcs.bash
    include gmx_setup_cmds.bash

   fgp_xvg_plot $@
else
    export FGP_XVG_PLOT
fi
