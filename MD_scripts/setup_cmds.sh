#!/bin/bash
#	Copyright 2018 JOSE R VALVERDE, CNB/CSIC.

# Select gromacs commands
gmx=`which gmx`
if [ "$gmx" == "" ] ; then
	#echo "gmx '$gmx' not found"
        export g_check=gmxcheck
	export g_energy=g_energy
	export g_rms=g_rms
	export g_rmsf=g_rmsf
	export g_gyrate=g_gyrate
	export g_cluster=g_cluster
	export g_sas=g_sas
	export g_hbond=g_hbond
	export make_ndx=make_ndx
        export trjconv=trjconv
        export tpbconv=tpbconv
	export xpm2ps=xpm2ps
        export pdb2gmx=pdb2gmx
	export do_dssp=do_dssp
        export ngmx=ngmx
else
	#echo "gmx '$gmx' found"
        export g_check="gmx check"
	export g_energy="gmx energy"
	export g_rms="gmx rms"
	export g_rmsf="gmx rmsf"
	export g_gyrate="gmx gyrate"
	export g_cluster="gmx cluster"
	export g_sas="gmx sasa"
	export g_hbond="gmx hbond"
	export make_ndx="gmx make_ndx"
	export trjconv="gmx trjconv"
	export tpbconv="gmx convert-tpr"
	export xpm2ps="gmx xpm2ps"
	export pdb2gmx="gmx pdb2gmx"
	export do_dssp="gmx do_dssp"
	export ngmx="gmx view"
fi

export grace=`which grace`
# provide defaults for external variables
export chimera=${chimera:-`which chimera`}
export babel=${babel:-`which babel`}
export reduce=${reduce:-`which reduce`}
export haad=${haad:-`which haad`}
export DSSP=~/bin/dssp
