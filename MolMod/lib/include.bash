#!/bin/bash
#
# AUTHOR
#	José R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es, 2014
#
#	Licensed under (at your option) either GNU/GPL or EUPL
#
# LICENSE:
#
#	Copyright 2014 JOSE R VALVERDE, CNB/CSIC.
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
INCLUDE='INCLUDE'
TRUE=${TRUE:-0}
FALSE=${FALSE:-1}
#
OK=${OK:-0}
ERROR=${ERROR:-1}
#
VERBOSE=${VERBOSE:-0}	# default value for verbose *level*
DEBUG=${DEBUG:-1}

# check if include already exists as a function
if declare -f -F include >/dev/null ; then return ; fi

#ignored, superseeded by later redefinition
# function include() {
#     if [ $# -lt 1 ] ; then echo "Err: ${FUNCNAME[0]} includefile" ; exit 1 
#     else echo ">>> ${FUNCNAME[0]}" $* ; fi
#     
#     while [ $# -gt 0 ] ; do
#         if [ ! -s "$1" ] ; then
#             echo "Warning ${FUNCNAME[0]}: '$1' does not exist or is empty!"
#         else
#             if [ -z $"$1" ] ; then
# 	        source $1.bash
# 	    fi
# 	    if [ $? -ne 0 ] ; then
# 	        echo ">>> ERROR (include): could not source" $*
# 		exit
# 	    fi
# 	    "$1"='ok'
#         fi
#         shift
#     done
# }
# 
function include() {
    # we expect the name of a bash file
    # if it has been included, a variable with the same name in capitals
    # must exist
    if  [ $# != 1 ] ; then echo "error: include file.bash" ; return $ERROR ; fi
    
    local file=$1
    #local name=`basename $file`    # possibly less efficient than
    local name=${file##*/}          # remove any leading path elements
    local NAME=${name%.bash}		# remove .bash from the end
    local NAME=${NAME^^}            # convert to all caps
    [[ -v ${!NAME} ]] && return     # do not include a file twice 

    local BASE=${BASE:-}            # use global BASE or leave empty
    #local BASE=`dirname $file`      # find location (won't honor a global BASE)
    
    # we need to distinguish an explicit "./file" from an implicit "file"
    # as in both cases dirname will rerturn '.'
    # if no path was explicitly specified then keep BASE (global or empty)
    if [[ "$file" ==  */* ]] ; then BASE="${file%/*}" ; fi 
    
    # if the include directory is empty (i.e. not specified and not global), 
    # then look up BASE in our own (include.bash) directory
    if [ "$BASE" = '' ] ; then
        # no directory has been specified
        BASE=`dirname ${BASH_SOURCE[0]}`
    fi
    # look for the include file in predefined locations
    if [ -s "$BASE/$name" ] ; then
        incfile="$BASE/$name"		# it is in the same directory as us
    elif [ -s "$BASE/lib/$name" ] ; then
        incfile="$BASE/lib/$name"	# it is in a subdirectory called 'lib'
    elif [ -s "$BASE/include/$name" ] ; then
        incfile="$BASE/include/$name"	# it is in an 'include' subdirectory
    else
        echo "ERROR: NO $BASE/$name $BASE/lib/$name $BASE/include/$name found!" ; 
        return $ERROR ;
    fi
    #echo "Checking $NAME: ${!NAME}"
    [[ -z ${!NAME} ]] && source "$incfile"
    # in case the included script does not define its inclusion, we will
    [[ -z ${!NAME} ]] && export $NAME="$NAME"
    return $OK
}

#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # catch signals (see kill -L)
    # INT QUIT KILL ABRT BUS KILL PIPE TERM
    # note that CHLD will make this test fail
    trap 'rm -f "$TMPFILE"' 2 3 4 6 7 9 13 15 
    
    # test we do indeed source a file
    TMPFILE=$( mktemp TESTXXXXX --suffix=.bash ) || exit 1
    echo $TMPFILE
    echo "echo OK from $TMPFILE" > $TMPFILE
    BASE=/no include $TMPFILE    # this should not find TMPFILE
    include ./$TMPFILE  # this being implicit should work
    include ./$TMPFILE  # this should NOT exec TMPFILE a second time
    rm $TMPFILE
fi
