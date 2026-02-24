# declare -r v		# v is read only
# declare -f v		# v is a function
# declare -F v		# show function v's name ans attributes
# declare -g v		# apply global scope to v operations INSIDE a function
# declare -p v		# display variable v's options and attributes
#			# -- before a var means the var has no arguments
# declare attributes:
# declare -i v		# v is an integer
#	  -a		# array
#	  -A		# associative array
#	  -l		# all lowercase characters (unset with +l)
#	  -u		# the var consists of uppercase characters only (unset +u)
#         -n            # variable becomes a name reference for another (+n unset)
#	  -t		# used with a function, it inherits the DEBUG and RETURN
#                       # traps from the parent (unset with +t)
#	  -X		# export variable v to child processes (unset +x)


# get the position of an array element by its content (-1 if not present)
#	get_index array value
# e.g.
#    declare -a array
#    array=( 'a' 'b' 'c' )
#    get_index array b
function get_index() {
    # $1 is the name of the array (not the array content)
    # we will use the name to access the array
    local -n arr=$1	# use -n to make a reference to the variable *name*
  		   	# from here on we can use arr as the array called as $1
    local val=$2

    #echo "arr = ${arr[@]}"
    #echo "IDX = ${!arr[@]}"

    # loop over the indexes to avoid dereferencing a gap
    for i in "${!arr[@]}"; do
	if [[ ${arr[i]} = $val ]] ; then
	    echo $i
	    return 0	# success
	fi
    done
    echo -1
    return 1		# failure
}


# print an array as a series of 'index	value' lines
function dump_array() {
    # works for linear and for associative arrays
    local -n ary=$1
    for i in "${!ary[@]}"; do
        printf "%s\t%s\n" "$i" "${ary[$i]}"
    done
}



# this function will check the command line for conformance with a 
# specified list of arguments, call it with
#	check_args "$opts" "$@"
#
# $opts must be a string containing first the colon-separated short
# (one letter) options, a slash (/) and then the colon-separated
# list of long options, e.g.:
#
# o:t:T/one:two:three
#
# uncoupling the two steps of argument processing gives us greater
# flexibility in some cases: when all arguments have a value, and
# we do not want/need to check them, get_args() alone may suffice
#
# Note that function "usage()" *must* exist!
#
function check_args() {
    local opts="$1"
    local args="$@"
    #echo "OPTS=$opts"
    #echo "ARGS=$args"
    #echo "CMD=""$@"
    #echo "ME=$MYNAME"
    MYNAME=${0:-check_args}
    local tmp
    
    tmp=$( getopt -o `echo $opts | cut -d';' -f1` \
                   --long `echo $opts | cut -d'/' -f2` \
	           -n "$MYNAME" -- "$@" )
    #invalid option?
    if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi
}



function get_index_nogaps() {
    # use as get_index value "${array[@]}"
    # in practice: pos=`get_index value "${array[@]}"`
    # or: pos=$( get_index value "${array[@]}" )
    #
    # Note that this will fail if the array contains gaps!!!
    #	In that case the array should not be passed as an
    #	argument to a function because it will be substituted 
    #	on call (here we rely on that command line substitution 
    #   to get the index).
    #	If the array has gaps we should loop directly on the
    #	array indexes "${!array[@]}" and test against ${array[i]}
    value="$1"
    shift
    local index=0
    for i in "$@"; do
        if [[ "$i" = "${value}" ]] ; then
            echo "${index}";
            return
        fi
        ((index++))
    done
    return 1
}



function optno() {
    # use as optno opt optlist
    local value="$1"
    local soptstr=$( echo "$2" | cut -d';' -f1 )	# a string
    local loptlst=( $( echo "$2" | cut -d';' -f2 | tr ',' ' ' ) ) # an array

    # check if it is a one-letter option
    local pos=`expr index $soptsrt $value`	# one-offset
    if [ $pos -ne 0 ] ; then echo $pos ; fi

    # check if it is a long option
    pos=`get_index loptlst "$value"`
    if [ ! $? ] ; then return 1; else echo $pos ; return 0 ; fi
}


function UNFINISHED_args() {
    # call with args $opts "$@"
    local opts="$1"
    #echo OPT=$opts ; exit
    # we could try to generate the short arg list from the long arg list
    # as long as there are no repeated initials
    # if opts is a long arg list, we can make an array of long arg names
#    local los=( ${opts//,/ } )
#    local sos=( $( for i in "${los[@]}" ; do echo -n "${i:0:1} " ; done ) )
#    echo "los=${los[@]}"
#    echo "sos=${sos[@]}"
#    eval $sos[1]=0.000
#    echo "${sos[1]}=$threshold" 
    
    local tmp=$( getopt -o `echo $opts | cut -d';' -f1` \
                   --long `echo $opts | cut -d';' -f2` \
	           -n "$MYNAME" -- "$@" )
    #invalid option?
    if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

    eval set -- "$tmp"
    echo "tmp=$tmp" ; echo "\$#=$#" ; 

#    while true ; do
#        if [ "$1" ] == "--" ] ; then break ; fi
#        idx=`get_index los $1`
#        if [ "$idx" -ne -1 ] ; then
#	    eval $los[pos]=$2
#	    shift 2
#	fi
#    done
#    exit
    
    while true ; do
        case "$1" in
        	-\?|-h|--help)
                    usage ;
		    exit 0 ;;
		-t|--threshold)
		    # force field
		    threshold=$2 ; 
		    shift 2 ;;
		'--') break ;;
                *) 
		    echo "ERROR: wrong option encountered ($1)!" >&2 ; 
		    usage ; 
		    exit 1 ;;
        esac
    done
}


args "$opts" "$@"	# process args and set specified values (if any)



#-----------------------------------------------------------------------



# declare -r v		# v is read only
# declare -f v		# v is a function
# declare -F v		# show function v's name ans attributes
# declare -g v		# apply global scope to v operations INSIDE a function
# declare -p v		# display variable v's options and attributes
#			# -- before a var means the var has no arguments
# declare attributes:
# declare -i v		# v is an integer
#	  -a		# array
#	  -A		# associative array
#	  -l		# all lowercase characters (unset with +l)
#	  -u		# the var consists of uppercase characters only (unset +u)
#         -n            # variable becomes a name reference for another (+n unset)
#	  -t		# used with a function, it inherits the DEBUG and RETURN
#                       # traps from the parent (unset with +t)
#	  -X		# export variable v to child processes (unset +x)


# This function will process the command line and convert parameters
# to variables with their corresponding value.
# Parameters start with a '-' or a '--'
# ALL parameters must have an assigned value ('' is OK).
# Values may follow the parameter or be assigned with an '=' sign, e.g.
#	get_args -i input -out output --input=in --output=''
#
# Any arguments that do not conform to the "arg value" scheme, will be
# saved in a global array named "extra_args" for additional downstream
# processing if necessary
#
# Note: if the variables have previous default values, those will be
# overridden by the last assignment
#	if the variabkes have no defaults, then one needs to check
# mandatory variables for existence and issue an usage message if
# missing
#	there is no validity checking for unknown arguments
#
# e.g.:
#
#    check_args "$opts" "$@"
#    get_args "$@"
#    echo "extra='${extra_args[@]}'"
#    #: ${help?}		# exit if help is not set or null
#    if [[ -v help ]] ; then echo "help is set" ; fi
#    if isset help ; then echo "help is set" ; fi
#    help=${help:-false}	# if not set, set help to false
#    help=${help-false}	# only set help to false if already set
#    echo "help=<$help>"
#
#
# ${variable:?word} Complain if undefined or null 
# ${variable:-word} Use new value if undefined or null 
# ${variable:+word} Opposite of the above |
# ${variable:=word} Use new value if undefined or null, and redefine.

function get_args()
{
    unset extra_args
    declare -g -a extra_args		# global array
    local tmp
    local parameter
    local value
    #echo "get_args()"
    #echo "Parameters are '$*'"
    until [ -z "$1" ]
    do
        tmp="$1"
        #echo "Processing parameter: '$tmp'"
        if [ "${tmp:0:1}" = '-' ] ; then
            tmp="${tmp:1}"		# remove leading '-'
	    # check if it has a second leading '-' (supposedly a long option)
	    if [ "${tmp:0:1}" = '-' ] ; then
                tmp="${tmp:1}"		# Finish removing leading '--'
	    fi
	    #echo "$tmp ${tmp:0:1}"
	    # we'll treat the same '-' and '--' options
	    
	    # detect special cases:
	    #	options without name (- -- --=something) cannot save a
	    #   subsequent value into a 'noname' variable: set them 
	    #	separately
	    if [[ -z "$tmp" || "${tmp:0:1}" == *'=' ]] ; then
	        # add them to extra_args, remove and proceed to next
		extra_args+=( "$1" )
		shift
		continue;
	    fi
	    
	    # Now we have two possibilities:
	    # the option was of the type 
            #	[-[-]]o[pt]=val 
            # or 
            #	[-[-]]o[pt] val
	    # let us now tell them apart
	    if [ `expr index "$tmp" "="` -gt 1 ] ; then 
	        # it has a name and an '=', must be a [-]-opt=val
		# if we did 'eval $tmp' it would fail with embedded spaces
		parameter="${tmp%%=*}"     # Extract name (remove = and after).
		parameter="${parameter//-/_}"	# change any middle '-' to '_'
        	value="${tmp##*=}"         # Extract value (remove up to and including =).
	    else
		# there is no '=', it must be [-]-opt val
		parameter="$tmp"
	        parameter="${parameter//-/_}"	# change any middle '-' to '_'
		shift		# get next argument
		# value can be '' or start with a '-' (e.g. -1.2e3)
		value="$1"
	  fi
	  #echo "Parameter: '$parameter', value: '$value'"
	  # do the assignment
          eval $parameter="$value"
          shift
	else
	    # If a parameter does not start with '-'
	    # we will not assign this argument because we do not know
	    # which variable name to give it.
	    # But we can save it in a 'leftovers' array
	    extra_args+=( "$tmp" )
	    shift
	fi
    #echo "extra=${extra_args[@]}"
    done
    #echo "extra=${extra_args[@]}"
}


get_args "$@"
