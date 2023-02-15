#
#	Utility functions
#
# AUTHOR(S)
#	All  code is
#		(C) José R. Valverde, CNB/CSIC. jrvalverde@cnb.csic.es 2014
#	and
#		Licensed under (at your option) either GNU/GPL or EUPL
#	UNLESS OTHERWISE INDICATED 
#
#
# LICENSE:
#
#	Copyright 2014 JOSÉ R VALVERDE, CNB/CSIC.
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

UTIL_FUNCS='UTIL_FUNCS'
TRUE=0
FALSE=1
#
OK=0
ERROR=1
#
VERBOSE=${VERBOSE:-0}	# default value for verbose *level*

bold=`tput bold`
plain=`tput sgr0`
black=`tput setaf 0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
cyan=`tput setaf 6`
lightgray=`tput setaf 7`

# these do not work in non-interactive (script) mode
#	use "echo $colormode" instead
#alias bold=`tput bold`
#alias plain=`tput sgr0`
#alias black=`tput setaf 0`
#alias red=`tput setaf 1`
#alias green=`tput setaf 2`
#alias yellow=`tput setaf 3`
#alias blue=`tput setaf 4`
#alias magenta=`tput setaf 5`
#alias cyan=`tput setaf 6`
#alias lightgray=`tput setaf 7`

# print a message in blod-blue text
function boldblue() {
    echo -n "$bold$(tput setaf 4) "
    echo    "$*"
    echo -n "$(tput setaf 0)$plain"
}

# print a message in bold-red text
function boldred() {
    echo -n "$bold$(tput setaf 1)"
    echo    "$*"
    echo -n "$(tput setaf 0)$plain"
}


function banner() {
    #
    # Taken from http://stackoverflow.com/questions/652517/whats-the-deal-with-the-banner-command
    #
    #	Msg by jlliagre
    #		Apr 15 '12 at 11:52
    #
    # ### JR ###
    #	Input:	A text up to 10 letter wide
    # This has been included because banner(1) is no longer a standard
    # tool in many Linux systems. This way we avoid having a dependency
    # that might not be met.
    # It is often installed through package 'sysvbanner'
    #	npm has an ascii-banner tool (npm -g install ascii-banner)
    # Other alternatives are toilet(1) and figlet(1)

    typeset A=$((1<<0))
    typeset B=$((1<<1))
    typeset C=$((1<<2))
    typeset D=$((1<<3))
    typeset E=$((1<<4))
    typeset F=$((1<<5))
    typeset G=$((1<<6))
    typeset H=$((1<<7))

    function outLine()
    {
      typeset r=0 scan
      for scan
      do
        typeset l=${#scan}
        typeset line=0
        for ((p=0; p<l; p++))
        do
          line="$((line+${scan:$p:1}))"
        done
        for ((column=0; column<8; column++))
          do
            [[ $((line & (1<<column))) == 0 ]] && n=" " || n="#"
            raw[r]="${raw[r]}$n"
          done
          r=$((r+1))
        done
    }

    function outChar()
    {
        case "$1" in
        (" ") outLine "" "" "" "" "" "" "" "" ;;
        ("0") outLine "BCDEF" "AFG" "AEG" "ADG" "ACG" "ABG" "BCDEF" "" ;;
        ("1") outLine "F" "EF" "F" "F" "F" "F" "F" "" ;;
        ("2") outLine "BCDEF" "AG" "G" "CDEF" "B" "A" "ABCDEFG" "" ;;
        ("3") outLine "BCDEF" "AG" "G" "CDEF" "G" "AG" "BCDEF" "" ;;
        ("4") outLine "AF" "AF" "AF" "BCDEFG" "F" "F" "F" "" ;;
        ("5") outLine "ABCDEFG" "A" "A" "ABCDEF" "G" "AG" "BCDEF" "" ;;
        ("6") outLine "BCDEF" "A" "A" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("7") outLine "BCDEFG" "G" "F" "E" "D" "C" "B" "" ;;
        ("8") outLine "BCDEF" "AG" "AG" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("9") outLine "BCDEF" "AG" "AG" "BCDEF" "G" "G" "BCDEF" "" ;;
        ("a") outLine "" "" "BCDE" "F" "BCDEF" "AF" "BCDEG" "" ;;
        ("b") outLine "B" "B" "BCDEF" "BG" "BG" "BG" "ACDEF" "" ;;
        ("c") outLine "" "" "CDE" "BF" "A" "BF" "CDE" "" ;;
        ("d") outLine "F" "F" "BCDEF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("e") outLine "" "" "BCDE" "AF" "ABCDEF" "A" "BCDE" "" ;;
        ("f") outLine "CDE" "B" "B" "ABCD" "B" "B" "B" "" ;;
        ("g") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "BCDE" ;;
        ("h") outLine "B" "B" "BCDE" "BF" "BF" "BF" "ABF" "" ;;
        ("i") outLine "C" "" "BC" "C" "C" "C" "ABCDE" "" ;;
        ("j") outLine "D" "" "CD" "D" "D" "D" "AD" "BC" ;;
        ("k") outLine "B" "BE" "BD" "BC" "BD" "BE" "ABEF" "" ;;
        ("l") outLine "AB" "B" "B" "B" "B" "B" "ABC" "" ;;
        ("m") outLine "" "" "ACEF" "ABDG" "ADG" "ADG" "ADG" "" ;;
        ("n") outLine "" "" "BDE" "BCF" "BF" "BF" "BF" "" ;;
        ("o") outLine "" "" "BCDE" "AF" "AF" "AF" "BCDE" "" ;;
        ("p") outLine "" "" "ABCDE" "BF" "BF" "BCDE" "B" "AB" ;;
        ("q") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "FG" ;;
        ("r") outLine "" "" "ABDE" "BCF" "B" "B" "AB" "" ;;
        ("s") outLine "" "" "BCDE" "A" "BCDE" "F" "ABCDE" "" ;;
        ("t") outLine "C" "C" "ABCDE" "C" "C" "C" "DE" "" ;;
        ("u") outLine "" "" "AF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("v") outLine "" "" "AG" "BF" "BF" "CE" "D" "" ;;
        ("w") outLine "" "" "AG" "AG" "ADG" "ADG" "BCEF" "" ;;
        ("x") outLine "" "" "AF" "BE" "CD" "BE" "AF" "" ;;
        ("y") outLine "" "" "BF" "BF" "BF" "CDE" "E" "BCD" ;;
        ("z") outLine "" "" "ABCDEF" "E" "D" "C" "BCDEFG" "" ;;
        ("A") outLine "D" "CE" "BF" "AG" "ABCDEFG" "AG" "AG" "" ;;
        ("B") outLine "ABCDE" "AF" "AF" "ABCDE" "AF" "AF" "ABCDE" "" ;;
        ("C") outLine "CDE" "BF" "A" "A" "A" "BF" "CDE" "" ;;
        ("D") outLine "ABCD" "AE" "AF" "AF" "AF" "AE" "ABCD" "" ;;
        ("E") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "ABCDEF" "" ;;
        ("F") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "A" "" ;;
        ("G") outLine "CDE" "BF" "A" "A" "AEFG" "BFG" "CDEG" "" ;;
        ("H") outLine "AG" "AG" "AG" "ABCDEFG" "AG" "AG" "AG" "" ;;
        ("I") outLine "ABCDE" "C" "C" "C" "C" "C" "ABCDE" "" ;;
        ("J") outLine "BCDEF" "D" "D" "D" "D" "BD" "C" "" ;;
        ("K") outLine "AF" "AE" "AD" "ABC" "AD" "AE" "AF" "" ;;
        ("L") outLine "A" "A" "A" "A" "A" "A" "ABCDEF" "" ;;
        ("M") outLine "ABFG" "ACEG" "ADG" "AG" "AG" "AG" "AG" "" ;;
        ("N") outLine "AG" "ABG" "ACG" "ADG" "AEG" "AFG" "AG" "" ;;
        ("O") outLine "CDE" "BF" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("P") outLine "ABCDE" "AF" "AF" "ABCDE" "A" "A" "A" "" ;;
        ("Q") outLine "CDE" "BF" "AG" "AG" "ACG" "BDF" "CDE" "FG" ;;
        ("R") outLine "ABCD" "AE" "AE" "ABCD" "AE" "AF" "AF" "" ;;
        ("S") outLine "CDE" "BF" "C" "D" "E" "BF" "CDE" "" ;;
        ("T") outLine "ABCDEFG" "D" "D" "D" "D" "D" "D" "" ;;
        ("U") outLine "AG" "AG" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("V") outLine "AG" "AG" "BF" "BF" "CE" "CE" "D" "" ;;
        ("W") outLine "AG" "AG" "AG" "AG" "ADG" "ACEG" "BF" "" ;;
        ("X") outLine "AG" "AG" "BF" "CDE" "BF" "AG" "AG" "" ;;
        ("Y") outLine "AG" "AG" "BF" "CE" "D" "D" "D" "" ;;
        ("Z") outLine "ABCDEFG" "F" "E" "D" "C" "B" "ABCDEFG" "" ;;
        (".") outLine "" "" "" "" "" "" "D" "" ;;
        (",") outLine "" "" "" "" "" "E" "E" "D" ;;
        (":") outLine "" "" "" "" "D" "" "D" "" ;;
        ("!") outLine "D" "D" "D" "D" "D" "" "D" "" ;;
        ("/") outLine "G" "F" "E" "D" "C" "B" "A" "" ;;
        ("\\") outLine "A" "B" "C" "D" "E" "F" "G" "" ;;
        ("|") outLine "D" "D" "D" "D" "D" "D" "D" "D" ;;
        ("+") outLine "" "D" "D" "BCDEF" "D" "D" "" "" ;;
        ("-") outLine "" "" "" "BCDEF" "" "" "" "" ;;
        ("*") outLine "" "BDF" "CDE" "D" "CDE" "BDF" "" "" ;;
        ("=") outLine "" "" "BCDEF" "" "BCDEF" "" "" "" ;;
        (*) outLine "ABCDEFGH" "AH" "AH" "AH" "AH" "AH" "AH" "ABCDEFGH" ;;
        esac
    }

    function outArg()
    {
      typeset l=${#1} c r
      for ((c=0; c<l; c++))
      do
        outChar "${1:$c:1}"
      done
      echo
      for ((r=0; r<8; r++))
      do
        printf "%-*.*s\n" "${COLUMNS:-80}" "${COLUMNS:-80}" "${raw[r]}"
        raw[r]=""
      done
    }

    for i
    do
      outArg "$i"
      echo
    done
}


function redirect_std_out_err() {
    # This function provides two ways to collect logs:
    #    A default method that is always active and redirects both
    # standard output and error to a (possibly specified) log file
    #	 A LOG global variable that can be used to reditect output and error
    # streams of specific commands.
    #    It takes and output log directory and, optionally a log file
    # name root. The global log will go into logdir/logfilename.std and
    # command-specific streams will be appended to logdir/logfilename.{out| err}

    if [ $# -lt 1 ] ; then errexit "logdir [logfile]" 
    else notecont $* ; fi

    local log_folder=${1:-log}
    log_folder=`abspath $log_folder`

    # use a single log file, backing it up to an increasing count if one
    # already exists.
    #
    local myname=`basename "${BASH_SOURCE[0]}"`
    local log=${2:-log.$myname}

    if [ -e $log_folder ] ; then 
        if [ ! -d $log_folder ] ; then errexit "$log_folder exists and is not a directory" ; fi
    fi
    mkdir -p $log_folder 

    version_file $log_folder/$log
    # the following two variables are used in (non-)verbose mode to
    # additionally redirect output to specific files
    #
    #	OUTDATED NOTE:
    #	The idea is that whenever we want to run a command that
    #	outputs too much detail, we want to redirect it to separate
    #	files unless VERBOSE is chosen
    #	For this to work, commands must be run with "eval cmd $LOG"
    #	so that normally it would be ignored. After we define for LOG a
    #	different value here, all commands will use this value because
    #	the original definition of LOG in {parent-source}.bash must have taken
    #	place before this one (on initialization) and is superseded by this.
    #	If we do not re-define LOG, then {parent-source} will work as if it
    #	did not exist.
    #
    if [ ! -e $log_folder/$log.out ] ; then touch $log_folder/$log.out ; fi
    if [ ! -e $log_folder/$log.err ] ; then touch $log_folder/$log.err ; fi
    local stdout=$log_folder/$log.out 
    local stderr=$log_folder/$log.err
    version_file $stdout
    version_file $stderr
    if [ $VERBOSE -eq 0 ] ; then
	LOG=">>$stdout 2>>$stderr"
        exec > $log_folder/$log.std 2>&1
    else
	#LOG="| tee -a $stdout 2| tee -a $stderr"
        LOG="> >(tee ${stdout}) 2> >(tee ${stderr} >&2)"
        exec |& tee $log_folder/$log.std
    fi

}

# check if a function exists (useful, e.g. to avoid redefinitions)
# use as, for instance
#    function_exists funcname && echo YES || echo NO
# or
#    if function_exists funcname ; then return ; fi
function function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

function notecont() {
    if [ $# -lt 1 ] ; then 
        echo -e ">>> ERROR (${FUNCNAME[0]}): note_message" 
	exit 1 
    fi
    
    local VERBOSE=${VERBOSE:-1}		# set default for global $VERBOSE (SHOULD BE 0)
    local LONG_OUTPUT=${LONG_OUTPUT:-0}	# set default to short output
    
    if [ "$VERBOSE" -eq 0 ] ; then return $OK ; fi
    if [ -v "$LONG_OUTPUT" ] ; then echo "" ; fi
    if [ -t 1 ] ; then
        # Enable interpretation of \ to allow \n (but requiring \\)
        echo -e "${green}NOTICE (${FUNCNAME[1]}):" $* "${plain}"
    else
        echo -e "NOTICE (${FUNCNAME[1]}):" $* 
    fi
    if [ -v $LONG_OUTPUT ] ; then echo "" ; fi
    return $OK
}

# print a warning message in bold-blue (unless output is redirected) 
# and continue
# e.g.
#    warning "[line $LINENO]" we are going to call the police
function warncont() {
    if [ $# -lt 1 ] ; then 
        echo "ERROR: ${FUNCNAME[0]} warning message" 
	exit 1 
    fi
    if [ -v $LONG_OUTPUT ] ; then echo "" ; fi
    if [ -t 1 ] ; then
        echo -n "$bold$blue"
        echo "WARNING (${FUNCNAME[1]}):" $*
        echo -n "$plain"
    else
        echo ">>> WARNING (${FUNCNAME[1]}):" $*
    fi
    if [ -v $LONG_OUTPUT ] ; then echo "" ; fi
    return $OK
}

#
# Print an error message and an optional stack trace (see below for other
# possible traceback functions). The error goes to stderr (file descriptor 2)
# AND EXIT
#
function errexit() {
    if [ $# -ne 1 ] ; then 
        echo "ERROR: ${FUNCNAME[0]} error message" 
	# use exit only if we are in a non-interactive shell
	if [[ $- == *i* ]] ; then
            return $ERROR
	else
	   # otherwise, return
	   return $ERROR
	fi
    fi

    # defaults for global variables (SHOULD BE 0)
    local VERBOSE=${VERBOSE:-1}
    
    # check if stderr is a terminal and set output bold red
    if [ -v $LONG_OUTPUT ] ; then echo "" ; fi
    if [ -t 2 ] ; then
        echo -n "$bold$(tput setaf 1)"
        echo "Error (${FUNCNAME[1]}):" $* 1>&2
        echo -n "$(tput setaf 0)$plain"
    else
        echo "Error (${FUNCNAME[1]}):" $* 1>&2
    fi
    if [ -v $LONG_OUTPUT ] ; then echo "" ; fi

    if [ "$VERBOSE" -gt 0 ] ; then
        stacktrace
        if function_exists usage ; then usage ; fi
    fi
    # exit only if we are in a function
    if [[ $- == *i* ]] ; then
        return $ERROR
    else
       # otherwise, return
       return $ERROR
    fi
}

function require_environ() {
  var_name="${1:-}"
  explanatory_message="${2:-}"
  if [ -z "$var_name" ]; then
    echo ">>> Missing environment variable ${var_name}"
    if [ ! -z "$explanatory_message" ]; then        
       echo ">>>  - $explanatory_message"     
    fi
    exit $ERROR
  fi
}


#
# Various tracebcak functions
#	Each one provides more information than the previous ones
#	stacktrace() is a good compromise
#

# print line number function file
function traceback() {
    local frame=0
    while caller $frame; do
        ((frame++));
    done
    echo "$*"
}

# print traceback
#	function() in file:lineno
function trace_back()
{
  # Hide the traceback() call.
  local -i start=$(( ${1:-0} + 1 ))
  local -i end=${#BASH_SOURCE[@]}
  local -i i=0
  local -i j=0

  echo "Traceback (last called is first):" 1>&2
  for ((i=start; i < end; i++)); do
    j=$(( i - 1 ))
    local function="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$j]}"
    echo "     ${function}() in ${file}:${line}" 1>&2
  done
}

#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
# Based on https://stackoverflow.com/questions/25492953/bash-how-to-get-the-call-chain-on-errors
# Aug 26 '14 Neil McGill

# print indenting each call
#     at: func(), file, line number
function back_trace () {
    local deptn=${#FUNCNAME[@]}

    for ((i=1; i<$deptn; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local src="${BASH_SOURCE[$((i-1))]}"
        printf '%*s' $i '' # indent
        echo "at: $func(), $src, line $line"
    done
}

# print last caller and its location
# usage e.g.
#   set -o errtrace
#   trap 'trace_top_caller' ERR
function trace_top_caller () {
    local func="${FUNCNAME[1]}"
    local line="${BASH_LINENO[0]}"
    local src="${BASH_SOURCE[0]}"
    echo "  called from: $func(), $src, line $line"
}



#----------------------------------------------------------------------------
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
# Based on
#   https://www.runscripts.com/support/guides/scripting/bash/debugging-bash/stack-trace
#
# print full stack trace
#  file: Line no: function(): func arg1 arg2...
#
function stacktrace()
{
   declare frame=0
   declare argv_offset=0

   shopt -q extdebug ; local dbg=$?	# save extdebug status
   shopt -s extdebug			# activate extdebug

   while caller_info=( $(caller $frame) ) ; do

       if shopt -q extdebug ; then
           i=$((i+1))
           printf '%*s' $frame '' # indent

           declare argv=()
           declare argc
           declare frame_argc

           for ((frame_argc=${BASH_ARGC[frame]},frame_argc--,argc=0; frame_argc >= 0; argc++, frame_argc--)) ; do
               argv[argc]=${BASH_ARGV[argv_offset+frame_argc]}
               case "${argv[argc]}" in
                   *[[:space:]]*) argv[argc]="'${argv[argc]}'" ;;
               esac
           done
           argv_offset=$((argv_offset + ${BASH_ARGC[frame]}))
           echo ":: ${caller_info[2]}: Line ${caller_info[0]}: ${caller_info[1]}(): ${FUNCNAME[frame]} ${argv[*]}"
       fi

       frame=$((frame+1))
   done

   if [[ $frame -eq 1 ]] ; then
       caller_info=( $(caller 0) )
       echo "at: ${caller_info[2]}: Line ${caller_info[0]}: ${caller_info[1]}"
   fi

   # restore extdebug status
   if [ $dbg -eq 1 ] ; then shopt -u extdebug ; fi
}


#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
# From https://github.com/stripe-archive/random/blob/master/bash-backtrace.sh
#
# Add python-like backtraces to your bash shell scripts!
#
# Use like so:
#
# #!/bin/bash
# set -eu
# source "$stripe_random/bash-backtrace.sh"
# ...
#
# If you're using this, chances are high that you should switch from bash to a
# more modern programming language.
#

# Copyright (c) 2014- Stripe, Inc. (https://stripe.com)
#
# bash-backtrace.sh is published under the MIT license:
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# References:
# - https://gist.github.com/ryo1kato/3102982
# - https://gist.github.com/kergoth/6395873
#
# sample usage:
#   trap bash_backtrace ERR


#if [ -z "${BASH_VERSION-}" ]; then
#    echo >&2 "Error: this script only works in bash"
#    return 1 || exit 1
#fi

#set -E

function bash_backtrace() {
    local ret=$?
    local i=0
    local FRAMES=${#BASH_SOURCE[@]}


    echo >&2 "Traceback (most recent call last):"

    for ((frame=FRAMES-2; frame >= 0; frame--)); do
        local lineno=${BASH_LINENO[frame]}

        printf >&2 '  File "%s", line %d, in %s\n' \
            "${BASH_SOURCE[frame+1]}" "$lineno" "${FUNCNAME[frame+1]}"

        sed >&2 -n "${lineno}s/^[   ]*/    /p" "${BASH_SOURCE[frame+1]}"
    done

    printf >&2 "Exiting with status %d\n" "$ret"
}

#---------------------------------------------------------------------------
#---------------------------------------------------------------------------
#---------------------------------------------------------------------------


if [ "TESTED" == "yes" ] ; then
    # taken from https://stackoverflow.com/questions/64786/error-handling-in-bash
    # answer by Luca Borrione (Dec 16 '13 at 9:55)
    #
    lib_name='trap'
    lib_version=20121026

    stderr_log="/dev/shm/stderr.log"

    #
    # TO BE SOURCED ONLY ONCE:
    #
    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

    if test "${g_libs[$lib_name]+_}"; then
	return 0
    else
	if test ${#g_libs[@]} == 0; then
            declare -A g_libs
	fi
	g_libs[$lib_name]=$lib_version
    fi


    #
    # MAIN CODE:
    #
    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

    set -o pipefail  # trace ERR through pipes
    set -o errtrace  # trace ERR through 'time command' and other functions
    set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
    set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

    #exec 2>"$stderr_log"


    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
    #
    # FUNCTION: EXIT_HANDLER
    #
    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

    function exit_handler ()
    {
	local error_code="$?"

	test $error_code == 0 && return;

	#
	# LOCAL VARIABLES:
	# ------------------------------------------------------------------
	#    
	local i=0
	local regex=''
	local mem=''

	local error_file=''
	local error_lineno=''
	local error_message='unknown'

	local lineno=''


	#
	# PRINT THE HEADER:
	# ------------------------------------------------------------------
	#
	# Color the output if it's an interactive terminal
	test -t 1 && tput bold; tput setf 4                                 ## red bold
	echo -e "\n(!) EXIT HANDLER:\n"


	#
	# GETTING LAST ERROR OCCURRED:
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

	#
	# Read last file from the error log
	# ------------------------------------------------------------------
	#
	if test -f "$stderr_log"
            then
        	stderr=$( tail -n 1 "$stderr_log" )
        	rm "$stderr_log"
	fi

	#
	# Managing the line to extract information:
	# ------------------------------------------------------------------
	#

	if test -n "$stderr"
            then        
        	# Exploding stderr on :
        	mem="$IFS"
        	local shrunk_stderr=$( echo "$stderr" | sed 's/\: /\:/g' )
        	IFS=':'
        	local stderr_parts=( $shrunk_stderr )
        	IFS="$mem"

        	# Storing information on the error
        	error_file="${stderr_parts[0]}"
        	error_lineno="${stderr_parts[1]}"
        	error_message=""

        	for (( i = 3; i <= ${#stderr_parts[@]}; i++ ))
                    do
                	error_message="$error_message "${stderr_parts[$i-1]}": "
        	done

        	# Removing last ':' (colon character)
        	error_message="${error_message%:*}"

        	# Trim
        	error_message="$( echo "$error_message" | sed -e 's/^[ \t]*//' | sed -e 's/[ \t]*$//' )"
	fi

	#
	# GETTING BACKTRACE:
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
	_backtrace=$( backtrace 2 )


	#
	# MANAGING THE OUTPUT:
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

	local lineno=""
	regex='^([a-z]{1,}) ([0-9]{1,})$'

	if [[ $error_lineno =~ $regex ]]

            # The error line was found on the log
            # (e.g. type 'ff' without quotes wherever)
            # --------------------------------------------------------------
            then
        	local row="${BASH_REMATCH[1]}"
        	lineno="${BASH_REMATCH[2]}"

        	echo -e "FILE:\t\t${error_file}"
        	echo -e "${row^^}:\t\t${lineno}\n"

        	echo -e "ERROR CODE:\t${error_code}"             
        	test -t 1 && tput setf 6                                    ## white yellow
        	echo -e "ERROR MESSAGE:\n$error_message"


            else
        	regex="^${error_file}\$|^${error_file}\s+|\s+${error_file}\s+|\s+${error_file}\$"
        	if [[ "$_backtrace" =~ $regex ]]

                    # The file was found on the log but not the error line
                    # (could not reproduce this case so far)
                    # ------------------------------------------------------
                    then
                	echo -e "FILE:\t\t$error_file"
                	echo -e "ROW:\t\tunknown\n"

                	echo -e "ERROR CODE:\t${error_code}"
                	test -t 1 && tput setf 6                            ## white yellow
                	echo -e "ERROR MESSAGE:\n${stderr}"

                    # Neither the error line nor the error file was found on the log
                    # (e.g. type 'cp ffd fdf' without quotes wherever)
                    # ------------------------------------------------------
                    else
                	#
                	# The error file is the first on backtrace list:

                	# Exploding backtrace on newlines
                	mem=$IFS
                	IFS='
                	'
                	#
                	# Substring: I keep only the carriage return
                	# (others needed only for tabbing purpose)
                	IFS=${IFS:0:1}
                	local lines=( $_backtrace )

                	IFS=$mem

                	error_file=""

                	if test -n "${lines[1]}"
                            then
                        	array=( ${lines[1]} )

                        	for (( i=2; i<${#array[@]}; i++ ))
                                    do
                                	error_file="$error_file ${array[$i]}"
                        	done

                        	# Trim
                        	error_file="$( echo "$error_file" | sed -e 's/^[ \t]*//' | sed -e 's/[ \t]*$//' )"
                	fi

                	echo -e "FILE:\t\t$error_file"
                	echo -e "ROW:\t\tunknown\n"

                	echo -e "ERROR CODE:\t${error_code}"
                	test -t 1 && tput setf 6                            ## white yellow
                	if test -n "${stderr}"
                            then
                        	echo -e "ERROR MESSAGE:\n${stderr}"
                            else
                        	echo -e "ERROR MESSAGE:\n${error_message}"
                	fi
        	fi
	fi

	#
	# PRINTING THE BACKTRACE:
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

	test -t 1 && tput setf 7                                            ## white bold
	echo -e "\n$_backtrace\n"

	#
	# EXITING:
	# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

	test -t 1 && tput setf 4                                            ## red bold
	echo "Exiting!"

	test -t 1 && tput sgr0 # Reset terminal

	exit "$error_code"
    }
    trap exit_handler EXIT                                                  # ! ! ! TRAP EXIT ! ! !
    trap exit ERR                                                           # ! ! ! TRAP ERR ! ! !


    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
    #
    # FUNCTION: BACKTRACE
    #
    ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

    function backtrace()
    {
	local _start_from_=0

	local params=( "$@" )
	if (( "${#params[@]}" >= "1" ))
            then
        	_start_from_="$1"
	fi

	local i=0
	local first=false
	while caller $i > /dev/null
	do
            if test -n "$_start_from_" && (( "$i" + 1   >= "$_start_from_" ))
        	then
                    if test "$first" == false
                	then
                            echo "BACKTRACE IS:"
                            first=true
                    fi
                    caller $i
            fi
            let "i=i+1"
	done
    }



    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------

fi	# [ "TESTED" == "yes" ]
