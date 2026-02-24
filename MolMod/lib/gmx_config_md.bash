#!/bin/bash
#
# NAME
#	gmx_config_mg - desc
#
# SYNOPSIS
#	gmx_config_mg [arg] [arg]
#
# DESCRIPTION
#	
#
#
# ARGUMENTS
#	arg	- desc
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


GMX_CONFIG_MD_H="GMX_CONFIG_MD_H"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash


function gmx_config_md() {
    if ! funusage $# [name] [pressure] [temperature] [dt] [npicos] ; then return $ERROR ; fi 
    notecont "$*"
    local name=${1:-md}				        # production 
    local pressure=${2:-1.0}		        # bar
    local temperature=${3:-310}		        # Kelvin
    local dt=${4:-0.002}			        # picoseconds (default 2 fs)
    local npicos=${5:-10000}		        # picoseconds (default 10 ns)
	
    local nsteps=`echo "${npicos}/${dt}" | bc`
    local nstout=`echo "$nsteps / 2000" | bc`	    # ensure we save 2,000 frames
    local nstcalcenergy=100
    local nstenergy=$(( nstout / nstcalcenergy ))   # round off with int math
    nstenergy=$(( nstenergy * 100 ))                # and back

    echo "dt=$dt"
    echo "time=$npicos"
    echo "nsteps=$nsteps"
    echo "nstout=$nstout"
    echo "nstenergy=$nstenergy"
    echo "nstcalcenergy=$nstcalcenergy"

	#	From: http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/08_MD.html
	#
	# Upon completion of the two equilibration phases, the system should now be
	# well-equilibrated at the desired temperature and pressure. We are now 
	# ready to release the position restraints and run production MD for data 
	# collection. The process is just like we have seen before, as we will 
	# make use of the checkpoint file (which in this case now contains preserve 
	# pressure coupling information) to grompp. 
	
	# Before proceeding, find out how many groups do we have for
	# temperature coupling
	#
	# we want to treat solute and solvent as separate groups
	# but if there are no non-protein atoms, then the non-protein group
	# does not exist
	local n=`out='no' grep  -v "^[;#]" Complex.top | while read line ; do 
        	if [ "$out" == 'yes' ] ; then 
            	echo $line 
        	fi 
    		if [ "$line" == "[ molecules ]" ] ; then 
            	out="yes" 
        	fi
    	done | grep -v '^\[' | grep -v "^Protein" | wc -l`

	if [ $n -eq 0 ] ; then
    	#local grp="Protein"
        local grp="System"
        local comm_grps=$grp
        local tc_grps=$grp
        local e_grps=''
    	local tau_t="0.1"
    	local ref_t="$temperature"
	else
    	# XXX JR XXX IDEALLY THIS SHOULD BE SOLUTE SOLVENT
        #   but we would need to know if solvate=yes
    	local grp="Protein Non-Protein"
        #local grp="Solute Solvent"
        local comm_grps=$grp
    	local tc_grps=$grp
        local e_grps=$grp
        local tau_t="0.1	0.1"
    	local ref_t="$temperature	$temperature"
	fi
    local mdp="$name.mdp"
    # Create production run md.mdp file
    cat << EOF >| $mdp
; MD PRODUCTION RUN

; 7.3.3 Run Control
integrator              = md                    ; md integrator
tinit                   = 0                     ; [ps] starting time for run
dt                      = $dt                   ; [ps] time step for integration
nsteps                  = $nsteps               ; maximum number of steps to integrate
;nsteps                  =  2 500 000             ; 0.002 * 2,500,000 = 5,000 ps = 5 ns
;nsteps                  = 10 000 000             ; 0.002 * 10,000,000 = 20,000 ps = 5 ns
comm_mode               = Linear                ; remove center of mass translation
nstcomm                 = 100                   ; [steps] frequency of center of mass motion removal
comm_grps               = $comm_grps   ; group(s) for center of mass motion removal
continuation		= yes			; Restarting after NPT 

; 7.3.8 Output Control
nstxout                 = $nstout          ; [steps] freq to write coordinates to trajectory
nstvout                 = $nstout          ; [steps] freq to write velocities to trajectory
nstfout                 = $nstout          ; [steps] freq to write forces to trajectory
nstlog                  = $nstout          ; [steps] freq to write energies to log file
nstenergy               = $nstenergy       ; [steps] freq to write energies to energy file
        ; nstenergy should be a multiple of nstcalcenergy, which defaults to 100
nstxout-compressed      = $nstout          ; [steps] freq to write coordinates to xtc trajectory
compressed-x-precision  = $nstout          ; [real] precision to write xtc trajectory
compressed-x-grps       = System        ; group(s) to write to xtc trajectory
energygrps              = $e_grps        ; group(s) to write to energy file

; LANGEVIN DYNAMICS OPTIONS
; Friction coefficient (amu/ps) and random seed
bd-fric                  = 0
;ld-seed                  = 1963

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
nstlist                 = 12            ; [steps] freq to update neighbor list
ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
periodic_molecules      = no
; nblist cut-off        
rlist                   = 1.0           ; [nm] cut-off distance for the short-range neighbor list
;verlet-buffer-tolerance = 1.0
verlet-buffer-tolerance = 1e-1
;verlet-buffer-tolerance = 0.005

; 7.3.10 Electrostatics
coulombtype             = PME-Switch    ; Particle-Mesh Ewald electrostatics
rcoulomb                = 0.8           ; [nm] distance for Coulomb cut-off
rlistlong               = 0.8           ; [nm] Cut-off distance for the long-range neighbor list. This parameter is only relevant for a twin-range cut-off setup with switched potentials
rcoulomb_switch         = 0.77          ; [nm] (difference should be < 5% to rcoulomb)
#rcoulomb                = 1.2		; with verlet lists rcoulomb >= rvdw
#rcoulomb-switch         = 1.15		; switching range should be 5% or less
; Relative dielectric constant for the medium and the reaction field
epsilon_r                = 1
epsilon_rf               = 1

; 7.3.11 VdW
vdwtype                 = Cut-off
vdw_modifier            = Force-switch  ; twin-range shift with rlist where rvdw >= rlist
rvdw                    = 0.8           ; [nm] distance for LJ cut-off
rvdw-switch             = 0.77          ; [nm]
DispCorr                = EnerPres      ; apply long range dispersion corrections for energy
; Extension of the potential lookup tables beyond the cut-off
table-extension          = 1
; Separate tables between energy group pairs
;undocumented error;energygrp_table          = $e_grps

; 7.3.13 Ewald
fourierspacing          = 0.12          ; [nm] grid spacing for FFT grid when using PME
; FFT grid size, when a value is 0 fourierspacing will be used
fourier_nx               = 0
fourier_ny               = 0
fourier_nz               = 0
pme_order               = 4             ; interpolation order for PME, 4 = cubic
ewald_rtol              = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb
ewald_geometry           = 3d
epsilon_surface          = 0
;obsolete;optimize_fft             = yes

; IMPLICIT SOLVENT ALGORITHM
implicit_solvent         = No

; 7.3.14 Temperature Coupling
;tcoupl                  = nose-hoover  ; temperature coupling with Nose-Hoover ensemble
;tcoupl			= berendsen	 ; Berendsen thermostat
tcoupl                   = V-rescale
; Groups to couple separately
tc_grps                 = $tc_grps        ; groups to couple seperately to temperature bath
; Time constant (ps) and reference temperature (K)
tau_t                   = $tau_t                ; [ps] time constant for coupling
ref_t                   = $ref_t                ; [K] reference temperature for coupling

; 7.3.15 Pressure Coupling
pcoupl                  = Parrinello-Rahman     ; pressure coupling where box vectors are variable
pcoupltype              = isotropic             ; pressure coupling in x-y-z directions
nstpcouple              = 10			; -1 = nstlist
; Time constant (ps), compressibility (1/bar) and reference P (bar)
tau_p                   = 2.0                   ; [ps] time constant for coupling
;tau_p                    = 0.5
compressibility         = 4.5e-5                ; [bar^-1] compressibility
ref_p                   = $pressure                   ; [bar] reference pressure for coupling

; 7.3.17 Velocity Generation
gen_vel                 = no            ; velocity generation turned off
					; we start from equilibration velocities
; 7.3.18 Bonds
constraints             = h-bonds       ; convert all h-bonds to constraints
constraint_algorithm    = LINCS         ; LINear Constraint Solver
lincs_order             = 4             ; highest order in the expansion of the contraint coupling matrix
;lincs_iter              = 1             ; number of iterations to correct for rotational lengthening
lincs-iter              = 2             ; number of iterations to correct for rotational lengthening
lincs_warnangle         = 30            ; [degrees] maximum angle that a bond can rotate before LINCS will complain

;optimize_fft            = yes
EOF
    echo ""
    echo "$mdp created"
    echo ""
		
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

    gmx_config_md $*
else
    export GMX_CONFIG_MD
fi
