# print line number, function and file
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
    local func="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$j]}"
    echo "     ${func}() in ${file}:${line}" 1>&2
  done
}

# print full stack trace
#  file: Line no: function(): func arg1 arg2...
#
function stacktrace()
{
   declare frame=0
   declare argv_offset=0

   shopt -q extdebug ; dbg=$?   # save extdebug status
   shopt -s extdebug		# activate extdebug

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
           echo "at: ${caller_info[2]}: Line ${caller_info[0]}: ${caller_info[1]}(): ${FUNCNAME[frame]} ${argv[*]}"
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

    # Based on https://stackoverflow.com/questions/25492953/bash-how-to-get-the-call-chain-on-errors
    # Aug 26 '14 Neil McGill

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

    function trace_top_caller () {
	local func="${FUNCNAME[1]}"
	local line="${BASH_LINENO[0]}"
	local src="${BASH_SOURCE[0]}"
	echo "  called from: $func(), $src, line $line"
    }

    #set -o errtrace
    #trap 'trace_top_caller' ERR

 
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


warn() {
    echo ">>> ${FUNCNAME[1]}: this is a warning"
    echo -n ">>>" ; caller 1

    local n=${#BASH_ARGV[@]}
    echo ">>> all args: ${BASH_ARGV[*]}"
    echo ".............."
    traceback
    echo ".............."
    trace_back
    echo ".............."
    stacktrace something
    echo ".............."
    back_trace
    echo ".............."
    trace_top_caller
    echo ".............."
    bash_backtrace
}

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
function boldred() {
    echo -n "$bold$(tput setaf 1)"
}
function plain() {
    echo "$(tput setaf 0)$plain"
}


function warning() {
    if [ $# -lt 1 ] ; then 
        echo "Err: ${FUNCNAME[0]} '\$LINENO: message'" 
	exit 1 
    fi
    if [ -t 1 ] ; then
        echo -n "$bold$blue"
    fi
    echo ""
    echo "WARNING (${FUNCNAME[1]}):" $*
    echo ""
    if [ -t 1 ] ; then
        echo -n "$plain"
    fi
}


function error() {
    if [ $# -ne 1 ] ; then 
        echo "Err: ${FUNCNAME[0]} 'message'" 
	exit 1 
    fi

    local message=${1:-"Unspecified error"}
    # defaults for global variables
    local VERBOSE=${VERBOSE:-1}
    
    # check if stderr is a terminal
    if [ -t 2 ] ; then
        echo -n "$bold$(tput setaf 1)"
    fi
    echo ""
    echo "Error (${FUNCNAME[1]}): $message" 1>&2
    echo ""
    if [ -t 2 ] ; then
        echo -n "$(tput setaf 0)$plain"
    fi

    if [ "$VERBOSE" -gt 0 ] ; then
    stacktrace
    fi
    exit 1
}



f()
{
    echo I am inside "$FUNCNAME" called from ${FUNCNAME[1]}
    warn call from f
}

g()
{
    echo I am inside "$FUNCNAME" called from ${FUNCNAME[1]}
    f call from g
}

h()
{
    echo "I am in h"
    g call from h
    warning "[line $LINENO]" we are going to call error
    error "$LINENO: terminated"
}

f
g
h
