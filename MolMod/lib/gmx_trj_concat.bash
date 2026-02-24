#!/bin/bash
# NAME
#	gmx_trj_concat -- concatenate GROMACS trajectories
#
# SYNOPSIS
#	gmx_trj_concat prefix
#
# DESCRIPTION
#	If a file named $prefix.{xtc|trj} does not exist, look for
# files named ${md}_number.trr or generally ${md}*.trr and concatenate
# them to obtain a $md.trr file. In the process, also generate if needed
# and join XTC equivalent trajectories for all parts and the final total,
# and concatenate their corresponding energgy .EDR files.
#
# ARGUMENTS
#	prefix	- the prefix to identify the parts and final outputs
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


GMX_TRJ_CONCAT="GMX_TRJ_CONCAT"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash

function gmx_trj_concat() {
    if ! funusage $# [md_prefix] ; then return $ERROR ; fi 
    notecont "$*"

    local md=${1:-md}
    
    local cmdtrr=''
    local cmdxtc=''
    local cmdedr=''
    local NUMERIC="NO"		# use ${md}_#.trr in numerical order
    local MTIME="YES"		# sort ${md}*.trr by last modification time
    local ERR=1
    
    #gmx trjcat -f traj_1.xtc traj_2.xtc -o final_traj.xtc (-settime)
    # get a trajectory with correct time steps
    #    yes c | gmx trjcat -f `ls -r ${md}_*trr | tr '\n' ' '` -settime -o ${md}.ok.trr


    # if either a .trr or a .xtc trajectory already exist with this name
    # then we do not need to concatenate parts
    if [ ! -s ${md}.trr -a ! -e ${md}.xtc ] ; then
        notecont "MD trajectory $md.trr/xtc does not exist! Trying to build it..."
        notecont "	We will use \${md}_\$no.trr for \$no=1 to n"
        # use -conect to preserve bonds in coarse grained trajectories or when
        # including non-protein molecules when converting to PDB

        cmdtrr="yes c | gmx trjcat -cat -settime -o ${md}.trr -f"
        cmdxtc="yes c | gmx trjcat -cat -settime -o ${md}.xtc -f"
        cmdedr="yes c | gmx eneconv -settime -o ${md}.edr -f"
        if [ "$NUMERIC" = "YES" ] ; then
	    i=1
            while [ -e ${md}_$i.trr ] ; do  

        	# prepare command to make trajectory
        	cmdtrr="${cmdtrr} ${md}_${i}.trr"

		# prepare command to make compressed trajectory
		if [ ! -s  ${md}_${i}.xtc ] ; then
	            echo System | gmx trjconv -o ${md}_${i}.xtc \
	        	-f ${md}_${i}.trr -s ${md}_${i}.tpr
		fi
        	cmdxtc="${cmdxtc} ${md}_${i}.xtc"

        	# prepare command to make energy file
		if [ -s ${md}_$i.edr ] ; then
	            cmdedr="${cmdedr} ${md}_${i}.edr"
        	else
                    notecont "WARNING: ${md}_${i}.edr DOES NOTE EXIST!"
                    notecont "Your ENERGY plots will be unreliable"
        	fi

		# preserve the last run input file
		if [ ! -s ${md}.tpr ] ; then
                    # use the last run input file available
	            cp ${md}_${i}.tpr ${md}.tpr
	            # only use the first run input file (next iterations will find that a
	            # topology does already exist
                    #cp ${md}_1.tpr ${md}.tpr
		    # we prefer the last because if the trajectory was extended
		    # by modifying the tpr, the lastone should match the
		    # whole trajectory
		fi

        	# ensure last output structure is preserved
		cp ${md}_$i.gro ${md}.gro


        	i=$((i + 1))
            done
            if [ $i -ne 1 ] ; then
		eval $cmdtrr
		eval $cmdxtc
		eval $cmdedr
            else
        	notecont "	No partial sub-trajectories ${md}_* found!"
		return $(( ERR++ ))
            fi
	elif [ "$MTIME" = "YES" ] ; then
	    i=1
	    ls -rf1 ${md}*.trr \
            | while read part_trr ; do  

        	# prepare command to make trajectory
        	cmdtrr="${cmdtrr} ${part_trr}"
		
		part=${part_trr%.trr}

		# prepare command to make compressed trajectory
		if [ ! -s  ${part}.xtc ] ; then
	            echo System | gmx trjconv -o ${part}.xtc \
	        	-f ${part_trr} -s ${part}.tpr
		fi
        	cmdxtc="${cmdxtc} ${part}.xtc"

        	# prepare command to make energy file
		if [ -s ${part}.edr ] ; then
	            cmdedr="${cmdedr} ${part}.edr"
        	else
                    notecont "WARNING: ${part}.edr DOES NOTE EXIST!"
                    notecont "Your ENERGY plots will be unreliable"
        	fi

		# preserve the last run input file
		if [ ! -s ${md}.tpr ] ; then
                    # use the last run input file available
	            cp ${part}.tpr ${md}.tpr
	            # only use the first run input file (next iterations will find that a
	            # topology does already exist
                    #cp ${part}.tpr ${md}.tpr

		fi

        	# ensure last output structure is preserved
		if [ -s "${part}.gro" ] ; then
		    cp ${part}.gro ${md}.gro
		fi
		
		# update count
        	i=$((i + 1))
            done
            if [ $i -gt 1 ] ; then
		eval $cmdtrr
		eval $cmdxtc
		eval $cmdedr
            else
        	notecont "No partial sub-trajectories ${md}*.trr found!"
		return $(( ERR++ ))
            fi
	fi
    else
        notecont "$md.{xtc|trr} already exists, refusing to overwrite"
	return $(( ERR++ ))
    fi

    if [ ! -e ${md}.edr ] ; then
        notecont "ERROR: ${md}.edr FILE DOES NOT EXIST"
        return $(( ERR++ ))
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

    gmx_trj_concat $*
else
    export GMX_TRJ_CONCAT
fi
