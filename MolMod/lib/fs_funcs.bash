#!/bin/bash
#
#	File system level functions
#

FS_FUNCS='FS_FUNCS'
TRUE=${TRUE:-0}
FALSE=${FALSE:-1}
OK=${OK:-0}
ERROR=${ERROR:-1}
# we require util_funcs.bash
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
source $LIB/include.bash
include $LIB/util_funcs.bash


function version_file() {
    if ! funusage $# file ; then return $ERROR ; fi
#     if [ $# -ne 1 ] ; then errexit "file"  ; fi
     notecont $*

    local file=$1
    
    if [ -s $file ] ; then
	cnt=1
	suffix=`printf "%03d" $cnt`
	while [ -e $file,$suffix ] ; do
            cnt=$((cnt + 1))
	    suffix=`printf "%03d" $cnt`
	    #echo "IN: $suffix"
	done
	#echo "OUT: $suffix"
	mv $file $file,$suffix
        notecont "$file saved as $file,$suffix"
    fi
    return $OK
}


function abspath() {
    if ! funusage $# file ; then return $ERROR ; fi
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    
    # prefer executable solutions if they already exist
    realpath=`which realpath`
    readlink=`which readlink`
    if [ -x "$realpath" ] ; then
        $realpath -eq "$@"		# must exist, quiet
        return $?
    elif [ -x "$readlink" ] ; then
        $readlink -eq -- "$@"
        return $?
    # otherwise use shell directly
    elif [ -d "$1" ]; then
        # dir
        (cd "$1"; pwd -P)		# -P avoid symlinks
        return $OK
    elif [ -f "$1" ]; then
        # file
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd -P)/${1##*/}"	# pwd -P: avoid symlinks
        else
            echo "$(pwd -P)/$1"
        fi
        return $OK
    else
        #echo "/dev/null"
        #warncont " ---FILE-DOES-NOT-EXIST---"
        echo ""
        return $ERROR
    fi
}

function relpath() {
    if ! funusage $# /abspath/to/relativize/file1 /abspath/to/reference/file 
    then return $ERROR ; fi
    # both $1 and $2 are absolute paths beginning with /
    # returns relative path to $2($target) from $1($source)
    if [ $# -eq 2 ] ; then
       source="$1"
       target="$2"
    elif [ $# -eq 1 ] ; then
       source=`pwd`
       target="$1"
    else
       warncont "---relpath error, usage: relpath [source] target---"
       return $ERROR
    fi
    
    # example use (ensure a symlink contains the relative path to 
    # a file from our current position instead of its absolute path):
    #    f=`abspath $file`
    #    ln -sf `relpath $f` target.lnk
     
    if [ ! -e "$source" -o ! -e "$target" ] ; then
        warncont "---NO-SUCH-FILE---"
        return $ERROR
    fi

    # example:
    #    f=`abspath $file`
    #    ln -s `relpath `pwd` $f` f.lnk

    common_part=$source # for now
    result="" # for now

    while [[ "${target#$common_part}" == "${target}" ]]; do
        # no match, means that candidate common part is not correct
        # go up one level (reduce common part)
        common_part="$(dirname $common_part)"
        # and record that we went back, with correct / handling
        if [[ -z $result ]]; then
            result=".."
        else
            result="../$result"
        fi
    done

    if [[ $common_part == "/" ]]; then
        # special case for root (no common path)
        result="$result/"
    fi

    # since we now have identified the common part,
    # compute the non-common part
    forward_part="${target#$common_part}"

    # and now stick all parts together
    if [[ -n $result ]] && [[ -n $forward_part ]]; then
        result="$result$forward_part"
    elif [[ -n $forward_part ]]; then
        # extra slash removal
        result="${forward_part:1}"
    fi

    echo $result
}


function posix_relpath () {
    [ $# -ge 1 ] && [ $# -le 2 ] || return 1
    current="${2:+"$1"}"	# if $2 unset use $1, if $2 is null leave as null
    target="${2:-"$1"}"
    [ "$target" != . ] || target=/
    target="/${target##/}"
    [ "$current" != . ] || current=/
    current="${current:="/"}"
    current="/${current##/}"
    appendix="${target##/}"
    relative=''
    while appendix="${target#"$current"/}"
        [ "$current" != '/' ] && [ "$appendix" = "$target" ]; do
        if [ "$current" = "$appendix" ]; then
            relative="${relative:-.}"
            echo "${relative#/}"
            return 0
        fi
        current="${current%/*}"
        relative="$relative${relative:+/}.."
    done
    relative="$relative${relative:+${appendix:+/}}${appendix#/}"
    echo "$relative"
}

# print file size in human readable form
function prsize() {
    if ! funusage $# file... ; then return $ERROR ; fi
    local f sz TB GB MB KB
    for f in "$@" ; do
        #f=$1
        # derefernce links (-L)
        #sz=`stat -L -c%s "$f"`
        sz=`stat -c%s "$f"`
        # powers of 2
        TB=1099511627776
        GB=1073741824
        MB=1048576
        KB=1024
        # powers of 10
        #TB=1000000000000
        #GB=1000000000
        #MB=1000000
        #KB=1000
        # GB?
        if [ $sz -gt $TB ] ; then
	    #echo $((sz / TB)) GB $f
            sz=`echo "scale=1; $sz/$TB" | bc`
            echo ${sz}T  $f
        elif [ $sz -gt $GB ] ; then
	    #echo $((sz / GB)) GB $f
            sz=`echo "scale=1; $sz/$GB" | bc`
            echo ${sz}G $f
        elif [ $sz -gt $MB ] ; then
	    #echo $((sz / MB)) MB $f
            sz=`echo "scale=1; $sz/$MB" | bc`
            echo ${sz}M $f
        elif [ $sz -gt $KB ] ; then
	    #echo $((sz / KB)) KB $f
            sz=`echo "scale=1; $sz/$KB" | bc`
            echo ${sz}K $f
        else
            echo ${sz}B $f
        fi
    done
}


# Unused alternatives
if [ "y" == "n" ] ; then
  # URL processing using bash
  function urlencode() {
      local arg i c
      arg="$1"
      i="0"
      while [ "$i" -lt ${#arg} ]; do
    	  c=${arg:$i:1}
    	  if echo "$c" | grep -q '[a-zA-Z/:_\.\-]'; then
    	      echo -n "$c"
    	  else
    	      echo -n "%"
    	      printf "%X" "'$c'"
    	  fi
    	  i=$((i+1))
      done
  }

  function urldecode() {
      local arg i c0 c1 c2
      arg="$1"
      i="0"
      while [ "$i" -lt ${#arg} ]; do
    	  c0=${arg:$i:1}
    	  if [ "x$c0" = "x%" ]; then
    	      c1=${arg:$((i+1)):1}
    	      c2=${arg:$((i+2)):1}
    	      printf "\x$c1$c2"
    	      i=$((i+3))
    	  else
    	      echo -n "$c0"
    	      i=$((i+1))
    	  fi
      done
  }

  # URL processing using sed
  function urldecode(){
      echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x/g;')"
  }

  # URL processing using bash
  function urlencode() {
      local l c
      l=${#1}
      for (( i = 0 ; i < l ; i++ )); do
          c=${1:i:1}
          case "$c" in
              [a-zA-Z0-9.~_-]) printf "$c" ;;
              ' ') printf + ;;
              *) printf '%%%X' "'$c"
          esac
      done
  }

  function urldecode() {
      local data 
      data=${1//+/ }
      printf '%b' "${data//%/\x}"
  }

fi



# File renaming
# -------------

# rename files with spaces, parentheses or stars to substitute them
# by underscores, dashes or pluses
alias renspaces='for i in *[\ \(\)\*]* ; do 
    if [ ! -e "$i" ] ; then continue ; fi ; 
    mv "$i" `echo "$i" |tr " ()*" "_\-\-+"` ; 
done'

# remove %2F (/) in file names and change it by a '.', then web-unescape
# the file name
alias webunescape='for i in *%2F* ; do 
    mv $i `echo $i | sed -e 's/%2F/\./g'` ; 
done ; convmv --unescape *%* --notest'

function remspace() {
    local name=''
    if [ $# == 0 ] ; then
        # if there are no arguments, read filenames from stdin
        # to be used with 
        #	find . -depth -print | remspace
        while read file ; do
            echo "$file"
            if [ ! -e "$file" ] ; then continue ; fi
            f="${file##*/}"
    	    name="${file%.*}"
    	    ext="${f##*.}"
            d=`dirname "$file"`
            #echo "$d"
            cd "$d"
            n=`echo "$f" |tr " *" "_+"`
            #pwd
            #echo "[${f}] [${n}]"
	    if [ ! "$f" == "$n" ] ; then
                echo mv "$f" "$n"
                mv "$f" "$n"
	    fi
            cd - >& /dev/null
        done
    else
        # if there are arguments, process each of them
        for file in "$@" ; do
            if [ ! -e "$file" ] ; then continue ; fi
            f="${file##*/}"
    	    name="${file%.*}"
    	    ext="${f##*.}"
            d=`dirname $file`
            cd "$d"
            #echo "$d"
            n=`echo "$f" |tr " *" "_+"`
            #pwd
            #echo "[${f}] [${n}]"
	    if [ ! "$f" == "$n" ] ; then
                #echo mv "$f" "$n"
                mv "$f" "$n"
	    fi
            cd - >& /dev/null
        done    
    fi
}

function rennumber() {
    # takes a directory as argument, cd's to it,
    # and renames all files with increasing sequential numbers
    local d i n 
    if ( ! funusage $# directory ) ; then return $ERROR ; fi
        #if [ $# == 0 ] ; then return ; else d="$1" ; fi
	#echo "$d"
        i=0
        if [ ! -d "$d" ] ; then echo "Err: '$d' not a directory" ; return ; fi
	# we'll use a new directory to avoid conflicts
        if [ -e "$d".new ] ; then echo "Err: '$d.new' exists" ; return ; fi
	mkdir -p "$d".new
        # Potential options
        #	ls -c1	-- sort by last modification time, newest first
        #	ls -r... -- reverse sort order
        #	ls --sort=(extension|size|time|version)
        /bin/ls -U1 "$d" | sort -n | while read n ; do
            # do not rename subdirectories
            if [ -f "$d"/"$n" ] ; then 
                i=$((i+1))
                echo "mv $d/$n -> $d.new/$i"
		# unformatted (apparently needed for claws-mail)
                mv "$d"/"$n" "$d".new/$i
                # formatted
                #mv "$d"/"$n" "$d".new/`printf "%06d" $i`
	    fi
	done
        # get the files back
        # we may have a problem if there is a subdir with an used numeric name
        mv -n "$d".new/* "$d"
        # Sanity check
        # at the end $d should be empty
	i=$(shopt -s nullglob; echo "$d".new/*)
        if [ ${#i} -gt 0 ]; then
            echo "$d.new is not empty after rennumbering!" 2>&1
            echo "$d.new is not empty after rennumbering!" > ~/err
        else
            rmdir "$d".new
	fi
}


# check if the argument exists and if it does, if it is empty
function isempty()
{
    if ! funusage $# file-or-dir ; then return $ERROR ; fi
    #if [ $# == 0 ] ; then echo "ERROR: ${FUNCNAME[0]} file-to-check" ; exit ;
    #fi
    target="$1"
    
    # which, as a one liner would look like
    #[ -d $target ] && ([ "$(ls -A $target)" ] && return $FALSE || return $TRUE) || ([ -s $target ] && return $FALSE || return $TRUE )

    ### JR ###
    # the rest should never be run and is left as alternatives, just in case
    if [ ! -e "$target" ] ; then return $TRUE ; fi

    # alternative
    if [ ! -s "$target" ] ; then return $TRUE ; fi
    
    # it might be a directory with non-zero size but no contents
    if [ -d "$target" ] ; then
	# three methods: each is final as coded, so only the first will run
        # method 1
	[ -z "$(ls -A $target)" ] && return $TRUE || return $FALSE
	# method 2
	# pure bash, will be run in a subshell, so no opts are modified
	[ -z "$(shopt -s nullglob dotglob; echo $target/*)" ] \
	    && return $TRUE || return $FALSE
	# method 3
	[ -n "$(find $target -prune -empty)" ] \
	    && return $TRUE || return $FALSE
    fi
    # must be a file/dir with non-zero size
    return $FALSE

    # alternative
    if [ -d "$target" ] ; then
        if [ "$(ls -A $target)" ] ; then 
            return $FALSE
        else
            return $TRUE
        fi
    else
        if [ -s "$target" ] ; then
            return $FALSE
        else
            return $TRUE
        fi
    fi
    
}


# link functions
function hardlink() {
    local orig="$1"
	local dest="$2"
	
	if [ ! -e "$orig" ] ; then return 1 ; fi
	if [ -e "$dest" ] ; then 
	    if [ ! -d "$dest" ] ; then return 2 ; fi
    fi
	
	ln "$orig" "$dest"
	return 0 ;
}

function symlink() {
    local orig="$1"
    local dest="$2"
	
    if [ ! -e "$orig" ] ; then return 1 ; fi
    if [ -e "$dest" ] ; then 
	if [ ! -d "$dest" ] ; then return 2 ; fi	# file or link
    fi
    if [ -d "$dest" ] ; then
        if [ -e "$dest/"`basename $orig` ] ; then return 3 ; fi	# already exists
    fi
	
    # next is GNU ls specific (may require using 'gls' in BSD-derived systems)
    # -s --symbolic (make symbolic link)
    # -L --logical (dereference TARGETs that are symbolic links)
    # -r --relative (create links relative to link location)
    if ! ln -s -L -r "$orig" "$dest" ; then ln -s -L "$orig" "$dest" ; fi
    return 0 ;
}

function nfiles() {
    pat="$1"
    # count files matching a pattern
    # must run in a subshell to avoid changing shopt in the executing
    # shell
    #
    # TAKES ONLY ONE ARGUMENT THAT MUST BE QUOTED!!!
    #
    # sample use: nfiles "*.pdb"
    #      if [ `nfiles "*.pdb"` -gt 0 ] ; then ...
    #
    #declare a=( $1 ) ; echo ${#a[@]}	# fails if no pattern but inexisting name
    #( shopt -s nullglob ; echo $1 | wc -w ) # fails if nonexisting, spaces or \n
    #
    # use stat and output only the file type (so no problem with \n in names)
    #stat -c %F $1 2>/dev/null | wc -l	# all
    # for regular files only, next may fail if LANG != EN
    #stat -c %F $1 2>/dev/null | grep -c regular	# regular files
    #
    #ls | grep -c "$1"					# only current dir, no type, no \n
    #
    # use find, output 0-terminated names to account for \n in name, and
    # use grep to count 0-delimited lines
    # this will also report filenames starting with .
    #find . -maxdepth 1 -type f -name "$1" -print0 | grep -zc .
    #
    LC_ALL=en_US stat -c %F $1 2>/dev/null | grep -c 'regular file'
}

function ndirs() {
    pat="$1"
	# count files matching a pattern
	# must run in a subshell to avoid changing shopt in the executing
	# shell
	#
	# TAKES ONLY ONE ARGUMENT THAT MUST BE QUOTED!!!
	#
	# use: ndirs "*.pdb"
	#      if [ `ndirs "*.pdb" ` -gt 0 ] ; then ...
	#
	#declare a=( $1 ) ; echo ${#a[@]}	# fails if no pattern but inexisting name
	#( shopt -s nullglob ; echo $1 | wc -w ) # fails if nonexisting, spaces or \n
    #
	# use stat and output only the file type (so no problem with \n in names)
	#stat -c %F $1 2>/dev/null | wc -l	# all
	#stat -c %F $1 2>/dev/null | grep -c regular	# regular files
	#
	# only searches in current dir, no type, no \n in names, GREP REGEXP
	#ls -F | grep -c "$1/$"					
	#
	# use find, output 0-terminated names to account for \n in name, and
	# use grep to count 0-delimited lines
	# this will also report filenames starting with .
	#find . -maxdepth 1 -type d -name "$1" -print0 | grep -zc .
	#
    stat -c %F $1 2>/dev/null | grep -c 'directory'
}

function nlinks() {
    pat="$1"
	# count files matching a pattern
	# must run in a subshell to avoid changing shopt in the executing
	# shell
	#
	# TAKES ONLY ONE ARGUMENT THAT MUST BE QUOTED!!!
	#
	# use: nlinks "*.pdb"
	#      if [ `nlinks "*.pdb" ` -gt 0 ] ; then ...
	#
	#declare a=( $1 ) ; echo ${#a[@]}	# fails if no pattern but inexisting name
	#( shopt -s nullglob ; echo $1 | wc -w ) # fails if nonexisting, spaces or \n
    #
	# use stat and output only the file type (so no problem with \n in names)
	#stat -c %F $1 2>/dev/null | wc -l	# all
	#stat -c %F $1 2>/dev/null | grep -c regular	# regular files
	#
	# only searches in current dir, no type, no \n in names, GREP REGEXP
	#ls -F | grep -c "$1@$"					
	#
	# use find, output 0-terminated names to account for \n in name, and
	# use grep to count 0-delimited lines
	# this will also report filenames starting with .
	#find . -maxdepth 1 -type l -name "$1" -print0 | grep -zc .
    stat -c %F $1 2>/dev/null | grep -c 'symbolic link'
}
