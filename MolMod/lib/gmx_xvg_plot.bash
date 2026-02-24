#!/bin/bash
#

GMX_XVG_PLOT="GMX_XVG_PLOT"

LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash
include grace_xvg_plot.bash
include fgp_xvg_plot.bash

grace=`which grace`

function gmx_xvg_plot {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG or png or svg or pdf

    if [ -s ${nam%.xvg}.${dev} ] ; then return 0 ; fi
	if [ "$dev" = "PNG" -o "$dev" = "SVG" ] ; then
	    grace_xvg_plot "$nam" "$dev"
    elif [ "$dev" = "png" -o "$dev" = "svg" -o "$dev" = "pdf" ] ; then
	    fgp_xvg_plot "$nam" "$dev"
	else
	    echo "Unknown device $dev"
	fi

}

function gmx_xvg_plot_running_average {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG

    if [ -s ${nam%.xvg}.$dev ] ; then return 0 ; fi
    $grace -hardcopy \
        -hdevice $dev \
        -printfile ${nam%.xvg}.$dev \
        ${nam} \
        -pexec 'runavg(S0,100)'

}

function gmx_xvg_plot_nxy {
    local nam=${1:-file}
    local dev=${2:-PNG}	# PNG or SVG
    
	if [ -s ${nam%.xvg}.$dev ] ; then return 0 ; fi
    $grace -hardcopy \
        -nxy \
		${nam} \
        -hdevice $dev \
        -printfile ${nam%.xvg}.$dev
}


function gmx_xvg2img {
    # do all plots
    local x="${1:-out.xvg}"
	
    local n=${x%.xvg}
    local ext=${x##*.}
    # we want an XVG file
    if [ "$ext" != "xvg" ] ; then return 1 ; fi
    # which, obviously, must exist and not be empty
    if [ ! -s "$x" ] ; then return 2 ; fi

    grace_xvg2img "$x"
	fgp_xvg_plot "$x"
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
    include gmx_xvg_plot.bash

    gmx_xvg2img $*
else
    export GMX_XVG_PLOT
fi

