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





# print an array as a series of 'index	value' lines
function dump_array() {
    # works for linear and for associative arrays
    local -n ary=$1
    for i in "${!ary[@]}"; do
        printf "%s\t%s\n" "$i" "${ary[$i]}"
    done
}



# get the position of an array element by its content (-1 if not present)
#	get_array_index array value
# e.g.
#    declare -a array
#    array=( 'a' 'b' 'c' )
#    get_array_index array b
function get_array_index() {
    # $1 is the name of the array (not the array content)
    # we will use the name to access the array
    local -n arr=$1	# use -n to make a reference to the variable *name*
  		   	# from here on we can use arr as the array called as $1
    local val=$2

    #echo "arr = ${arr[@]}"
    #echo "IDX = ${!arr[@]}"

    # loop over the indexes to avoid dereferencing a gap
    for i in "${!arr[@]}"; do
	if [[ "${arr[i]}" = "$val" ]] ; then
	    echo $i
	    return 0	# success
	fi
    done
    echo -1
    return 1		# failure
}



function get_array_index_nogaps() {
    # use as get_array_index_nogaps value "${array[@]}"
    # in practice: pos=`get_array_index_nogaps value "${array[@]}"`
    # or: pos=$( get_array_index_nogaps value "${array[@]}" )
    #
    # Note that this will fail if the array contains gaps!!!
    #	In that case the array should not be passed as an
    #	argument to a function because it will be substituted 
    #	on call (here we rely on that command line substitution 
    #   to get the index).
    #
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
        (( index++ ))
    done
    return 1
}



# sh-valid "contains" function
contains() {
  case "$1" in
    (*"$2"*) true;;
    (*) false;;
  esac
}


# bash-ism: test if variable "variable-name" (no dollar!) is set
is_set() {
  [[ -v "$1" ]]
}



# check arguments against an argument list for getopt(1)
#
# this function will check the command line for conformance with a 
# specified list of arguments, call it with
#
#	check_args "$opts" "$@"
#
# $opts must be a string containing first a string of short
# (one letter) options, a slash (/) and then the comma-separated
# list of long options. Options may be followed by a colon ':' to
# indicate that they require an additional argument, or two colons
# to indicate that they require an optional argument, e.g.:
#
# ot:T:f/one,two:,three:,four
#
# uncoupling the two steps of argument processing gives us greater
# flexibility in some cases: when all arguments have a value, and
# we do not want/need to check them, get_args() alone may suffice
#
# Note that function "usage()" *must* exist!
#
# Note too that we do not need to check bash built-in getopts: first,
# it only takes one-letter options, second, all options are optional,
# and third, getopt works sequentially on the command line, does not
# pre-process it first.
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

    if ! contains "$opts" '/' ; then
        # only one kind of options were provided, check if it was
	# a short-options string or a long-options comma-separated
	# list, and add a '/' so cut(1) works correctly
	if ! contains "$opts" ',' ; then
	    opts="$opts"/
	else
	    opts=/"$opts"
	fi
    fi
    tmp=$( getopt -o `echo $opts | cut -d';' -f1` \
                   --long `echo $opts | cut -d'/' -f2` \
	           -n "$MYNAME" -- "$@" )
    #invalid option?
    if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi
}



function optno() {
    # use as optno opt optlist
    local value="$1"
    local soptstr=$( echo "$2" | cut -d'/' -f1 )		  # a string
    local loptlst=( $( echo "$2" | cut -d'/' -f2 | tr ',' ' ' ) ) # an array

    # check if it is a one-letter option
    local pos=`expr index $soptsrt $value`	# one-offset
    if [ $pos -ne 0 ] ; then echo $pos ; fi

    # check if it is a long option
    #	first by name
    pos=`get_array_index loptlst "$value"`
    # 	maybe it has a mandatory argument?
    if [ ! $? ] ; then pos=`get_array_index loptlst "$value": ` ; fi
    #	or an optional argument?
    if [ ! $? ] ; then pos=`get_array_index loptlst "$value":: ` ; fi
    #	otherwise it was not found
    if [ ! $? ] ; then echo "-1"; return 1; else echo $pos ; return 0 ; fi
}



# This function will process the command line and convert parameters
# to variables with their corresponding value.
#
# Parameters start with a '-' or a '--'
#
# Parameters with no value will be assigned a default "$yes" (defined
# inside)
#
# Values may follow the parameter or be assigned with an '=' sign, e.g.
#	get_args -i input -out output --input=in --output=''
#
# Any arguments that do not conform to the "[-]-arg..." scheme, will be
# saved in a global array named "extra_args" for additional downstream
# processing if necessary
#
# Notes: 
#	if the variables have previous default values, those will be
# overridden by the last assignment
#	if the variabkes have no defaults, then one needs to check
# mandatory variables for existence and issue an usage message if
# missing
#	there is no validity checking for unknown arguments
#
# e.g.:
#
#    check_arg "$opts" "$@"
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
    local yes=${yes:-y}			# default 'yes' to 'y'
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
	    #	options without name (- -- --=something) cannot give a
	    #   subsequent value into a 'noname' variable: send the 
	    #	values to $extra_args[]
	    if [[ -z "$tmp" || "${tmp:0:1}" == *'=' ]] ; then
	        # add them to extra_args, remove and proceed to next
		extra_args+=( "$1" )
		shift
		continue;
	    fi
	    
	    # Now we have three possibilities:
	    # the option was of the type 
            #	[-[-]]o[pt]=val 
            # or 
            #	[-[-]]o[pt] val
	    # or
	    #   [-[-]o[pt]
	    # let us now tell them apart
	    if [ `expr index "$tmp" "="` -gt 1 ] ; then 
	        # it has a name and an '='; it must be a [-]-opt=val
		# if we did 'eval $tmp' it would fail with embedded spaces
		parameter="${tmp%%=*}"     # Extract name (remove = and after).
		parameter="${parameter//-/_}"	# change any middle '-' to '_'
        	value="${tmp##*=}"         # Extract value (remove up to and including =).
	    else
		# there is no '=', it must be [-]-opt val or  [-]-opt
		parameter="$tmp"
	        parameter="${parameter//-/_}"	# change any middle '-' to '_'
		#echo "processing $tmp: $parameter N=$# 2=$2"
		# test next argument
		if [ $# -eq 1 ] ; then
		    # this is the last argument and has no value
		    value="$yes"
		elif [ "${2:0:1}" = '-' ] ; then
		    #echo "\$2=$2 has a -"
		    # this option is of type [-]-opt, set value to "$yes"
		    value="$yes"
		else
		    # next argument is the value	
		    value="$2"
		    shift		# get next argument
		    # value can be '' or start with a '-' (e.g. -1.2e3)
		fi
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
# example use:
#
# get_args "$@"
#
# note that we do not need to define any argument string, but we will need
# to check matching short and long variable names afterwards and define a
# precedence of short/long arguments, because as we do not know the order
# we cannot use first/last use for precedence
#
# e.g.:
# cmd -i in1 -input in2 --output=out1 -o out2
#
# get_args "$@"
# if is_set I ; then infile=$I ; fi
# if is_set INPUT ; then infile=$INPUT ; fi	# in this order INPUT takes precedence
# if is_set OUTPUT ; then outfile=$OUTPUT ; fi
# if is_set O ; then outfile=$O ; fi		# but in this one O takes precedence
#
