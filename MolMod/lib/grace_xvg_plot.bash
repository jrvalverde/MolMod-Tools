#!/bin/bash
#

GRACE_XVG_PLOT="GRACE_XVG_PLOT"

grace=`which grace`

function grace_xvg_plot {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG

    if [ -s ${nam%.xvg}.${dev} ] ; then return 0 ; fi
	# ${var,,} convert to lower case ( ${var^^} for upper case )
    $grace -hardcopy \
        -hdevice $dev \
        -printfile ${nam%.xvg}.${dev} \
    	${nam} 

}

function grace_xvg_plot_running_average {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG

    if [ -s ${nam%.xvg}.$dev ] ; then return 0 ; fi
    $grace -hardcopy \
        -hdevice $dev \
        -printfile ${nam%.xvg}.$dev \
        ${nam} \
        -pexec 'runavg(S0,100)'

}

function grace_xvg_plot_nxy {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG
    
	if [ -s ${nam%.xvg}.$dev ] ; then return 0 ; fi
    $grace -hardcopy \
        -nxy \
		${nam} \
        -hdevice $dev \
        -printfile ${nam%.xvg}.$dev
}


function grace_xvg2img {
    local x="$1"
	
    local n=${x%.xvg}
    local ext=${x##*.}
    # we want an XVG file
    if [ "$ext" != "xvg" ] ; then return 1 ; fi
    # which, obviously, must exist and not be empty
    if [ ! -s "$x" ] ; then return 2 ; fi

    # do not repeat work already done
    if [ ! -e ${n}.SVG ] ; then
        $grace -hardcopy \
		       -hdevice SVG \
		       -printfile ${n}.SVG \
			   -nxy ${x}
    fi
    if [ ! -e ${n}.PNG ] ; then
        $grace -hardcopy \
		       -hdevice PNG \
			   -printfile ${n}.PNG \
			   -autoscale xy \
			   -fixed 1536 1536 \
			   ${comment# -viewport 0 0 1.0 1.0 } \
			   ${comment# -world 0 0 10000 10000 } \
			   -nxy ${x}
    fi
	return 0
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
    include grace_xvg_plot.bash

    grace_xvg2img $*
else
    export GRACE_XVG_PLOT
fi

