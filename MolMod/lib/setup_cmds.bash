#!/bin/bash
#	Copyright 2018 JOSE R VALVERDE, CNB/CSIC.

SETUP_CMDS='SETUP_CMDS'
GMX_SETUP_CMDS='GMX_SETUP_CMDS'

# Select gromacs commands
gmx=`which gmx`
if [ "$gmx" == "" ] ; then
	#echo "gmx '$gmx' not found"
	export do_dssp=do_dssp
    export editconf=editconf
    export g_check=g_check
	export g_chi=g_chi
	export g_cluster=g_cluster
    export genboxadd=genbox
    export genbox=genbox
    export genion=genion
	export g_energy=g_energy
	export g_gyrate=g_gyrate
	export g_hbond=g_hbond
	export g_rmsf=g_rmsf
	export g_rms=g_rms
    export grompp=grompp
	export g_sas=g_sas
	export make_ndx=make_ndx
    export mdrun=mdrun
    export ngmx=ngmx
    export pdb2gmx=pdb2gmx
    export tpbconv=tpbconv
    export trjconv=trjcat
    export trjconv=trjconv
	export xpm2ps=xpm2ps
else
	#echo "Found gmx as $gmx"
	export do_dssp=`which do_dssp454`	# latest do_dssp is buggy, use a previous one
	export do_dssp="gmx dssp"			# 2025
	export do_dssp=${do_dssp:-"gmx do_dssp"}
	export editconf="gmx editconf"
    export g_check="gmx check"
	export g_chi="gmx chi"
	export g_cluster="gmx cluster"
    export genboxadd="gmx insert-molecules"
    export genbox="gmx solvate"
    export genion="gmx genion"
	export g_energy="gmx energy"
	export g_gyrate="gmx gyrate"
	export g_hbond="gmx hbond"
	export g_rmsf="gmx rmsf"
	export g_rms="gmx rms"
	export grompp="gmx grompp"
	export g_sas="gmx sasa"
	export mdrun="gmx mdrun"
	export make_ndx="gmx make_ndx"
	export ngmx="gmx view"
	export pdb2gmx="gmx pdb2gmx"
	export tpbconv="gmx convert-tpr"
	export trjcat="gmx trjcat"
	export trjconv="gmx trjconv"
	export xpm2ps="gmx xpm2ps"
fi

# provide defaults for external variables
#
# general tools
export babel=${babel:-`which babel`}		# get it from http://openbabel.org
export chimera=${chimera:-`which chimera`}	# get it from http://www.cgl.ucsf.edu/chimera/
#
# add H
export reduce=${reduce:-`which reduce`}}	# get it from http://kinemage.biochem.duke.edu/software/
export REDUCE_HET_DICT=~/share/kinemage/reduce_wwPDB_het_dict.txt

export haad=${haad:-`which haad`}		    # get it from http://zhanglab.ccmb.med.umich.edu/HAAD
#
# QM (unsupported outside CNB/CSIC)
#export openmopac=${openmopac:-`which MOPAC2009.exe`}	# get if from http://OpenMopac.net
export openmopac=~/contrib/mopac/MOPAC2009.exe
export MOPAC_LICENSE=~/contrib/mopac
export freeON=${freeON:-`which FreeON.sh`}		    # get freeON at http://freeon.org
export ergoSCF=${ergoSCF:-`which ErgoSCF.bash`}		# get ergo at http://ergoscf.org
#
# topology builders
export mktop=${mktop:-`which mktop_2.2.1.pl`}		# you can get it from http://www.aribeiro.net.br/mktop/
export topolgen=${topolgen:-`which topolgen`}		# you can get it from http://www.gromacs.org/@api/deki/files/88/=topolgen-1.1.tgz
#export topolbuild=${topolbuild:-`which topolbuild`}	# you can get get it from http://www.gromacs.org/Downloads/User_contributions/Other_software
export topolbuild=~/contrib/topolbuild1_3/bin/topolbuild	# get it from http://www.gromacs.org/Downloads/User_contributions/Other_software
export topolbuilddat=~/contrib/topolbuild1_3/dat/
export acpype=${acpype:-`which acpype`}	            # get it from http://www.gromacs.org/Downloads/User_contributions/Other_software
#
# analysis
# DSSP is an environment variable used by gromacs do_dssp pointing to the dssp executable
export DSSP=${DSSP:-`which dssp`}	# needed for Gromacs do_dssp
export DSSP=~/bin/dssp			    # these two take different parameters, beware
export DSSP=~/bin/dsspcmbi		    # needed for Gromacs do_dssp
#
# graphical representation
export grace=${grace:-`which grace`}

