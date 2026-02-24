#!/bin/bash
#
# NAME
#	gmx_config_em - desc
#
# SYNOPSIS
#	gmx_config_em [arg] [arg]
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


GMX_CONFIG_EM_H="GMX_CONFIG_EM"
LIB=`dirname ${BASH_SOURCE[0]}`	# located in our same directory
#LIB=${BASH_SOURCE[0]##*/}
source $LIB/include.bash
include util_funcs.bash


function gmx_config_em() {
    if ! funusage $# [name] [mode] [emtol] ; then return $ERROR ; fi 
    notecont "$*"
	local name=${1:-em}			# em, minim are common names for this file
	local mode=${2:-solution}	# valid values are vacuum and solution
	local emtol=''				# kJ/mol/nm
	
	if [ "$emtol" = '' ] ; then
	    if [ "$mode" = 'solution' ] ; then 
			emtol=1000.0 
		elif [ "$mode" = 'vacuum' ] ; then
			emtol=10.0
		else
		    echo errexit "Unknown minimization mode (must be solution or vacuum)"
		fi
	fi
	
    if [ "$mode" == "solution" ] ; then
		# Create $name.mdp file
    	#	we force creation of em.mdp even if it exists with '>|'
        cat << EOF >| $name.mdp
; ENERGY MINIMIZATION 
; This parameter file calls for a steepest descent energy minimization not 
; to exceed 10,000 steps. The minimization will be considered successful 
; if the maximum force on any atom is less than 1000 kJ/mol/nm, at which 
; point the minimization will stop. Other parameters of note include periodic 
; boundary conditions in the x-, y-, and z-directions, 0.8 nm cut-offs for 
; short-range VDW and electrostatic interactions, and particle-mesh Ewald 
; long-range electrostatics. If any of these settings do not make sense, it 
; is unwise to proceed without reading about them in Chapter 7 of the manual.
;
; Note that for large systems, a max. force < 1000 kJ/mol/nm may be too small
; and a lower value, e.g. 10.0 or 100.0 may be an option

; 7.3.2 Preprocessing
define                   = -DFLEXIBLE    ; defines to pass to the preprocessor

; 7.3.3 Run Control
integrator               = cg ; steep    ; conjugate gradients energy minimization
nsteps                   = 10000         ; maximum number of steps to integrate
constraints              = none

; 7.3.5 Energy Minimization
emtol                    = $emtol        ; [kJ/mol/nm] minimization is converged when max force is < emtol
emstep                   = 0.01          ; [nm] initial step-size
nstcgsteep               = 10            ; do a steep every 10 steps of cg
;nstcomm                  = 1			 ; no centering when using constraints

; 7.3.8 Output Control
nstxout                 = 100           ; [steps] freq to write coordinates to trajectory
nstvout                 = 100           ; [steps] freq to write velocities to trajectory
nstfout                 = 100           ; [steps] freq to write forces to trajectory
nstlog                  = 1             ; [steps] freq to write energies to log file
nstenergy               = 1             ; [steps] freq to write energies to energy file
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
nstlist                 = 10            ; [steps] freq to update neighbor list
ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
rlist                   = 0.8           ; [nm]  distance for the short-range neighbor list

; 7.3.10 Electrostatics
coulombtype              = PME           ; Particle-Mesh Ewald electrostatics
rcoulomb                 = 0.8           ; [nm] distance for Coulomb cut-off

; 7.3.11 VdW
vdwtype                 = cut-off       ; twin-range cut-off with rlist where rvdw >= rlist
rvdw                    = 0.8           ; [nm] distance for LJ cut-off
DispCorr                = Ener          ; apply long range dispersion corrections for energy

; 7.3.13 Ewald
fourierspacing          = 0.12          ; [nm] grid spacing for FFT grid when using PME
pme_order               = 4             ; interpolation order for PME, 4 = cubic
ewald_rtol              = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb

Tcoupl                   = no
Pcoupl                   = no
gen_vel                  = no
;optimize_fft             = yes
EOF
    elif [ "$mode" = "vacuum" ] ; then
	    # Create em.mdp file
        # we force creation of em.mdp even if it exists with '>|'
        cat << EOF >| $name.mdp
; ENERGY MINIMIZATION 
; This parameter file calls for a steepest descent energy minimization not 
; to exceed 10,000 steps. The minimization will be considered successful 
; if the maximum force on any atom is less than 1000 kJ/mol/nm, at which 
; point the minimization will stop. Other parameters of note include periodic 
; boundary conditions in the x-, y-, and z-directions, 0.8 nm cut-offs for 
; short-range VDW and electrostatic interactions, and particle-mesh Ewald 
; long-range electrostatics. If any of these settings do not make sense, it 
; is unwise to proceed without reading about them in Chapter 7 of the manual.
;
; Note that for large systems, a max. force < 1000 kJ/mol/nm may be too small
; and a lower value, e.g. 10.0 or 100.0 may be an option

title		= Minimization in vacuo ; Title of run

; Define can be used to control processes
define          = -DFLEXIBLE

; Parameters describing what to do, when to stop and what to save
integrator	= cg ; Algorithm selection. 
                 ;cg = conjugate gradients
				 ;steep = steepest descent minimization 
				 ;MD = Leap Frog algorith for integrating Newtonś equations of motion )
nsteps		= 10000		; Maximum number of (minimization) steps to perform

; 7.3.5 Energy Minimization
emtol		    = $emtol		; Stop minimization when the energy changes by less than emtol kJ/mol/nm.
emstep          = 0.01          ; [nm] initial step-size
nstcgsteep      = 10            ; do a steep every 10 steps of cg

nstenergy	= 1		; Write energies to disk every nstenergy steps
nstxtcout	= 100		; Write coordinates to disk every nstxtcout steps
xtc_grps	= System	; Which coordinate group(s) to write to disk
energygrps	= System	; Which energy group(s) to write to disk

; Parameters describing how to find the neighbors of each atom and how to calculate the interactions
nstlist		= 5		; Frequency to update the neighbor list and long range forces
ns_type		= grid	; Method to determine neighbor list (simple, grid)
constraints	= none		; Bond types to replace by constraints
pbc		= xyz		; Periodic Boundary Conditions (yes/no)
rlist		= 1.4		; [nm] Cut-off for making neighbor list (short range forces)
;NOTE: depending on system size we have variously used 1.4, 1.2, 1.0 or even 0.8
; YMMV, but be aware that you may need to change this here and below

;coulombtype	= PME		; Treatment of long range electrostatic interactions
coulombtype	= cut-off	; Treatment of long range electrostatic interactions
rcoulomb	= 1.4		; [nm] long range electrostatic cut-off

vdwtype		= cutoff
vdw-modifier	= force-switch
rvdw		= 1.4		; [nm] long range Van der Waals cut-off
rvdw-switch	= 1.0		; [nm] short range Van der Waals cut-off

DispCorr        = Ener          ; apply long range dispersion corrections for energy
EOF
    else
		# this should never happen as we have already tested it.
	    errexit "Unknown minimization mode (must be 'solution' or 'vacuum')"
    fi


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

    gmx_config_em $*
else
    export GMX_CONFIG_EM
fi
