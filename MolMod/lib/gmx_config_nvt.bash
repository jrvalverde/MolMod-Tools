#!/bin/bash
#
# NAME
#	gmx_config_nvt - desc
#
# SYNOPSIS
#	gmx_config_nvt [arg] [arg]
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


GMX_CONGIF_NVT_H="GMX_CONGIF_NVT_H"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash


function gmx_config_nvt() {
    if ! funusage $# [md_name] [temperature] ; then return $ERROR ; fi 
    notecont "$*"
    # Create NVT equilibration run file
	local name=${1:-nvt}
	local temperature=${2:-310}		# 310⁰K
    
	# Before proceeding, find out how many groups do we have for
	# temperature coupling
	#
	# we want to treat solute and solvent as separate groups
	# but if there are no non-protein atoms, then the non-protein group
	# does not exist
	#
	#	XXX JR XXX SEE OPLS-AA.BASH
	#
	local n=`out='no' grep  -v '^[;#]' Complex.top | while read line ; do 
        	if [ "$out" == 'yes' ] ; then 
            	echo $line 
        	fi 
    		if [ "$line" == '[ molecules ]' ] ; then 
            	out='yes'
        	fi
    	done | grep -v '^\[' | grep -v '^Protein' | wc -l`

	if [ $n -eq 0 ] ; then
    	local grp="Protein"
    	local tau_t="0.1"
    	local ref_t="$temperature"
	else
    	# XXX JR XXX IDEALLY THIS SHOULD BE SOLUTE SOLVENT"
    	local grp="Protein Non-Protein"
    	local tau_t="0.1	0.1"
    	local ref_t="$temperature	$temperature"
	fi

    cat << EOF >| nvt.mdp
;title   = NVT equilibration

; NVT EQUILIBRATION
; This file calls for an MD run of 250,000 steps with a 2 fs timestep (a total 
; of 500 ps). The 'define = -DPOSRES' line initiates the backbone restraints 
; on the protein, which should remain on until production MD. Temperature 
; coupling is performed using the Berendsen method. In order to be sure 
; velocities (and therefore temperature) are evenly distributed across all of 
; the molecule types, it is a good idea to couple protein atoms and 
; non-protein atoms to separate baths. Without separate coupling, you run the 
; risk weird phenomena such as a system where the water molecules are at 
; 350 K and the protein is at 200 K. Finally, all bonds are constrained using 
; the linear constraint solver (LINCS) algorithm. Review the GROMACS manual 
; if you are unfamiliar with the implementation or purpose of any of these 
; parameters.
;
; Note that for very large systems, 200ps might be insufficient.

; 7.3.2 Preprocessing
define                  = -DPOSRES      ; position restrain the protein

; 7.3.3 Run Control
integrator              = md            ; md integrator
tinit                   = 0             ; [ps] starting time for run
;dt                      = 0.001         ; [ps] time step for integration
dt                      = 0.002         ; [ps] time step for integration
nsteps                  = 250000        ; number of steps to integrate, 0.002 * 250,000 = 500 ps
comm_mode               = Linear        ; remove center of mass translation
nstcomm                 = 100           ; [steps] frequency of mass motion removal
comm_grps               = $grp   		; group(s) for center of mass motion removal

; 7.3.8 Output Control
nstxout                 = 25000         ; [steps] freq to write coordinates to trajectory
nstvout                 = 25000         ; [steps] freq to write velocities to trajectory
nstfout                 = 25000         ; [steps] freq to write forces to trajectory
nstlog                  = 100           ; [steps] freq to write energies to log file
nstenergy               = 100           ; [steps] freq to write energies to energy file
nstxout-compressed      = 100           ; [steps] freq to write coordinates to xtc trajectory
compressed-x-precision  = 1000          ; [real] precision to write xtc trajectory
compressed-x-grps       = System        ; group(s) to write to xtc trajectory
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
nstlist                 = 10            ; [steps] freq to update neighbor list
;ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
rlist                   = 0.8           ; [nm] cut-off distance for the short-range neighbor list

; 7.3.10 Electrostatics
coulombtype             = PME           ; Particle-Mesh Ewald electrostatics
rcoulomb                = 0.8           ; [nm] distance for Coulomb cut-off

; 7.3.11 VdW
vdwtype                 = cut-off       ; twin-range cut-off with rlist where rvdw >= rlist
rvdw                    = 0.8           ; [nm] distance for LJ cut-off
DispCorr                = EnerPres      ; apply long range dispersion corrections

; 7.3.13 Ewald
fourierspacing          = 0.12          ; [nm] grid spacing for FFT grid when using PME
pme_order               = 4             ; interpolation order for PME, 4 = cubic
ewald_rtol              = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb

; 7.3.14 Temperature Coupling
;tcoupl                  = berendsen    ; temperature coupling with Berendsen-thermostat
tcoupl			= V-rescale	; modified Berendsen thermostat
tc_grps                 = $grp        	; groups to couple seperately to temperature bath
tau_t                   = $tau_t        ; [ps] time constant for coupling
ref_t                   = $ref_t        ; [K] reference temperature for coupling

; 7.3.17 Velocity Generation
gen_vel                 = yes           ; generate velocities according to Maxwell distribution of temperature
gen_temp                = $temperature  ; [K] temperature for Maxwell distribution
gen_seed                = -1            ; [integer] used to initialize random generator for random velocities

; Pressure coupling is off
pcoupl			= no 		; no pressure coupling in NVT

; 7.3.18 Bonds
constraints             = h-bonds       ; convert all H-bonds to constraints
constraint_algorithm    = LINCS         ; LINear Constraint Solver
continuation            = no            ; no = apply constraints to the start configuration
lincs_order             = 4             ; highest order in the expansion of the contraint coupling matrix
lincs_iter              = 1             ; number of iterations to correct for rotational lengthening
lincs_warnangle         = 30            ; [degrees] maximum angle that a bond can rotate before LINCS will complainEOF
EOF

    echo ""
    echo "$name.mdp created"
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

    gmx_config_nvt $*
else
    export GMX_CONGIF_NVT
fi
