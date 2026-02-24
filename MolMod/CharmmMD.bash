#!/bin/bash

ME=$0
export FUNCS_BASE=`dirname "$ME"`/lib
INCLUDE='yes'
. "$FUNCS_BASE"/setup_cmds.bash
INCLUDE='no'

export AMBERHOME=~/contrib/amber14
export PATH=~/contrib/acpype:~/contrib/amber14/bin:~/contrib/openbabel/bin:$PATH
export GMX_TOP=~/share/gromacs/top
# this overrides the value in the included libraries
export DSSP=~/bin/dssp
export acpype=`which acpype`
# used to determine number of threads
#xport mdrun="gmx mdrun -nt 1"
#xport nproc=`nproc`
#xport nproc=$((nproc / 4))     # or / 2 or / 1
export nproc=16
# used with -pin on to pin MDrun threads to consecutive MD-free processors
export nMDrunning=`ps ax | grep mdrun | grep -v grep | wc -l`
# hopefully all MD will use the same number of processors as us
export usedprocs=`bc -l <<< "$nproc * $nMDrunning"`		
export safe=yes

#defaults
MPI='no'
MPInodes=24
ligands='./LIGANDS'
addH='no'		# yes or no
addHmethod='gromacs'	# chimera or babel or gromacs
solvate='no'		# solvate (yes or no)
counterions='no'        # add counterions to neutralize system charges
useSaline='no'		# use physiologic saline serum (with extra Na and Cl)
pH=7.365		# default pH for babel H assignment
temperature='310'	# target temperature (in Kelvin)
pressure='1.0'		# target pressure (in bar)
optimize='no'		# add an optimization run
equilibrate='no'	# add an equilibration run
shortrun='no'		# add a 1 ns MD production run
longrun='no'		# add a 10 ns MD production run
verbose='no'		# produce additional output
forcefield='charmm27'	# force field to use
watermodel='tips3p'		# water model for this force field

myname=`basename $0`


#
#	Utility functions
#

# this one allows using options for echo
function echo.err() {
    >&2 echo "$@"               # >& goes to (fd 1 goes to fd 2)
}

# these will output - and -- options, instead of passing the to echo
function outerr() { cat <<< "ERROR: $@" 1>&2 ; }
# which one will be faster???
function outerr() { printf "ERROR: %s\n" "$*" >&2 ; }
# warnings go to stdout
function outwarn() { echo "WARNING: $@" ; }
# this one allows - and -- options interpretation by echo
function echo.warn() { echo -n "WARNING: " ; echo "$@" ; }


function banner() {
    #
    # Taken from http://stackoverflow.com/questions/652517/whats-the-deal-with-the-banner-command
    #
    #	Msg by jlliagre
    #		Apr 15 '12 at 11:52
    #
    # ### JR ###
    #	Input:	A text up to 10 letter wide
    # This has been included because banner(1) is no longer a standard
    # tool in many Linux systems. This way we avoid having a dependency
    # that might not be met.
    # It is often installed through package 'sysvbanner'
    #	npm has an ascii-banner tool (npm -g install ascii-banner)
    # Other alternatives are toilet(1) and figlet(1)

    typeset A=$((1<<0))
    typeset B=$((1<<1))
    typeset C=$((1<<2))
    typeset D=$((1<<3))
    typeset E=$((1<<4))
    typeset F=$((1<<5))
    typeset G=$((1<<6))
    typeset H=$((1<<7))

    function outLine
    {
      typeset r=0 scan
      for scan
      do
        typeset l=${#scan}
        typeset line=0
        for ((p=0; p<l; p++))
        do
          line="$((line+${scan:$p:1}))"
        done
        for ((column=0; column<8; column++))
          do
            [[ $((line & (1<<column))) == 0 ]] && n=" " || n="#"
            raw[r]="${raw[r]}$n"
          done
          r=$((r+1))
        done
    }

    function outChar
    {
        case "$1" in
        (" ") outLine "" "" "" "" "" "" "" "" ;;
        ("0") outLine "BCDEF" "AFG" "AEG" "ADG" "ACG" "ABG" "BCDEF" "" ;;
        ("1") outLine "F" "EF" "F" "F" "F" "F" "F" "" ;;
        ("2") outLine "BCDEF" "AG" "G" "CDEF" "B" "A" "ABCDEFG" "" ;;
        ("3") outLine "BCDEF" "AG" "G" "CDEF" "G" "AG" "BCDEF" "" ;;
        ("4") outLine "AF" "AF" "AF" "BCDEFG" "F" "F" "F" "" ;;
        ("5") outLine "ABCDEFG" "A" "A" "ABCDEF" "G" "AG" "BCDEF" "" ;;
        ("6") outLine "BCDEF" "A" "A" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("7") outLine "BCDEFG" "G" "F" "E" "D" "C" "B" "" ;;
        ("8") outLine "BCDEF" "AG" "AG" "BCDEF" "AG" "AG" "BCDEF" "" ;;
        ("9") outLine "BCDEF" "AG" "AG" "BCDEF" "G" "G" "BCDEF" "" ;;
        ("a") outLine "" "" "BCDE" "F" "BCDEF" "AF" "BCDEG" "" ;;
        ("b") outLine "B" "B" "BCDEF" "BG" "BG" "BG" "ACDEF" "" ;;
        ("c") outLine "" "" "CDE" "BF" "A" "BF" "CDE" "" ;;
        ("d") outLine "F" "F" "BCDEF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("e") outLine "" "" "BCDE" "AF" "ABCDEF" "A" "BCDE" "" ;;
        ("f") outLine "CDE" "B" "B" "ABCD" "B" "B" "B" "" ;;
        ("g") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "BCDE" ;;
        ("h") outLine "B" "B" "BCDE" "BF" "BF" "BF" "ABF" "" ;;
        ("i") outLine "C" "" "BC" "C" "C" "C" "ABCDE" "" ;;
        ("j") outLine "D" "" "CD" "D" "D" "D" "AD" "BC" ;;
        ("k") outLine "B" "BE" "BD" "BC" "BD" "BE" "ABEF" "" ;;
        ("l") outLine "AB" "B" "B" "B" "B" "B" "ABC" "" ;;
        ("m") outLine "" "" "ACEF" "ABDG" "ADG" "ADG" "ADG" "" ;;
        ("n") outLine "" "" "BDE" "BCF" "BF" "BF" "BF" "" ;;
        ("o") outLine "" "" "BCDE" "AF" "AF" "AF" "BCDE" "" ;;
        ("p") outLine "" "" "ABCDE" "BF" "BF" "BCDE" "B" "AB" ;;
        ("q") outLine "" "" "BCDEG" "AF" "AF" "BCDE" "F" "FG" ;;
        ("r") outLine "" "" "ABDE" "BCF" "B" "B" "AB" "" ;;
        ("s") outLine "" "" "BCDE" "A" "BCDE" "F" "ABCDE" "" ;;
        ("t") outLine "C" "C" "ABCDE" "C" "C" "C" "DE" "" ;;
        ("u") outLine "" "" "AF" "AF" "AF" "AF" "BCDEG" "" ;;
        ("v") outLine "" "" "AG" "BF" "BF" "CE" "D" "" ;;
        ("w") outLine "" "" "AG" "AG" "ADG" "ADG" "BCEF" "" ;;
        ("x") outLine "" "" "AF" "BE" "CD" "BE" "AF" "" ;;
        ("y") outLine "" "" "BF" "BF" "BF" "CDE" "E" "BCD" ;;
        ("z") outLine "" "" "ABCDEF" "E" "D" "C" "BCDEFG" "" ;;
        ("A") outLine "D" "CE" "BF" "AG" "ABCDEFG" "AG" "AG" "" ;;
        ("B") outLine "ABCDE" "AF" "AF" "ABCDE" "AF" "AF" "ABCDE" "" ;;
        ("C") outLine "CDE" "BF" "A" "A" "A" "BF" "CDE" "" ;;
        ("D") outLine "ABCD" "AE" "AF" "AF" "AF" "AE" "ABCD" "" ;;
        ("E") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "ABCDEF" "" ;;
        ("F") outLine "ABCDEF" "A" "A" "ABCDE" "A" "A" "A" "" ;;
        ("G") outLine "CDE" "BF" "A" "A" "AEFG" "BFG" "CDEG" "" ;;
        ("H") outLine "AG" "AG" "AG" "ABCDEFG" "AG" "AG" "AG" "" ;;
        ("I") outLine "ABCDE" "C" "C" "C" "C" "C" "ABCDE" "" ;;
        ("J") outLine "BCDEF" "D" "D" "D" "D" "BD" "C" "" ;;
        ("K") outLine "AF" "AE" "AD" "ABC" "AD" "AE" "AF" "" ;;
        ("L") outLine "A" "A" "A" "A" "A" "A" "ABCDEF" "" ;;
        ("M") outLine "ABFG" "ACEG" "ADG" "AG" "AG" "AG" "AG" "" ;;
        ("N") outLine "AG" "ABG" "ACG" "ADG" "AEG" "AFG" "AG" "" ;;
        ("O") outLine "CDE" "BF" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("P") outLine "ABCDE" "AF" "AF" "ABCDE" "A" "A" "A" "" ;;
        ("Q") outLine "CDE" "BF" "AG" "AG" "ACG" "BDF" "CDE" "FG" ;;
        ("R") outLine "ABCD" "AE" "AE" "ABCD" "AE" "AF" "AF" "" ;;
        ("S") outLine "CDE" "BF" "C" "D" "E" "BF" "CDE" "" ;;
        ("T") outLine "ABCDEFG" "D" "D" "D" "D" "D" "D" "" ;;
        ("U") outLine "AG" "AG" "AG" "AG" "AG" "BF" "CDE" "" ;;
        ("V") outLine "AG" "AG" "BF" "BF" "CE" "CE" "D" "" ;;
        ("W") outLine "AG" "AG" "AG" "AG" "ADG" "ACEG" "BF" "" ;;
        ("X") outLine "AG" "AG" "BF" "CDE" "BF" "AG" "AG" "" ;;
        ("Y") outLine "AG" "AG" "BF" "CE" "D" "D" "D" "" ;;
        ("Z") outLine "ABCDEFG" "F" "E" "D" "C" "B" "ABCDEFG" "" ;;
        (".") outLine "" "" "" "" "" "" "D" "" ;;
        (",") outLine "" "" "" "" "" "E" "E" "D" ;;
        (":") outLine "" "" "" "" "D" "" "D" "" ;;
        ("!") outLine "D" "D" "D" "D" "D" "" "D" "" ;;
        ("/") outLine "G" "F" "E" "D" "C" "B" "A" "" ;;
        ("\\") outLine "A" "B" "C" "D" "E" "F" "G" "" ;;
        ("|") outLine "D" "D" "D" "D" "D" "D" "D" "D" ;;
        ("+") outLine "" "D" "D" "BCDEF" "D" "D" "" "" ;;
        ("-") outLine "" "" "" "BCDEF" "" "" "" "" ;;
        ("*") outLine "" "BDF" "CDE" "D" "CDE" "BDF" "" "" ;;
        ("=") outLine "" "" "BCDEF" "" "BCDEF" "" "" "" ;;
        (*) outLine "ABCDEFGH" "AH" "AH" "AH" "AH" "AH" "AH" "ABCDEFGH" ;;
        esac
    }

    function outArg
    {
      typeset l=${#1} c r
      for ((c=0; c<l; c++))
      do
        outChar "${1:$c:1}"
      done
      echo
      for ((r=0; r<8; r++))
      do
        printf "%-*.*s\n" "${COLUMNS:-80}" "${COLUMNS:-80}" "${raw[r]}"
        raw[r]=""
      done
    }

    for i
    do
      outArg "$i"
      echo
    done
}


function addHbabel {
    local pdb=$1
    local charges=$2
    local ext="${input##*.}"
    local nam="${in%.*}"
    if [ "$ext" != "pdb" -o "$ext" != "brk" ] ; then
        echo "$pdb doesn't seem to be a PDB file"
        return
    fi
    echo "Adding H to $pdb using OpenBabel"
    # Add H at a pH of 7.365 computing Gasteiger charges
    #	NOTE: babel will add all H at the end of the
    #	PDB file, all called H, leaving an unsorted
    #	PDB without specific H atom names.
    #	CAVEAT: if there are no CONECT records (e.g.
    #	after docking) then babel might possibly add H
    #	to the wrong atoms.
    charges="gasteiger" # or "mmff94" or "eem"
    $babel -h -p 7.365 --center --partialcharge $charges \
          -ipdb $pdb -opdb ${nam}+H.pdb
}

function addHchimera {
    local pdb=$1
    local ext="${input##*.}"
    local nam="${in%.*}"
    if [ "$ext" != "pdb" -o "$ext" != "brk" ] ; then
        echo "$pdb doesn't seem to be a PDB file"
        return
    fi
    echo "Adding H to $pdb using UCSF Chimera"
    #
    # Add H using Chimera. It will often do the right thing
    #	When no CONECT records are available, Chimera might
    #	be able to recognize some hetero groups (like nucleic
    #	acids).
    #
    $chimera --nogui <<END
        open $pdb
        addh inisolation true hbond true useHisName true useGluName true useAspName true useLysName true useCysName true
        addcharge all chargeModel 99sb method gasteiger
        write format pdb 0 ${nam}+H.pdb
        stop now
END

}

function usage {
    cat <<END

    Usage: $myname -i input.pdb -h -p pH -m add_H_method -s -c -S -l ligands
    		   -T Temp -P Press -O -E -M -L
    
    	Run a full Gromacs simulation using the CHARMM force field.
        
	if -h is used, then H will be added to the system. By default
        a physiologic pH is used. H may be added using Chimera, or
        babel, in which case, a different pH may be specified with -p
        
        This command will analyze the input file looking for ligands, and
        if any are found, will generate the parameters for them using
        ACPYPE. A list of ligands to process can be given instead, and
        in this case, charges for each ligand may be specified.
        
        Once all parameters have been generated, the system will be
        solvated and ions will be added to compensate charges (-s) or,
        if -S is specified, to simulate physiologic saline serum.
        
        After the system has been set up, it will be energy minimized,
        equilibrated, first in NVT and then in NPT, and finally an MD
        run in NPT will be computed.
        
        At each step, relevant statistics will be collected.
        
        Parameters:

                -?	print this help
        	-i	input file in PDB format
                -h	add H to the system
                -m	method to use for adding H (chimera or babel)
		-p	pH to consider for adding H (only used if method
                	is babel) [7.365]
                -s	solvate 
                -c	add counterions to neutralize system charges
                	(implies -s/solvate)
                -S	solvate using physiologic saline serum 
                	(implies -s/solvate and cancels -c/counterions)
                -l	file with a list of ligands, format is
                	'LIG	charge'
                -T	target temperature in Kelvin [310]
                -P	target pressure in bar [1.0]
                -O	add an optimization (energy minimization) run
                -E	add an equilibration run (implies -O)
                -M	add a short 2.5ns MD run (implies -E -O)
                -L	add a longer 20ns MD run (implies -M -E -O)
        
        Other files:
        	\$LIG.mol2 for any ligand \$LIG, if a \$LIG.mol2 file exists, it
                	will be used to assign charges to its atoms (instead
                        of using SQM BCC1 or Gasteiger charges if that fails)

END

}

function config_em {
    # Create em.mdp file
    #	we force creation of em.mdp even if it exists with '>|'
    cat << EOF >| em.mdp
; LINES STARTING WITH ';' ARE COMMENTS
;
; ENERGY MINIMIZATION 
; This parameter file calls for a steepest descent energy minimization not 
; to exceed 2,000 steps. The minimization will be considered successful 
; if the maximum force on any atom is less than 1000 kJ/mol/nm, at which 
; point the minimization will stop. Other parameters of note include periodic 
; boundary conditions in the x-, y-, and z-directions, 0.8 nm cut-offs for 
; short-range VDW and electrostatic interactions, and particle-mesh Ewald 
; long-range electrostatics. If any of these settings do not make sense, it 
; is unwise to proceed without reading about them in Chapter 7 of the manual.

title		    = Minimization	; Title of run

; Parameters describing what to do, when to stop and what to save

; 7.3.2 Preprocessing
define                   = -DFLEXIBLE    ; defines to pass to the preprocessor

; 7.3.3 Run Control
integrator               = steep
nsteps                   = 10000         ; maximum number of steps to integrate
constraints              = h-bonds

; 7.3.5 Energy Minimization
emtol                    = 1000.0        ; [kJ/mol/nm] minimization is converged when max force is < emtol
emstep                   = 0.01          ; [nm] initial step-size
;nstcgsteep               = 10            ; do a steep every 10 steps of cg
;nstcomm                  = 1

; 7.3.8 Output Control
nstxout                 = 100           ; [steps] freq to write coordinates to trajectory
nstvout                 = 100           ; [steps] freq to write velocities to trajectory
nstfout                 = 100           ; [steps] freq to write forces to trajectory
nstlog                  = 1             ; [steps] freq to write energies to log file
nstenergy               = 1             ; [steps] freq to write energies to energy file
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
; Parameters describing how to find the neighbors of each atom and how to calculate the interactions
cutoff-scheme   = Verlet
nstlist		    = 1		        ; [steps] Frequency to update the neighbor list and long range forces
ns_type		    = grid	    ; Method to determine neighbor list (simple, grid)
pbc                 = xyz           ; Periodic Boundary Conditions
rlist		    = 1.2	    ; Cut-off for making neighbor list (short range forces)

; 7.3.13 Ewald
coulombtype	    = PME	    ; Treatment of long range electrostatic interactions
rcoulomb	    = 1.2	    ; long range electrostatic cut-off
pme_order           = 4             ; interpolation order for PME, 4 = cubic
fourierspacing      = 0.16          ; [nm] grid spacing for FFT grid when using PME
ewald_rtol          = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb


; 7.3.11 VdW
vdwtype             = cutoff
vdw-modifier        = force-switch
rvdw-switch         = 1.0
rvdw		    = 1.2		    ; long range Van der Waals cut-off
DispCorr            = no

Tcoupl                   = no
Pcoupl                   = no
gen_vel                  = no

optimize_fft             = yes

table-extension = 40
EOF
    echo ""
    echo "em.mdp created"
    echo ""
}


function config_em_vacuum {
    # Create em.mdp file
    #	we force creation of em.mdp even if it exists with '>|'
    cat << EOF >| em.mdp
; ENERGY MINIMIZATION 
;       ADAPTED FOR CHARMM FORCE FIELD
title		= Minimization in vacuo ; Title of run

; Define can be used to control processes
define          = -DFLEXIBLE

; Parameters describing what to do, when to stop and what to save
integrator	= cg ;steep	; Algorithm options. cg = conjugate gradients
				; steep = steepest descent minimization 
				; MD = Leap Frog algorith for integrating Newtonś equations of motion )
nsteps		= 10000		; Maximum number of (minimization) steps to perform

; 7.3.5 Energy Minimization
emtol		= 10.0		; Stop minimization when the energy changes by less than emtol kJ/mol/nm.
emstep          = 0.01          ; [nm] initial step-size
nstcgsteep      = 10            ; do a steep every 10 steps of cg

nstenergy	= 1		; Write energies to disk every nstenergy steps
nstxtcout	= 100		; Write coordinates to disk every nstxtcout steps
xtc_grps	= System	; Which coordinate group(s) to write to disk
energygrps	= System	; Which energy group(s) to write to disk

; Parameters describing how to find the neighbors of each atom and how to calculate the interactions
nstlist		= 5		; Frequency to update the neighbor list and long range forces
ns_type		= grid	; Method to determine neighbor list (simple, grid)
;constraints	= none		; Bond types to replace by constraints
constraints	= h-bonds	; Bond types to replace by constraints
pbc		= xyz		; Periodic Boundary Conditions (yes/no)
;rlist		= 1.4		; [nm] Cut-off for making neighbor list (short range forces)
rlist		= 1.2		; [nm] Cut-off for making neighbor list (short range forces)
;NOTE: depending on system size we have variously used 1.4, 1.2, 1.0 or even 0.8
; YMMV, but be aware that you may need to change this here and below

coulombtype	= PME		; Treatment of long range electrostatic interactions
;coulombtype	= cut-off	; Treatment of long range electrostatic interactions
;rcoulomb	= 1.4		; [nm] long range electrostatic cut-off
rcoulomb	= 1.2		; [nm] long range electrostatic cut-off
cutoff-scheme   = Verlet

vdwtype		= cutoff
vdw-modifier	= force-switch
;rvdw		= 1.4		; [nm] long range Van der Waals cut-off
rvdw		= 1.2		; [nm] long range Van der Waals cut-off
rvdw-switch	= 1.0		; [nm] short range Van der Waals cut-off

;DispCorr        = Ener          ; apply long range dispersion corrections for energy
DispCorr        = no          ; apply long range dispersion corrections for energy


; miscellaneous trial-and-error for large systems
; Options for the decoupling
sc-alpha                 = 0.5
sc-coul                  = no
sc-power                 = 1
sc-sigma                 = 0.3
couple-moltype           = MOL
couple-lambda0           = vdw-q
couple-lambda1           = none
;couple-intramol         = no
couple-intramol          = yes
;nstdhdl                 = 10

optimize_fft             = yes

table-extension = 40
EOF
    echo ""
    echo "em.mdp created"
    echo ""
}


function config_nvt {
    # Create NVT equilibration run file
        
    cat << EOF >| nvt.mdp
title   = NVT equilibration

; NVT EQUILIBRATION
; This file calls for an MD run of 100,000 steps with a 2 fs timestep (a total 
; of 200 ps). The 'define = -DPOSRES' line initiates the backbone restraints 
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

; 7.3.2 Preprocessing
define                  = -DPOSRES      ; position restrain the protein

; 7.3.3 Run Control
integrator              = md                    ; md integrator
tinit                   = 0                     ; [ps] starting time for run
dt                      = 0.001                 ; [ps] time step for integration
;dt                      = 0.002                 ; [ps] time step for integration
nsteps                  = 200000                ; maximum number of steps to integrate, 0.002 * 100,000 = 200 ps
;nsteps                  = 100000                ; maximum number of steps to integrate, 0.002 * 100,000 = 200 ps
comm_mode               = Linear                ; remove center of mass translation
nstcomm                 = 1                     ; [steps] frequency of mass motion removal
comm_grps               = $grp   		; group(s) for center of mass motion removal

; 7.3.8 Output Control
;nstxout                 = 25000         ; [steps] freq to write coordinates to trajectory
;nstvout                 = 25000         ; [steps] freq to write velocities to trajectory
;nstfout                 = 25000         ; [steps] freq to write forces to trajectory
; increase saving frequency for better monitoring
nstxout                 = 2500          ; [steps] freq to write coordinates to trajectory
nstvout                 = 2500          ; [steps] freq to write velocities to trajectory
nstfout                 = 2500          ; [steps] freq to write forces to trajectory
nstlog                  = 100           ; [steps] freq to write energies to log file
nstenergy               = 100           ; [steps] freq to write energies to energy file
nstxout-compressed      = 100           ; [steps] freq to write coordinates to xtc trajectory
compressed-x-precision  = 1000          ; [real] precision to write xtc trajectory
compressed-x-grps       = System        ; group(s) to write to xtc trajectory
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
nstlist                 = 10            ; [steps] freq to update neighbor list
ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
;rlist                   = 0.8           ; [nm] cut-off distance for the short-range neighbor list
rlist                   = 1.2           ; [nm] cut-off distance for the short-range neighbor list

; 7.3.10 Electrostatics
coulombtype             = PME           ; Particle-Mesh Ewald electrostatics
;rcoulomb                = 0.8           ; [nm] distance for Coulomb cut-off
rcoulomb                = 1.2           ; [nm] distance for Coulomb cut-off

; 7.3.11 VdW
vdwtype                 = cut-off       ; twin-range cut-off with rlist where rvdw >= rlist
;rvdw                    = 0.8           ; [nm] distance for LJ cut-off
rvdw                    = 1.2           ; [nm] distance for LJ cut-off
rvdw-switch             = 1.0
;DispCorr                = EnerPres      ; apply long range dispersion corrections
DispCorr                = no            ; apply long range dispersion corrections

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
;constraints             = all-bonds     ; convert all bonds to constraints
constraints             = h-bonds       ; convert all bonds to constraints
constraint_algorithm    = LINCS         ; LINear Constraint Solver
continuation            = no            ; no = apply constraints to the start configuration
lincs_order             = 4             ; highest order in the expansion of the contraint coupling matrix
lincs_iter              = 1             ; number of iterations to correct for rotational lengthening
lincs_warnangle         = 30            ; [degrees] maximum angle that a bond can rotate before LINCS will complainEOF

optimize_fft             = yes

table-extension = 40
EOF

    echo ""
    echo "nvt.mdp created"
    echo ""
}


function config_npt {
    # Create equilibration run NPT file
    cat <<EOF >| npt.mdp
title			= NPT equilibration

; NPT EQUILIBRATION
; Following equilibration to a target temperature, you must next relax your 
; system into a constant pressure ensemble. 
; This parameter file calls for a run of 250,000 steps with a 2 fs timestep 
; (a total of 500 ps). Position restraints are still being applied to the 
; backbone. The Berendsen thermostat has been replaced with a Nose-Hoover 
; thermostat, which will produce a more correct ensemble of kinetic energies. 
; The Nose-Hoover thermostat, however, must be implemented only after the 
; system is already near its target temperature (which was achieved by the 
; Berendsen thermostat), or the kinetic energy of the system will fluctuate 
; wildly. Because this run will be a continuation of the previous run, 
; 'gen_vel' has been set to 'no'. Finally, the Parrinello-Rahman method is 
; used to couple pressure isotropically (the same in all directions) to a 
; value of 1.0 bar.

; 7.3.2 Preprocessing
define                  = -DPOSRES      ; position restrain the protein

; 7.3.3 Run Control
continuation		= yes			; Restarting after NVT
integrator              = md                    ; md integrator
tinit                   = 0                     ; [ps] starting time for run
dt                      = 0.002                 ; [ps] time step for integration
nsteps                  = 100000                ; maximum number of steps to integrate, 0.002 * 100,000 = 200 ps
comm_mode               = Linear                ; remove center of mass translation
nstcomm                 = 1                     ; [steps] frequency of mass motion removal
comm_grps               = $grp   ; group(s) for center of mass motion removal
;continuation            = no            ; no = apply constraints to the start configuration

; 7.3.8 Output Control
;nstxout                 = 25000         ; [steps] freq to write coordinates to trajectory
;nstvout                 = 25000         ; [steps] freq to write velocities to trajectory
;nstfout                 = 25000         ; [steps] freq to write forces to trajectory
; increase saving frequency for better monitoring
nstxout                 = 2500          ; [steps] freq to write coordinates to trajectory
nstvout                 = 2500          ; [steps] freq to write velocities to trajectory
nstfout                 = 2500          ; [steps] freq to write forces to trajectory
nstlog                  = 100           ; [steps] freq to write energies to log file
nstenergy               = 100           ; [steps] freq to write energies to energy file
nstxout-compressed      = 100           ; [steps] freq to write coordinates to xtc trajectory
compressed-x-precision  = 1000          ; [real] precision to write xtc trajectory
compressed-x-grps       = System        ; group(s) to write to xtc trajectory
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
nstlist                 = 10            ; [steps] freq to update neighbor list
ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
;rlist                   = 0.8           ; [nm] cut-off distance for the short-range neighbor list
rlist                   = 1.2           ; [nm] cut-off distance for the short-range neighbor list

; 7.3.10 Electrostatics
coulombtype             = PME           ; Particle-Mesh Ewald electrostatics
;rcoulomb                = 0.8           ; [nm] distance for Coulomb cut-off
rcoulomb                = 1.2           ; [nm] distance for Coulomb cut-off
;DispCorr                = EnerPres      ; apply long range dispersion corrections
DispCorr                = no            ; apply long range dispersion corrections

; 7.3.11 VdW
vdwtype                 = cut-off       ; twin-range cut-off with rlist where rvdw >= rlist
;rvdw                    = 0.8           ; [nm] distance for LJ cut-off
rvdw                    = 1.2           ; [nm] distance for LJ cut-off
rvdw-switch             = 1.0

; 7.3.13 Ewald
fourierspacing          = 0.12          ; [nm] grid spacing for FFT grid when using PME
pme_order               = 4             ; interpolation order for PME, 4 = cubic
ewald_rtol              = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb

; 7.3.14 Temperature Coupling
;tcoupl                  = berendsen			; temperature coupling with Berendsen-thermostat
tcoupl			= V-rescale			; modified Berendsen thermostat
tc_grps                 = $grp        ; groups to couple seperately to temperature bath
tau_t                   = $tau_t                ; [ps] time constant for coupling
ref_t                   = $ref_t                ; [K] reference temperature for coupling

; Pressure Coupling
pcoupl			= Parrinello-Rahman	; Pressure coupling on in NPT
pcoupltype		= isotropic		; uniform scaling of box vectors
tau_p			= 2.0			; time constant, in ps
ref_p			= $pressure			; reference pressure, in bar
compressibility 	= 4.5e-5		; isothermal compressibility of water, bar^-1
refcoord_scaling 	= com

; 7.3.17 Velocity Generation
;	OFF (continuation run)
gen_vel                 = no           ; generate velocities according to Maxwell distribution of temperature
;gen_temp                = $temperature           ; [K] temperature for Maxwell distribution
;gen_seed                = -1            ; [integer] used to initialize random generator for random velocities

; 7.3.18 Bonds
;constraints             = all-bonds     ; convert all bonds to constraints
constraints             = h-bonds       ; convert all bonds to constraints
constraint_algorithm    = LINCS         ; LINear Constraint Solver
lincs_order             = 4             ; highest order in the expansion of the contraint coupling matrix
lincs_iter              = 1             ; number of iterations to correct for rotational lengthening
lincs_warnangle         = 30            ; [degrees] maximum angle that a bond can rotate before LINCS will complain

optimize_fft             = yes

table-extension = 40
EOF

    echo ""
    echo "npt.mdp created"
    echo ""

}



function config_md {

    if [ "$longrun" == "yes" ] ; then 
        nsteps=10000000 
	echo "Doing long $nsteps MD run"
    else 
        # if we are here then $shortrun must be yes
        nsteps=2500000
	echo "Doing short $nsteps MD run"
    fi


    # Create production run md.mdp file
    cat << EOF >| md.mdp
; MD PRODUCTION RUN

; 7.3.3 Run Control
integrator              = md                    ; md integrator
tinit                   = 0                     ; [ps] starting time for run
dt                      = 0.002                 ; [ps] time step for integration
nsteps                  = $nsteps               ; maximum number of steps to integrate, 0.002 * 2,500,000 = 5,000 ps
;nsteps                  =  2 500 000               ; maximum number of steps to integrate, 0.002 * 2,500,000 = 5,000 ps
;nsteps                  = 10 000 000              ; maximum number of steps to integrate, 0.002 * 10,000,000 = 20,000 ps
comm_mode               = Linear                ; remove center of mass translation
nstcomm                 = 100                   ; [steps] frequency of center of mass motion removal
comm_grps               = $grp   ; group(s) for center of mass motion removal
continuation		= yes			; Restarting after NPT 

; 7.3.8 Output Control
nstxout                 = 1000          ; [steps] freq to write coordinates to trajectory
nstvout                 = 1000          ; [steps] freq to write velocities to trajectory
nstfout                 = 1000          ; [steps] freq to write forces to trajectory
nstlog                  = 1000          ; [steps] freq to write energies to log file
nstenergy               = 1000          ; [steps] freq to write energies to energy file
nstxout-compressed      = 1000          ; [steps] freq to write coordinates to xtc trajectory
compressed-x-precision  = 1000          ; [real] precision to write xtc trajectory
compressed-x-grps       = System        ; group(s) to write to xtc trajectory
energygrps              = System        ; group(s) to write to energy file

; 7.3.9 Neighbor Searching
cutoff-scheme           = Verlet
verlet-buffer-tolerance = 0.005
nstlist                 = 12            ; [steps] freq to update neighbor list
ns_type                 = grid          ; method of updating neighbor list
pbc                     = xyz           ; periodic boundary conditions in all directions
;rlist                   = 1.0           ; [nm] cut-off distance for the short-range neighbor list
rlist                   = 1.2           ; [nm] cut-off distance for the short-range neighbor list

; 7.3.10 Electrostatics
coulombtype             = PME           ; Particle-Mesh Ewald electrostatics
;rcoulomb                = 0.8           ; [nm] distance for Coulomb cut-off
;rlistlong               = 0.8           ; [nm] Cut-off distance for the long-range neighbor list. This parameter is only relevant for a twin-range cut-off setup with switched potentials
rcoulomb                = 1.2           ; [nm] distance for Coulomb cut-off
rlistlong               = 1.2           ; [nm] Cut-off distance for the long-range neighbor list. This parameter is only relevant for a twin-range cut-off setup with switched potentials

; 7.3.11 VdW
vdwtype                 = Cut-off
vdw_modifier            = Force-switch  ; twin-range shift with rlist where rvdw >= rlist
;rvdw                    = 0.8           ; [nm] distance for LJ cut-off
;rvdw-switch             = 0.7
;DispCorr                = EnerPres      ; apply long range dispersion corrections for energy
rvdw                    = 1.2           ; [nm] distance for LJ cut-off
rvdw-switch             = 1.0
; Dispersion correction is not used for proteins with the C36 additive FF
DispCorr                = no            ; apply long range dispersion corrections for energy

; 7.3.13 Ewald
;fourierspacing          = 0.12          ; [nm] grid spacing for FFT grid when using PME
fourierspacing          = 0.16          ; [nm] grid spacing for FFT grid when using PME
pme_order               = 4             ; interpolation order for PME, 4 = cubic
ewald_rtol              = 1e-5          ; relative strength of Ewald-shifted potential at rcoulomb

; 7.3.14 Temperature Coupling
;tcoupl                  = nose-hoover  ; temperature coupling with Nose-Hoover ensemble
Tcoupl                   = V-rescale
tc_grps                 = $grp        ; groups to couple seperately to temperature bath
tau_t                   = $tau_t                ; [ps] time constant for coupling
ref_t                   = $ref_t                ; [K] reference temperature for coupling

; 7.3.15 Pressure Coupling
pcoupl                  = Parrinello-Rahman     ; pressure coupling where box vectors are variable
pcoupltype              = isotropic             ; pressure coupling in x-y-z directions
tau_p                   = 2.0                   ; [ps] time constant for coupling
;tau_p                    = 0.5
compressibility         = 4.5e-5                ; [bar^-1] compressibility
ref_p                   = $pressure                   ; [bar] reference pressure for coupling

; 7.3.17 Velocity Generation
gen_vel                 = no            ; velocity generation turned off
					; we start from equilibration velocities
; 7.3.18 Bonds
;constraints             = all-bonds     ; convert all bonds to constraints
constraints             = h-bonds       ; convert all bonds to constraints
constraint_algorithm    = LINCS         ; LINear Constraint Solver
lincs_order             = 4             ; highest order in the expansion of the contraint coupling matrix
;lincs_iter              = 1             ; number of iterations to correct for rotational lengthening
lincs-iter              = 2             ; number of iterations to correct for rotational lengthening
lincs_warnangle         = 30            ; [degrees] maximum angle that a bond can rotate before LINCS will complain

optimize_fft             = yes

table-extension = 40
EOF
    echo ""
    echo "md.mdp created"
    echo ""

}


function gro2pdb() {
    i=$1
    n=${i%.gro}
    if [ ! -e $n.pdb ] ; then
        if [ -e $n.tpr ] ; then
	    	tpr=$n.tpr
		else
	    	# if there is no $n.tpr then we'll use the project's one
	    	tpr=$md.tpr
		fi
	# editconf does not preserve the chain info (does not use 
        # any .tpr file)
        #gmx editconf -f $i -o $n.pdb -pbc mol
	# -conect adds conect records which is useful for coarse grained
	# simulations and models containing non-protein molecules, but may
	# become a problem for simulations with > 100K atoms
	natoms=`head -2 $i | tail -1`
	if [ "$natoms" -gt 99999 ] ; then conect='' ; else conect='-conect' ; fi
	echo "System" | gmx trjconv -f $i -s $tpr -o $n.pdb -pbc mol $conect
	#echo "TPR used is $tpr"
        echo "$bold${green}Converted $i $plain$black"
    fi
}



if [ $# == 0 ] ; then
	usage ; exit 1
fi

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o ?i:hm:p:scSl:T:P:OEMLv \
     --long help,input:,addH,method:,pH:,solvate,counterions,saline,ligands:,temperature:,pressure:,optimize,equilibrate,shortmd,longmd,verbose \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
        	-\?|--help)
                    usage ; exit 0 ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
                    if [ ! -s $2 ] ; then
			echo ""
                    	echo "ERROR: $2 doesn't exist or is empty"
                    	usage ; exit 1
                    fi
		    input=$2 ; shift 2 ;;
		-h|--addH) 
		    addH='yes' 
                    addHmethod="gromacs"
		    shift ;;
                -m|--method)
                    if [ "$2" == 'chimera' -o "$2" == "babel" -o "$2" == "gromacs" ] ; then
                        addHmethod=$2 ; 
                    else
                        usage; exit 1
                    fi
                    shift 2 ;;
                -p|--pH)
                    # check $2 is a positive real number
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pH=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
                -c|--counterions)
                    counterions='yes'
                    solvate='yes'
                    shift ;;
		-s|--solvate)
                    solvate='yes'
                    shift ;;
                -S|--saline)
                    solvate='yes'
                    useSaline='yes'
                    counterions='no'
                    shift ;;
                -l|--ligands)
                    if [ ! -s $2 ] ; then
                        echo ""
                    	echo "ERROR: $2 doesn't exist or is empty"
                    	usage ; exit 1
                    fi
                    ligands=$2
                    shift 2 ;;             
	        -T|--temperature)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        temperature=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
		-P|--pressure)
                    if [[ $2 =~ ^[0-9]+(.[0-9]?)?$ ]] ; then
                        pressure=$2
                    else
                        echo ""
                        echo "ERROR: $2 is not a positive real number"
                        usage ; exit 1
                    fi
                    shift 2 ;;
                -O|--optimize)
                    optimize='yes'
                    shift ;;
                -E|--equilibrate)
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;
                -M|--shortmd)
                    shortrun='yes'
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;
                -L|--longmd)
                    longrun='yes'
                    shortrun='yes'
                    equilibrate='yes'
                    optimize='yes'
                    shift ;;             
                -v|--verbose)
                    verbose='yes'
					shift ;;
                --) shift ; break ;;
		*) echo "ERROR: Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

echo ""
banner " CHARMM MD"
echo ""
echo "input: $input"
echo "add-H: $addH"
echo "method: $addHmethod"
echo "pH: $pH"
echo "T: $temperature"
echo "P: $pressure"
echo "solvate: $solvate"
echo "saline: $useSaline"
echo "ligands: $ligands"
echo "optimize: $optimize"
echo "equilibrate: $equilibrate"
echo "short MD run (1ns): $shortrun"
echo "long MD run (10ns): $longrun"
echo "number of threads: $nproc"
echo "CPU allocation offset: $usedprocs"

# Setup simulation directory

# get file directory
#	if $input is empty this will return "."
d=`dirname "$input"`

in="${input##*/}"
ext="${input##*.}"
nam="${in%.*}"

#echo "dir: $d"
#echo "in : $in"
#echo "ext: $ext"
#echo "nam: $nam"

if [ ! "$ext" == "pdb" -a ! "$ext" == "brk" ] ; then
    echo "ERROR: Input file must be a PDB file"
    usage ; exit 1
fi

## DEFINE OUTPUT DIRECTORY NAME
##
# name=`basename $1 .pdb`_Hc_pH7.4_hoh_ion
# echo $name
name="charmm_${nam}"

if [ $addH == 'yes' ] ; then
    if [ $addHmethod == 'chimera' ] ; then
        name="${name}_Hc"
    elif [ $addHmethod == 'babel' ] ; then
        name="${name}_pH${pH}"
        name="${name}_Hb"
    else
        name="${name}_H"
    fi
fi
if [ $useSaline == 'yes' ] ; then
    name="${name}_150mM"
elif [ $solvate == 'yes' ] ; then
    name="${name}_hoh"
fi
if [ $counterions == 'yes' ] ; then
    name="${name}_ion"
fi

name="${name}_${temperature}K"

echo "output: $name"
echo ""

if [ -e "$name" -a ! -d "$name" ] ; then 
    echo "ERROR: $name exists and is not a directory"
    exit 
fi

mkdir -p "$name"
mkdir -p "$name"/lib
if [ "$verbose" = "yes" ] ; then
    echo -n "Copying '$0' command to '$name' for future reference... "
    cp -rHLu "$ME" "$FUNCS_BASE" "$name"
    echo "done"
fi

if [ "$ONELOG" = 'yes' ] ; then
    # save all output together in a single log file
    if [ "$verbose" = "yes" ] ; then
    	log="./$name/log.$myname.outerr"
    	appendlog='-a'
    	#appendlog=''
        # note: >& send out and err together to... >(...) receive from in into command
    	exec >& >(stdbuf -o 0 -e 0 tee $appendlog "$log")
    fi
else
    # split all output into two log files (one for stdout and one for stderr)
    stdout="./$name/log.$myname.out"
    stderr="./$name/log.$myname.err"
    if [ "$verbose" = 'yes' ] ; then
    	exec | tee "$stdout" 2| tee "$stderr"
    else
    	exec > $stdout 2> "$stderr"
    fi
fi   
if [ "$TOBETESTED" = 'yes' ] ; then
    exec | >( stdbuf -o 0 -e 0 | tee $appendlog "$stdout" ) \
        2| >( stdbuf -o 0 -e 0 | tee $appendlog "$stderr" )
fi


echo ""
banner " CHARMM MD"
echo ""
echo "input: $input"
echo "add-H: $addH"
echo "method: $addHmethod"
echo "pH: $pH"
echo "T: $temperature"
echo "P: $pressure"
echo "solvate: $solvate"
echo "saline: $useSaline"
echo "ligands: $ligands"
echo "optimize: $optimize"
echo "equilibrate: $equilibrate"
echo "short MD run (1ns): $shortrun"
echo "long MD run (10ns): $longrun"
echo "number of threads: $nproc"
echo "CPU allocation offset: $usedprocs"

echo '
#-------------------------------------------------------------------------
#		PREPARE SYSTEM
#-------------------------------------------------------------------------
'
banner ' SET UP'

# Copy input files to work directory
cp $input $name/Orig.pdb
if [ -f "$ligands" ] ; then
    cp $ligands $name/
    # check if there are .mol2 or .pdb files to copy
    cut -f1 $ligands | while read lig ; do
	if [ -s $lig.mol2 ] ; then
            cp $lig.mol2 $name
        fi
	if [ -s $lig.pdb ] ; then
            cp $lig.pdb $name
        fi
    done
    # NOTE: later on we will simply check for the existence
    # of the .mol2 files inside the directory.
    # This is so because that way, if the calculation fails,
    # then we can add them later inside the work directory 
    # and restart the calculation to use those new ones.
fi


# FROM NOW ON, WORK INSIDE THE OUTPUT DIRECTORY
cd $name

if [ ! -s OrigComplex.pdb ] ; then
    if [ $addH == 'yes' ] ; then
        # remove all H (we'll add them to suit our desired pH)
        #
        if [ "$verbose" == 'yes' ] ; then echo "Removing H" ; fi
        grep -v " H " Orig.pdb | grep -v "^CONECT" | grep -v "^WARNING" \
	    > OrigComplex.pdb
    else
        cp Orig.pdb OrigComplex.pdb
        cp Orig.pdb OrigComplex+H.pdb
    fi
fi
echo "Original complex created"

if [ ! -s OrigComplex+H.pdb ] ; then
    if [ $addHmethod == 'babel' ] ; then
        echo "Adding charges with OpenBabel"
        addHbabel OrigComplex.pdb $charges
	# will produce OrigComplex+H.pdb
    elif [ $addHmethod == 'chimera' ] ; then
        echo "Adding charges with UCSF Chimera"
        addHchimera OrigComplex.pdb
	# will produce OrigComplex+H.pdb
    else
        echo "Using original geometry"
        # no H to add, or Gromacs method, use input structure 'as is'
        egrep  '(^ATOM)|(^HETATM)|(^CONECT)' OrigComplex.pdb > OrigComplex+H.pdb
    fi
fi
echo "OrigComplex protonated"

# ------------------------------------------------------------------------
# Separate ligands and Protein

if [ ! -s Protein.pdb ] ; then
    # we can't check for the ligands as we still do not know them, so
    # we only check for existence of the protein.

    # get a starting model, we'll remove the ligands next
    cp OrigComplex+H.pdb Protein.pdb

    # get list of ligands
    if [ ! -e $ligands ] ; then
        grep '^HETATM' OrigComplex+H.pdb | cut -c18-21 | uniq | grep -v ' MG '
    else
        # format of LIGANDS is 'LIG	charge'
        if [ "$ligands" != "LIGANDS" ] ; then
            cp $ligands LIGANDS
        fi
        cut -f1 LIGANDS 
    fi \
    | while read lig ; do	# in a subshell
        charge=0
        if [ -e LIGANDS ] ; then charge=`grep $lig LIGANDS | cut -f2` ; fi
        # compute multiplicity
        # HEURISTIC: assume all charges are due to e- that yield unpaired spin
        mult=$(( ${charge#-} + 1 ))
        echo ""
        #echo $lig $charge $mult
        banner "$lig $charge $mult"
        echo ""

        # extract ligand with the H already added
        # and remove it from the protein
        if [ $addHmethod == 'babel' ] ; then
            grep -h "^HETATM.* $lig" Protein.pdb > het$lig.pdb
    	    # remove ligand from protein
    	    grep -v "^HETATM.* $lig" Protein.pdb > Prot.pdb
    	    mv Prot.pdb Protein.pdb
        else 
      	    # for all the other cases, use Chimera    
    	    # Using Chimera helps keep/remove the CONECT records
	    $chimera --nogui <<END
                open Protein.pdb
                select #0:$lig
                write selected format pdb 0 het$lig.pdb
                delete #0:$lig
                write format pdb 0 Protein.pdb
                stop now
END
	    egrep '(^ATOM)|(^HETATM)|(^CONECT)' het$lig.pdb > het.pdb
            mv het.pdb het$lig.pdb
        fi


        #
        #	We'll try to generate the ligand parameters from scratch.
        #	Most likely this will fail to produce accurate AM1/BCC
        #	charges if the molecules are ionized. In that case, we
        #	resort to Gasteiger charges.
        #
        #	There is a scape though: you can compute charges elsewhere
        #	(e.g. in Chimera, Gabedit, using Mopac, or any other such)
        #       first, using AM1/BCC or whatever method, and save the files
        #	on the working directory as MOL2 files. Then these charges
        #	(hopefully more accurate) will be used instead. 
        #	You may even use babel --partialcharge {mmff94|eem|gasteiger}
        #	but babel has shown various problems adding H with -h -p 7.4 
        #	(e.g. with ATP).
        #
        if [ -e $lig.acpype ] ; then continue ; fi
        # add AM1-BCC charges with GAFF atom types and save as .mol2
        if [ ! -e $lig.mol2 -o ! -e $lig.pdb ] ; then
            # try to assign charges using Chimera and antechamber
            echo "Attempting to asssign charges using Chimera"
            $chimera --nogui <<END
                open het$lig.pdb
                #addh inisolation true hbond true
                addcharge all chargeModel 99sb method am1
                write format mol2 0 $lig.mol2
                write format pdb  0 $lig.pdb
                stop now
END
	    # NOTE: review the output to check that all went as expected.
            #	If there is something wrong, CORRECT THE ORIGINAL PDB FILE.
        fi
        # if a MOL2 file is available, assume it has charges and use them
        if [ -e $lig.mol2 ] ; then
          # use user charges
          #$acpype -i $lig.mol2 -n $charge -m $mult -b $lig -r -l -a charmm -c user
          $acpype -i $lig.mol2 -n $charge -m $mult -b $lig -z -l -a charmm -c user
          # if  MOL2 file failed, then resort to Gasteiger charges
          if [ $? -eq 1 ] ; then
              echo "COULD NOT USE MOL2 FILE CHARGES. USING GASTEIGER CHARGES"
              #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a charmm -c gas
              $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a charmm -c gas
          fi
        else
          # compute charges using SQM
          #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a charmm
          $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a charmm
          # if SQM failed, then resort to Gasteiger charges
          if [ $? -eq 1 ] ; then
              echo "COULD NOT USE SQM. USING GASTEIGER CHARGES"
              #$acpype -i $lig.pdb -n $charge -m $mult -b $lig -r -l -a charmm -c gas
              $acpype -i $lig.pdb -n $charge -m $mult -b $lig -z -l -a charmm -c gas
          fi
        fi
    done
fi
echo "Separated Protein + ligands"


if [ ! -e Complex.pdb -o ! -e Complex.top ] ; then
    # we need to merge back now the protein and the updated ligands, but this
    # requires that we first generate the topology for the protein:

    if [ "$addH" = 'no' -o "$addHmethod" = 'chimera' -o "$addHmethod" = 'babel' ] ; then
        $pdb2gmx -ff $forcefield -f Protein.pdb -o Protein2.pdb -p Protein.top \
	    -water $watermodel -i
        $pdb2gmx -ff $forcefield -f Protein.pdb -o Protein2.gro -p Protein.top \
	    -water $watermodel -i
    else
        # add H ourselves
        $pdb2gmx -ff $forcefield -f Protein.pdb -o Protein2.pdb -p Protein.top \
	    -water $watermodel -ignh -i
        $pdb2gmx -ff $forcefield -f Protein.pdb -o Protein2.gro -p Protein.top \
	    -water $watermodel -ignh -i
    fi

    if [ $? -ne 0 ] ; then exit ; fi

    # 
    # Merge Protein2.pdb + updated Ligand_NEW.pdb -> Complex.pdb
    #    NOTE: Ligand_NEW contains ALL the hydrogens, so it is not
    #    ionized as we would expect!
    #    Furthermore, they'll likely belong all to the same chain
    #    and Gromacs will try to connect them.
    grep -h ATOM Protein2.pdb *.acpype/*_NEW.pdb >| Complex.pdb
    #
    #grep -h ATOM Protein2.pdb > Complex.pdb
    #grep -h HETATM Lig*.pdb | sed -e 's/HETATM/ATOM  /g' >> Complex.pdb

    # Edit Protein.top -> Complex.top
    cp Protein.top Complex.top
    
	
    # check there are indeed ligands to add
    if [ `ls -1f *.acpype 2>&1 /dev/null | wc -l` -ne 0 && -s LIGANDS] ; then 
        echo "Adding ligands to complex"
        for i in *.acpype ; do
            lig=`basename $i .acpype`
            if [ ! -e $lig.itp ] ; then
                # remove atomtypes (we only want them included once
                # at the beginning, hence we'll process them separately
                cat $i/*_GMX.itp | sed -n '1,/atomtypes/p;/moleculetype/,$p' | \
                    grep -v " atomtypes " > $lig.itp
                sed -n -e '/atomtypes/,/^$/p' $i/*_GMX.itp >> atomtypes
            fi

            cat Complex.top | sed "/forcefield\.itp\"/a\
        #include \"$lig.itp\"\
        " >| Complex2.top

            echo "$lig      1" >> Complex2.top
            mv Complex2.top Complex.top
        done
         # now insert any new atom types before the ligands
        if [ ! -e atomtypes.itp ] ; then
            echo "[ atomtypes ]" > atomtypes.itp
            #echo "; name    at.num      mass     charge   ptype  sigma         epsilon" >> atomtypes.itp
            # first ensure there are no duplicates
            export IFS=''
            newatoms='0'
            #sort atomtypes | uniq | grep "^ " | \
            while read line ; do 
                atom=`echo $line | cut -c 1-3 | tr -d ' '`
                echo "${atom}=${line}"
                grep -q "^$atom " $GMX_TOP/charmm27.ff/ffnonbonded.itp
                if [ $? -ne 0 ] ; then 
                    echo "NOT FOUND: $line" 
                    echo "$line" >> atomtypes.itp
                    newatoms=$(($newatoms+1))
                fi
            done < <(sort atomtypes | uniq | grep "^ ")
            echo "" >> atomtypes.itp
            if [ $newatoms -gt 0 ] ; then
                banner " WARNING!"
                echo "New atom types defined"
                echo "Edit the file 'atomtypes.itp' to revise new atom num, mass and charge"
                echo "See $GMX_TOP/charmm27.ff/ffnonbonded.itp as reference"
                exit
            fi
        fi
        #rm atomtypes
        cat Complex.top | sed "/forcefield\.itp\"/a\
        #include \"atomtypes.itp\"\
        " >| Complex2.top
        mv Complex2.top Complex.top
    fi
fi
echo "Complex reconstituted"
echo ""

if [ ! -e Complex_b4ion.pdb ] ; then
    # Setup the PBC box
    $FUNCS_BASE/get_pdb_dimensions.sh Complex.pdb size > Complex.dims
    # find maximal dimensions
    xmax=`cut -f1 Complex.dims | sort -g | tail -1`
    ymax=`cut -f2 Complex.dims | sort -g | tail -1`
    zmax=`cut -f3 Complex.dims | sort -g | tail -1`
    echo "Maximum sizes: $xmax $ymax $zmax"
    # compute box size (+12 Å on each side and convert to nm)
    # this is wasteful, but...
    xbox=`echo "scale=3; ($xmax + 24)/10" | bc -l`
    ybox=`echo "scale=3; ($ymax + 24)/10" | bc -l`
    zbox=`echo "scale=3; ($zmax + 24)/10" | bc -l`
    #echo "We will use a common box of size $xbox $ybox $zbox nm"

    # the system may rotate during the simulation and clash with
    # itself, so we want the box to be large enough for the larger
    # dimension
    if [ `bc <<< "$xbox > $ybox"` == 1 ] ; then maxsz=$xbox ; else maxsz=$ybox ; fi
    if [ `bc <<< "$maxsz < $zbox"` == 1 ] ; then maxsz=$zbox ; fi
    maxsz=`bc <<< "$maxsz * 2"`

    #	should prefer -bt dodecahedron
    #	-d 1.6 : allow for 1.6 nm between protein and box edges
    if [ "$safe" == "yes" ] ; then
	maxsz=`bc <<< "$maxsz + 10"`	# add 5nm on each side
	center=`bc <<< "$maxsz / 2"`	# calculate box center (unnecessary?)
        echo "We will use a cubic box with side $maxsz"
	# this may be very wasteful of resources by defining a
	    # huge box for elongated systems
	$editconf -bt triclinic -box $maxsz $maxsz $maxsz \
		   -center $center $center $center \
		   -f Complex.pdb -o Complex_PBC.pdb
    else
	# the value to -d must exceed all .ndp cutoffs to avoid self-
	# interactions
	# This works for more or less globular proteins. For elongated
	# systems, the system may rotate and reorient its longest axis
	# across the shortest box dimension in a way that makes it get
	# in contact with itself,
    	$editconf -bt triclinic -f Complex.pdb -o Complex_PBC.pdb -d 1.6
    fi
    if [ $? -ne 0 ] ; then exit ; fi

    if [ $solvate == 'yes' ] ; then
        # Fill the box with water from SPC216.
        $genbox -cp Complex_PBC.pdb -cs spc216.gro -o Complex_b4ion.pdb -p Complex.top
    else
	cp Complex_PBC.pdb Complex_b4ion.pdb
    fi

    if [ $? -ne 0 ] ; then exit ; fi

fi
echo "Triclinic box created"



echo '
#-------------------------------------------------------------------------
#				ADD IONS 
#-------------------------------------------------------------------------
'
if [ ! -s em.mdp ] ; then
    if [ "$solvate" = "yes" ] ; then
        config_em
    else
        config_em_vacuum
    fi
fi

if [ ! -s Complex_b4em.pdb ] ; then
    # Add ions
    # we expect a warning because we still haven't equilibrated the system
    # charge and we may have non-zero total charge.
    $grompp -maxwarn 1 -f em.mdp -c Complex_b4ion.pdb \
			-p Complex.top -o Complex_b4ion.tpr
    if [ $? -ne 0 ] ; then exit ; fi

    cp Complex.top Complex_ion.top

    if [ $useSaline == 'yes' ] ; then
        # Use a concentration of 150 mM and a neutral system
        # 	we have MG, ATP and UD1, so SOL should be 14+3
	#	place ions using based on potenrial instead of randomly
        echo "SOL" | $genion -s Complex_b4ion.tpr -o Complex_b4em.pdb \
        	-neutral -conc 0.15 -p Complex_ion.top #-norandom
        if [ $? -ne 0 ] ; then exit ; fi
    elif [ $counterions == 'yes' ] ; then
        # Only equilibrate charges
        #	place ions randomly
        echo "SOL" | $genion -s Complex_b4ion.tpr -o Complex_b4em.pdb -neutral -p Complex_ion.top
        if [ $? -ne 0 ] ; then exit ; fi
    else
	# do not modify
        cp Complex_b4ion.pdb Complex_b4em.pdb
    fi


    mv Complex_ion.top Complex.top
fi

# check if an optimization has been requested
#	note that if equilibration or MD are requested,
#	then optimization is forced as well, i.e.
#	if there is no optimization there cannot be
#	equilibration or MD either, so we are done
#cho "Opt=$optimize"
if [ "$optimize" == "no" ] ; then echo "No optimization: Done" ; exit ; fi


echo '
#-------------------------------------------------------------------------
#				MINIMIZE ENERGY
#-------------------------------------------------------------------------
'
banner "  E  M  "



if [ -s em.pdb ] ; then
	echo "em.pdb exists: Skipping energy minimization"
else
    # Run minimisaton (no restrictions)
    $grompp -f em.mdp -c Complex_b4em.pdb -p Complex.top -o em.tpr
    if [ $? -ne 0 ] ; then exit ; fi

    echo "$mdrun -nt $nproc -v -deffnm em -pin on -pinoffset $usedprocs"
    $mdrun -nt $nproc -v -deffnm em -pin on -pinoffset $usedprocs
    if [ $? -ne 0 ] ; then exit ; fi

    # plot course of minimisation
    echo "Potential" | $g_energy -f em.edr -o em_energy.xvg

    # generate PDB file (use trjconv with a TPR reference to preserve chains)
    #$editconf -f em.gro -o em_PBC.pdb
    echo "System" | $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump

fi
# generate PDB file with the whole system
if [ -e em.gro -a ! -e em.pdb ] ; then 
    $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump <<< 0 
fi

echo "Energy minimization done"


# Before proceeding, find out how many groups do we have for
# temperature coupling
#
# we want to treat solute and solvent as separate groups
# but if there are no non-protein atoms, then the non-protein group
# does not exist
#
#	XXX JR XXX SEE OPLS-AA.BASH
#
n=`out='no' grep  -v "^[;#]" Complex.top | while read line ; do 
        if [ "$out" == 'yes' ] ; then 
            echo $line 
        fi 
    	if [ "$line" == "[ molecules ]" ] ; then 
            out="yes" 
        fi
    done | grep -v '^\[' | grep -v "^Protein" | wc -l`

if [ $n -eq 0 ] ; then
    grp="Protein"
    tau_t="0.1"
    ref_t="$temperature"
else
    # XXX JR XXX THIS SHOULD BE SOLUTE SOLVENT"
    grp="Protein Non-Protein"
    tau_t="0.1	0.1"
    ref_t="$temperature	$temperature"
fi


# check if an equilibration has been requested
#	note that if MD has been requested,
#	then optimization and equilibration are forced 
#	as well, i.e. if there is no equilibration there 
#	cannot be MD either, so we are done
if [ "$equilibrate" == "no" ] ; then exit ; fi


banner " N V T  "

echo '
#-------------------------------------------------------------------------
#		1: EQUILIBRATE IN NVT ENSEMBLE
#	ISOTHERMAL-ISOCHORIC        CANONICAL ENSEMBLE
#-------------------------------------------------------------------------
'

#	From: www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/06_equil.html
#
# EM ensured that we have a reasonable starting structure, in terms of 
# geometry and solvent orientation. To begin real dynamics, we must equilibrate 
# the solvent and ions around the protein. If we were to attempt unrestrained 
# dynamics at this point, the system may collapse. The reason is that the 
# solvent is mostly optimized within itself, and not necessarily with the 
# solute. It needs to be brought to the temperature we wish to simulate and 
# establish the proper orientation about the solute (the protein). After we 
# arrive at the correct temperature (based on kinetic energies), we will apply 
# pressure to the system until it reaches the proper density.
#
# Remember that posre.itp file that pdb2gmx generated a long time ago? 
# We're going to use it now. The purpose of posre.itp is to apply a position 
# restraining force on the heavy atoms of the protein (anything that is not 
# a hydrogen). Movement is permitted, but only after overcoming a substantial 
# energy penalty. The utility of position restraints is that they allow us to 
# equilibrate our solvent around our protein, without the added variable of 
# structural changes in the protein.
#

# Equilibration is often conducted in two phases. The first phase is conducted
# under an NVT ensemble (constant Number of particles, Volume, and Temperature).
# This ensemble is also referred to as "isothermal-isochoric" or "canonical." 
# The timeframe for such a procedure is dependent upon the contents of the 
# system, but in NVT, the temperature of the system should reach a plateau at 
# the desired value. If the temperature has not yet stabilized, additional 
# time will be required. Typically, 50-100 ps should suffice, and we will 
# conduct a 200-ps NVT equilibration to be on the safe side.
#


if [ -s nvt.pdb ] ; then
	echo "nvt.pdb exists. Skipping initial NVT equilibration"
else
    if [ ! -e nvt.mdp ] ; then
        config_nvt    
    fi
    
	# if we have no solvent and the system is charged, we'll get a warning
	if [ "$solvate" != 'yes' ] ; then maxwarn=3 ; else maxwarn=0 ; fi
	
    # Run NVT equilibration
    if [ ! -e nvt.tpr ] ; then
        $grompp -f nvt.mdp -c em.gro -p Complex.top -o nvt.tpr \
				-r em.gro -maxwarn $maxwarn
    fi

    if [ $? -ne 0 ] ; then exit ; fi

    if [ ! -e nvt.gro ] ; then 
        $mdrun -nt $nproc -s nvt.tpr  -deffnm nvt -v -pin on -pinoffset $usedprocs
    fi
    
    if [ $? -ne 0 ] ; then exit ; fi

    if [ ! -e nvt.pdb ] ; then
        # generate PDB file
        #$editconf -f nvt.gro -o nvt_PBC.pdb
	     echo "System" | $trjconv -f nvt.gro -s nvt.tpr -o nvt.nj.pdb -pbc nojump
 	     echo "System" | $trjconv -f nvt.gro -s nvt.tpr -o nvt.pdb -pbc mol
   fi

fi

# Generate monitor files
if [ ! -e nvt_pot_energy.xvg ] ; then
    # plot energy progress
    echo "Potential" | $g_energy -f nvt.edr -o nvt_pot_energy.xvg
fi

if [ ! -e nvt_temperature.xvg ] ; then
    # Check if equilibration was achieved (requires manual supervision)
    #	In the NVT equilibration step we want to ensure that the
    #	correct temperature was reached and stabilized.
    #	Typically 50-100ps should suffice.
    echo "Temperature" | $g_energy -f nvt.edr -o nvt_temperature.xvg
fi

echo ""
echo "NVT equilibration done"
echo ""

banner " N P T  "

echo '
#-------------------------------------------------------------------------
#		2: EQUILIBRATE IN NPT ENSEMBLE
#		      ISOTHERMAL-ISOBARIC
#-------------------------------------------------------------------------
'
#
#	From: www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/07_equil2.html
#
#
# The previous step, NVT equilibration, stabilized the temperature of the
# system. Prior to data collection, we must also stabilize the pressure (and 
# thus also the density) of the system. Equilibration of pressure is conducted
# under an NPT ensemble, wherein the Number of particles, Pressure, and 
# Temperature are all constant. The ensemble is also called the 
# "isothermal-isobaric" ensemble, and most closely resembles experimental 
# conditions.
#
# The .mdp file used for the next NPT equilibration is not drastically
# different from the parameter file used for NVT equilibration. Note the
# addition of the pressure coupling section, using the Parrinello-Rahman
# barostat.
#
# A few other changes:
#
#	continuation = yes: We are continuing the simulation from the NVT 
#			equilibration phase
#	gen_vel = no: Velocities are read from the trajectory (see below)
#

if [ -s npt.pdb ] ; then
	echo "npt.pdb exists: Skipping subsequent NPT equilibration"
else
    if [ ! -e npt.mdp ] ; then
        config_npt
    fi
    
    # Run NPT equilibration
    
	# if we have no solvent and the system is charged, we'll get a warning
	if [ "$solvate" != 'yes' ] ; then maxwarn=3 ; else maxwarn=0 ; fi

    if [ ! -e npt.tpr ] ; then
        $grompp -f npt.mdp -c nvt.gro -t nvt.cpt -p Complex.top -o npt.tpr \
		        -r nvt.gro -maxwarn $maxwarn
    fi
    
    if [ $? -ne 0 ] ; then exit ; fi

    if [ ! -e npt.gro ] ; then
        $mdrun -nt $nproc -s npt.tpr -deffnm npt -v -pin on -pinoffset $usedprocs
    fi
    
    if [ $? -ne 0 ] ; then exit ; fi

    if [ ! -e npt.pdb ] ; then
        # generate PDB file
        #$editconf -f npt.gro -o npt_PBC.pdb
	    echo "System" | $trjconv -f npt.gro -s npt.tpr -o npt.nj.pdb -pbc nojump
	    echo "System" | $trjconv -f npt.gro -s npt.tpr -o npt.pdb -pbc mol
    fi
fi

    # At this point we should check that both, temperature and pressure 
    # are equilibrated
    #
    # The pressure value fluctuates widely over the course of the equilibration
    # phase, but this behavior is not unexpected. The running average of these 
    # data can be plotted as a red line in the plot. Over the course of the 
    # equilibration, the expected average value of the pressure is ~1.0 bar.
    #
    # As with the pressure, the running average of the density may also be plotted 
    # in red. The average value over the course of the simulation should be close
    # to the experimental value of 1000 kg m-3 and the expected density of the 
    # SPC/E model of 1008 kg m-3. The parameters for the SPC/E water model closely 
    # replicate experimental values for water. The density values should be very
    # stable over time, indicating that the system is well-equilibrated now with
    # respect to pressure and density.
    #

if [ ! -e npt_pot_energy.xvg ] ; then
    # plot energy progress
    echo "Potential" | $g_energy -f npt.edr -o npt_pot_energy.xvg
    echo "Total-Energy" | $g_energy -f npt.edr -o npt_tot_energy.xvg
fi
if [ ! -e npt_temperature.xvg ] ; then
    # plot temperature
    echo "Temperature" | $g_energy -f npt.edr -o npt_temperature.xvg
fi
if [ ! -e npt_density.xvg ] ; then
    # plot density (no longer available)
    echo "Density" | $g_energy -f npt.edr -o npt_density.xvg
fi
if [ ! -e npt_pressure.xvg ] ; then
    # plot pressure
    echo "Pressure" | $g_energy -f npt.edr -o npt_pressure.xvg
fi

echo "NPT equilibration done"

# Check if we have been asked to do an MD simulation
#
if [ "$longrun" == "no" -a "$shortrun" == "no" ] ; then exit ; fi

banner "  M  D  "

echo '
#-------------------------------------------------------------------------
#		RUN MD SIMULATION
#-------------------------------------------------------------------------
'

#	From: http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/08_MD.html
#
# Upon completion of the two equilibration phases, the system is now 
# well-equilibrated at the desired temperature and pressure. We are now 
# ready to release the position restraints and run production MD for data 
# collection. The process is just like we have seen before, as we will 
# make use of the checkpoint file (which in this case now contains preserve 
# pressure coupling information) to grompp. 

# we should check if an MD run already exist and if so, extend it
if [ -s md.pdb ] ; then
	echo "md.pdb exists. Skipping MD simulation"
else
    config_md

    # Run simulation
    #                           -t npt.trr???
    $grompp -maxwarn 3 -f md.mdp -c npt.gro -t npt.cpt -p Complex.top -o md.tpr

    if [ $? -ne 0 ] ; then exit ; fi

    $mdrun -nt $nproc -v -deffnm md -pin on -pinoffset $usedprocs


    if [ $? -ne 0 ] ; then exit ; fi

    # Create PDB file
    #$editconf -f md.gro -o md_PBC.pdb
    echo "System" | $trjconv -f md.gro -s md.tpr -o md.pdb -pbc nojump
fi
echo "MD run completed"

echo '
#-------------------------------------------------------------------------
#		ANALYSE MD RUN
#-------------------------------------------------------------------------
'
banner 'ANALYSIS'

if [ -e analysed ] ; then
	echo "simulation already analysed. Skipping analysis"
else

    # Create a low-res XTC trajectory file (TRR is high precision and larger)
    if [ ! -e md.xtc ] ; then
        echo "System" | $trjconv -f md.trr -s md.tpr -o md.xtc
    fi

    # analysis (correct trajectory for PBC)
    if [ ! -e md_noPBC.xtc ] ; then
        echo "System" | $trjconv -s md.tpr -f md.xtc -o md_noPBC.xtc -pbc mol -ur compact
    fi

    # Create trajectory without the water
    echo "Solute" | $trjconv -f md.xtc -s md.tpr -o md_complex.xtc
    echo "Solute" | $tpbconv -s md.tpr -o md_complex.tpr
    echo "Solute"  | $trjconv -s md_complex.tpr -f md_complex.xtc -o md_complex.gro -dump 0

    # fit system to itself for easier manipulation
    $trjconv -s md_complex.tpr -f md_complex.xtc -o md_complex_fit.xtc -fit rot+tran <<END
System
System
END

    # Compute various graphs
    echo "Potential" | $g_energy -f md.edr -o md_potenergy.xvg
    echo "Kinetic" | $g_energy -f md.edr -o md_kinenergy.xvg
    echo "Total-Energy" | $g_energy -f md.edr -o md_totenergy.xvg
    echo "Pressure" | $g_energy -f md.edr -o md_pressure.xvg
    echo "Temperature" | $g_energy -f md.edr -o md_temperature.xvg
    #echo "Volume" | $g_energy -f md.edr -o md_volume.xvg
    echo "Density" | $g_energy -f md.edr -o md_density.xvg

    #	1. RMSD (movement w.r.t. original conformation)
    #	Show structural stability using ns as time unit
    $g_rms -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsd.xvg -tu ns <<END
Backbone
Backbone
END

    $g_rms -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsd_atp.xvg -tu ns <<END
non-Protein
non-Protein
END

    #	2. RMSF (movility per atom/residue)
    #	backbone
    echo "Backbone" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_bb.xvg -res
    #	side chains
    echo "SideChain" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_sc.xvg
    #	non-protein (ligands + ions)
    echo "non-Protein" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_np.xvg
    #	ATP
    #echo "14" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_atp.xvg -oq md_complex_rmsf_atp.xvg
    #	Makes no sense for MG (only one atom)
    #	UD1
    #echo "15" | $g_rmsf -s md_complex.tpr -f md_complex_fit.xtc -o md_complex_rmsf_ud1.xvg -oq md_complex_rmsf_ud1.xvg


    #	3. Radius of gyration (compactness and stability of the structure)
    #	backbone
    # The radius of gyration of a protein is a measure of its compactness. If a 
    # protein is stably folded, it will likely maintain a relatively steady value 
    # of R_g. If a protein unfolds, its R_g will change over time. 
    #
    echo "Backbone" | $g_gyrate -s md_complex.tpr -f md_complex.xtc -o md_complex_gyr.xvg

    #	4. Compute secondary structure changes
    $do_dssp -f md_complex.xtc -s md_complex.tpr -sc md_complex_scount.xvg -o md_complex_ss.xpm -dt 10 <<END
MainChain
END

    cat > ps.m2p <<END
; Matrix options
titlefont       = Helvetica     ; Matrix title Postscript Font name
titlefontsize   = 20.0          ; Matrix title Font size (pt)
legend          = yes           ; Show the legend
legendfont      = Helvetica     ; Legend name Postscript Font name
legendfontsize  = 12.0          ; Legend name Font size (pt)
legendlabel                     ; Used when there is none in the .xpm
legend2label                    ; Id. when merging two xpm s
xbox            = 2.0           ; x-size of a matrix element
ybox            = 20.0          ; y-size of a matrix element
matrixspacing   = 20.0          ; Space between 2 matrices
xoffset         = 0.0           ; Between matrix and bounding box
yoffset         = 0.0           ; Between matrix and bounding box

; X-axis options
x-lineat0value  = no            ; Draw line at matrix value==0
x-major         = 1000.0        ; Major tick spacing
x-minor         = 500.0         ; Id. Minor ticks
x-firstmajor    = 0.0           ; Offset for major tick
x-majorat0      = no            ; Additional Major tick at first frame
x-majorticklen  = 8.0           ; Length of major ticks
x-minorticklen  = 4.0           ; Id. Minor ticks
x-label         =               ; Used when there is none in the .xpm
x-font          = Helvetica     ; Axis label PostScript Font
x-fontsize      = 12            ; Axis label Font size (pt)
x-tickfont      = Helvetica     ; Tick label PostScript Font
x-tickfontsize  = 8             ; Tick label Font size (pt)

;Y-axis options
y-lineat0value  = no
y-major         = 10.0
y-minor         = 5.0
y-firstmajor    = 0.0
y-majorat0      = no
y-majorticklen  = 8.0
y-minorticklen  = 4.0
y-label         =
y-fontsize      = 12
y-font          = Helvetica
y-tickfontsize  = 8
y-tickfont      = Helvetica
END

    $xpm2ps -f md_complex_ss.xpm -di ps.m2p -o md_complex_ubq_ss.eps



    #	5. Clusterize trajectory and output central structures in
    #	each cluster.
    #g_cluster -s md_complex.tpr -f md_complex.trr -dist rmsd-distribution.xvg \
    #	-o clusters.xpm -sz cluster-sizes.xvg -tr cluster-transitions.xpm \
    #        -ntr cluster-transitions.xvg -clid cluster-id-over-time.xvg \
    #        -cl clusters.pdb -cutoff 0.25 -method gromos -dt 10 [ -av ]
    $g_cluster -s md.tpr -f md.trr -cl clusters.pdb -cutoff 5 \
	    -method gromos -dt 10 <<END
Protein
System
END
    # and now get the cluster average structures
    $g_cluster -s md.tpr -f md.xtc -cl clustav.pdb -cutoff 5 \
	    -method gromos -dt 10 -av <<END
Protein
System
END


    # create an index of all ligands
#    $make_ndx  -f md.tpr -o lig.ndx <<END
#13 | 14 | 15
#q
#END

    # count H-bonds (protein vs. ligands)
    $g_hbond -f md.xtc -s md.tpr -n lig.ndx \
	    -num md_hbnum.xvg -ac md_hbac.xvg \
            <<END
Protein
Other
END

    # create an index of protein plus all ligands
#    $make_ndx  -f md.tpr -o pro+lig.ndx <<END
#1| 13 | 14 | 15
#q
#END

    # protein surface area
    $g_sas -s md.tpr -f md.xtc -o md_sasa.xvg -tv md_vol.xvg -n pro+lig.ndx <<END
Protein
Protein
END

    # Visualise with VMD
    #vmd md.gro md.trr

    touch analysed
fi
echo "Analysis done"

# try first with trjconv and the TPR file to preserve chain information
# using the TPR file as reference and removing PBC
if [ -e em.gro -a ! -e em.pdb ] ; then $trjconv -f em.gro -s em.tpr -o em.pdb -pbc nojump <<< 0 ; fi
if [ -e nvt.gro -a ! -e nvt.pdb ] ; then $trjconv -f nvt.gro -s nvt.tpr -o nvt.pdb -pbc nojump <<< 0 ; fi
if [ -e npt.gro -a ! -e npt.pdb ] ; then $trjconv -f npt.gro -s npt.tpr -o npt.pdb -pbc nojump <<< 0 ; fi
if [ -e md.gro -a ! -e md.pdb ] ; then $trjconv -f md.gro -s md.tpr -o md.pdb -pbc nojump <<< 0 ; fi

# if that failed, tray with editconf
# editconf loses chain information because .gro lacks it, it will also keep PBC
if [ -e em.gro -a ! -e em.pdb ] ; then $editconf -f em.gro -o em_PBC.pdb <<< 0 ; fi
if [ -e nvt.gro -a ! -e nvt.pdb ] ; then $editconf -f nvt.gro -o nvt_PBC.pdb <<< 0 ; fi
if [ -e npt.gro -a ! -e npt.pdb ] ; then $editconf -f npt.gro -o npt_PBC.pdb <<< 0 ; fi
if [ -e md.gro -a ! -e md.pdb ] ; then $editconf -f md.gro -o md_PBC.pdb <<< 0 ; fi


# We are done
cd ..
