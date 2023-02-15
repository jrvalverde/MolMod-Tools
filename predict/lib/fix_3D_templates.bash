#!/bin/bash

function fix_3D_templates(){
# XXX JR XXX THIS IS AN UGLY HACK PENDING CORRECT REWRITING
# THIS IS BECAUSE IN SOME CASES, PepBuilder results in negative coordinates
# larger than -1000.000. This shifts all the coordinates one space right
# and breaks the PDB format, leading to a failure of CABS.
# Chimera can read the pdb file and "fix" the coordinates so we just
# read the file and save it again. This does not actually FIX the file,
# but distorts the X and Y coordinates so they fit in the box.
# Thus, it results in a distorted starting structure, but we do not
# care because any way, we will model it extensively with CABS.
for i in *.pdb ; do
    cp $i $i.orig
    DISPLAY='' chimera --nogui <<END
        open $i
        write format pdb 0 $i
END
done
}

#[[ $0 != $BASH_SOURCE ]] && echo "Script is being sourced" || echo "Script is being run"
#check if we are being sourced:
# as an included script we do not want to execute anything
if [[ $0 == $BASH_SOURCE ]] ; then
    # if we are not being included by other file, then we are being
    # called as an independent program. Set "INCLUDE=yes" to include
    # all the necessary files and do our work.
    LIB=`dirname $0`
    # this may be either a command or a library function
    if [ -d "$LIB/lib" ] ; then
        LIB="$LIB/lib"
    fi
    [[ -v FS_FUNCS ]] || source $LIB/fs_funcs.bash
    [[ -v UTIL_FUNCS ]] || source $LIB/util_funcs.bash
    
    fix_3D_templates "$@"
else
    export FIX_3D_TEMPLATES='FIX_3D_TEMPLATES'
fi

