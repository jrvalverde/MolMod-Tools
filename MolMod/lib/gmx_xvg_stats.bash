#!/bin/bash
#
# NAME
#	gmx_xvg_stats - desc
#
# SYNOPSIS
#	gmx_xvg_stats [arg] [arg]
#
# DESCRIPTION
#	
#
#
# ARGUMENTS
#	arg	- desc
#
# LICENSE:
#
#	Copyright 2023 JOSE R VALVERDE, CNB/CSIC.
#
#	EUPL
#
#       Licensed under the EUPL, Version 1.1 or \u2013 as soon they
#       will be approved by the European Commission - subsequent
#       versions of the EUPL (the "Licence");
#       You may not use this work except in compliance with the
#       Licence.
#       You may obtain a copy of the Licence at:
#
#       http://ec.europa.eu/idabc/eupl
#
#       Unless required by applicable law or agreed to in
#       writing, software distributed under the Licence is
#       distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#       express or implied.
#       See the Licence for the specific language governing
#       permissions and limitations under the Licence.
#
#	GNU/GPL
#
#       This program is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 3 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


GMX_XVG_STATS="GMX_XVG_STATS"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function average() {
    # calculate average of a one-column list of values (one per line)
    file=${1:-data.txt}

    # add all values in column 1 and divide by count
    awk "{ total += \$1; count++ } END { print total/count }" $file
}


function mean() {
    # calculate mean of a series of datasets:
	#	list	(one number per line, default)
	#	(t)able (first column is number of occurrences, second is value)
	#	(T)able	(first comes the value, seconf the number of occurrences)
	table=0

	## Parse command line otions
	while getopts VtT var
	do
	  case $var in
    	t) table=1;;
    	T) table=2 ;;
    	V) echo $version; exit ;;
	  esac
	done
	shift $(( $OPTIND - 1 ))

	## There are three different awk programs, one for each input format
	if [ $table -eq 0 ]  ## One number per line
	then
	  awk '{ tot += $1 }              ## Add number to the total
    	   END { print tot / NR }  ## Divide total by number of lines
    	  '  ${1+"$@"}
	elif [ $table -eq 1 ]  ## Each line has number of occurrences followed by the number
	then
	  awk '{
    	   num += $2          ## Count total number of occurrences
    	   tot += $1 * $2  ## Total is number multiplied by number of occurrences
    	   }
    	   END {print tot / num }' ${1+"$@"} ## Divide total by number of occurrences
	elif [ $table -eq 2 ]  ## Each line has number followed by the number of occurrences
	then
	  awk '{
    	   num += $1          ## Count total number of occurrences
    	   tot += $1 * $2     ## Total is number multiplied by number of occurrences
    	   }
    	   END { print tot / num }' ${1+"$@"} ## Divide total by number of occurrences
	fi
}

function total() {
    # calculate total of one or more files with lists (one by line) of values
	awk ' ## Add the value of each line to the total
    	  {total += $1}
    	  ## After all the lines have been processed, print the result
	  END {printf "%" prec "f\n", total}' prec=$precision ${1+"$@"}
}

function stdev() {
    # calculate stdev of one or more lists of values
	#	one value per line
	#   one value followed by its count per line
	table=0
	precision=.2

	## Parse command-line options
	while getopts tp: var
	do
	  case $var in
    	  t) table=1 ;;
    	  p) precision=$OPTARG ;;
	  esac
	done
	shift $(( $OPTIND - 1 ))

	if [ $table -eq 0 ]  ## Values input one per line
	then
	  awk '{
        	 tot += $1    ## Add value to total
        	 x[NR] = $1 ## Add value to array for later processing
    	   }
    	   END {
            	 mean = tot / NR  ## Calculate arithmetical mean
            	 tot=0            ## Reset total
            	 for (num in x) {
                	 ## The difference between each number and the mean
                	 diff = x[num] - mean

                	 ## Square difference, multiply by the frequency, and add to total
                	 tot += diff * diff
            	   }
            	   ## Deviation is total divided by number of items
            	   printf "%" precision "f\n", sqrt( tot / NR )
        	   }' precision=$precision ${1+"$@"}
	else  ##
	  awk '{
    	   num += $2
    	   tot += $1 * $2
    	   items += $2
    	   x[NR] = $1
    	   f[NR] = $2
    	   }
    	   END {
            	 mean = tot / num  ## Calculate arithmetical mean
            	 tot=0            ## Reset total
            	 for (num in x) {
                	 ## The difference between each number and the mean
                	 diff = x[num] - mean

                	 ## Square difference, multiply by the frequency, and add to total
                	 tot += diff * diff * f[num]
            	   }
            	   printf "%" precision "f\n", sqrt( tot / items )
        	   }' precision=$precision ${1+"$@"}
	fi


}

function range() {
	column=1

	## Parse command-line options
	while getopts Vn: var
	do
	  case $var in
    	n) column=$OPTARG ;;
	  esac
	done
	shift $(( $OPTIND - 1 ))

	awk 'BEGIN {
    	   ## awk variables are initialized to 0, so we need to
    	   ## give min a value larger than anything is it likely to
    	   ## encounter
    	   min = 999999999999999999 }
    	 {
    	  ++x[$col]
    	  if ( $col > max ) max = $col
    	  if ( $col < min ) min = $col
    	 }
    	 END { print max - min }
	' col=$column ${1+"$@"}
}

function mode() {
	table=0     ## by default the file contains a simple list, not a table

	## Parse the command-line options
	while getopts tT var
	do
	  case $var in
    	  t) table=1 ;;
    	  T) table=2 ;;
	  esac
	done
	shift $(( $OPTIND - 1 ))

	## There are really three separate scripts,
	## one for each configuration of the input file
	if [ $table -eq 0 ]
	then
	  ## The input is a simple list in one column
	  awk '{
    	  ++x[$1]    ## Count the instances of each value
    	  if ( x[$1] > max ) max = x[$1] ## Keep track of which has the most
    	 }
    	 END {
        	if ( max == 1 ) exit ## There is no mode

        	## Print all values with max instances
        	for ( num in x ) if ( x[num] == max ) print num
    	 }' ${1+"$@"}
	elif [ $table -eq 1 ]
	then
	  ## The second column contains the number of instances of
	  ## the value in the first column
	  awk '{  x[$1] += $2  ## Add the number of instances of each value
        	  if ( x[$1] > max ) max = x[$1] ## Keep track of the highest number
    	   }
    	 END {  ## Print the result
        	  if ( max == 1 ) exit
        	  for ( num in x ) if ( x[num] == max ) print num
        	 }' ${1+"$@"}
	elif [ $table -eq 2 ]
	then
	  ## The first column contains the number of instances of
	  ## the value in the second column
	  awk '{  x[$2] += $1
        	  if ( x[$1] > max ) max = x[$2]
    	   }
    	 END {  ## Print the result
        	  if ( max == 1 ) exit
        	  for ( num in x ) if ( x[num] == max ) print num
        	 }' ${1+"$@"}
	fi | sort
}

function median() {
	## Sort the list obtained from one or more files or the standard input
	sort -n ${1+"$@"} |
	  awk '{x[NR] = $1}    ## Store all the values in an array
    	   END {
        	 ## Find the middle number
        	 num = int( (NR + 1) / 2 )

        	 ## If there are an odd number of values
        	 ## use the middle number
        	 if ( NR % 2 == 1 ) print x[num]
        	 ## otherwise average the two middle numbers
        	 else  print (x[num] + x[num + 1]) / 2
    	   }'
}

function gmx_xvg_stats() {
    if ! funusage $# [xvg] [column] ; then return $ERROR ; fi 
    notecont "$*"

    local xvg=${1:-md.xvg}		# XVG file with the data in columns
    local col=${2:-2}			# column to use to calculate the stats
	local xlabel=`grep "@    xaxis  label" $xvg | sed -e 's/.* "//g' | tr -d '"' | tr '_' '+'`
    local legend=`grep "@ s" "$xvg" | while read l ; do l=${l#*legend } ; echo -en "${l}\t"; done`

	
	if [ ! -s "$xvg" ] ; then return 1 ; fi

    if [ ! -s "${xvg%xvg}tab" ] ; then
	    echo -e "\"${xlabel}\"\t$legend" > ${xvg%xvg}tab
	    cat $xvg \
        | grep -v '[#@]' \
	    | grep -v '^$' \
        | sed -e 's/^ \+//g' -e 's/ \+/\t/g' \
        >> ${xvg%xvg}tab
    fi
    
	if [ -s "${xvg%xvg}$col.stat" ] ; then return 0 ; fi # already done
    
	local tmpf=`mktemp`
	cat $xvg \
    | grep -v '[#@]' \
	| grep -v '^$' \
    | sed -e 's/^ \+//g' -e 's/ \+/\t/g' \
    | cut -f $col \
	> $tmpf
	
    # recopile stats
    total=$( cat $tmpf | total - )

    max=$( sort -g $tmpf | tail -1 )
	min=$( sort -g $tmpf | head -1 )

    range=$( cat $tmpf | range - )
	
	count=`wc -l $tmpf | cut -d' ' -f1`
	
    average=$( cat $tmpf | average - )
	
    mean=$( cat $tmpf | mean - )
	
    median=$( cat $tmpf | median - )
	
    mode=$( cat $tmpf | mode - | tr '\n' '\t' )
	
    stdev=$( cat $tmpf | stdev - )
	
	min2sd=`bc -l <<< "${mean^^} - (2 * $stdev)"`
	max2sd=`bc -l <<< "${mean^^} + (2 * $stdev)"`
		
	ci=`bc -l <<< "1.98 * $stdev / sqrt($count)"`
	
    # output stats
    # the '--' line will allow us to separate columnar from tabular data
    # later if we want to
    echo "\
count	$count
total	$total
minim	$min
maxim	$max
range	$range
average	$average
mean	$mean
median	$median
mode	$mode
stdev	$stdev
2*std	$min2sd - $max2sd
ci	$mean ± $ci
--
cnt tot min max range   mean    median  mode    stdev   ci
$count  $total  $min    $max    $range  $mean   $median $mode   $stdev  $ci
" > ${xvg%xvg}$col.stat

    
    rm $tmpf

}


if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program.
    # [[ -v VAR ]] tests if a variable is set
    # [[ -z "$VAR" ]] tests if length of $VAR is zero
    LIB=`dirname $0`
    source $LIB/include.bash
    include util_funcs.bash

    gmx_xvg_stats $*
else
    export GMX_XVG_STATS
fi
