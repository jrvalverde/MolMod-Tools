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


GMX_NDX_DEDUP="GMX_NDX_DEDUP"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function contains() {
    [[ "$1" =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0  || return 1
}


function gmx_ndx_dedup() {

    local md=${1:-md}
    local keep=${2:-last}
    
    local md_ndx=${md}.ndx
    local tmpf=`mktemp`
    
    if [ "$keep" = "first" ] ; then
	# KEEP FIRST DEFINITION
	
	# we can do all at once if we read each line, extracting the name
	# and detecting if it has appeared before, and only produce the line
	# if it hasn't appeared before (i.e. was the first instance); for this
	# we need to save group names in an array or string and search it for 
	# input line

	# change \n to @, insert \n before [ and remove empty lines
	# then check each line to be if it is a duplicate and if not
	# write it out, hence ignoring duplicates, at the end, restore
	# @ to \n
        local GRPS=""
	cat $md_ndx \
	| tr '\n' '@' \
	| sed -e 's/\[/\n\[/g' \
	| sed '/^$/d' \
	| while read line ; do
	    #echo "$line"
	    read s n e <<<"$line"
	    #echo N=$n
	    if contains "$GRPS" "$n" ; then 
        	: #echo "N='$n' has been seen" ; 
	    else 
		GRPS="$GRPS $n "
		echo "$line"
		#echo "new N='$n'" ; 
		#echo "GROUPS=$GRPS"
	    fi
	done \
	| tr '@' '\n' \
	| grep -v '^$' \
	> $tmpf

	mv $tmpf $md_ndx

    elif [ "$keep" = "last" ] ; then
	### KEEP LAST DEFINITION
	
	# change \n to @, insert \n before [ and remove empty lines
	# this wat all the information for each group in in a single line
	cat $md_ndx \
	| tr '\n' '@' \
	| sed -e 's/\[/\n\[/g' \
	| sed '/^$/d' \
	> $tmpf


	# we cannot connect the pipelines because we need the full output
	# to get counts, plus we need a file to edit

	# we can now remove duplicate lines:
	# for each group with a count > 1, remove first line and reduce count
	# until count = 1
	# this has the effect of keeping only the last instance of a group
	cat $tmpf \
	| cut -d' ' -f2 \
	| sort \
	| uniq -c \
	| while read cnt nam ; do     
	    #echo $nam $cnt;     
	    while [ $cnt -gt 1 ] ; do
        	echo $nam $cnt;     
        	sed -i -n "/ $nam /{:a;n;p;ba};p" $tmpf ;
        	cnt=$(( cnt - 1 )) ;
	    done ; 
	    #echo $nam $cnt;     
	done

	# and finally, revert @ to \n
	cat $tmpf | tr '@' '\n' | grep -v '^$' > $md_ndx
	rm $tmpf

    else
        echo "Please, specify if you want to keep 'first' or 'last' definition"
    fi

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

    gmx_ndx_dedup $*
else
    export GMX_NDX_DEDUP
fi
