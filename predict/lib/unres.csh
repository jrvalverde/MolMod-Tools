# By this script we intend to make a coarse-grained refinement of the cabs models
# by usgin the UNRES.v4-0 version

#!/bin/csh -f
setenv FGPROCS 1
setenv POT GB
setenv OUT1FILE YES
#-----------------------------------------------------------------------------
setenv UNRES_BIN $HOME/contrib/unres/unres-v4.0/bin
#-----------------------------------------------------------------------------
setenv DD $HOME/contrib/unres/unres-v4.0/PARAM
setenv BONDPAR $DD/bond_AM1.parm
setenv THETPAR $DD/theta_abinitio.parm
setenv THETPARPDB $DD/thetaml.5parm
setenv ROTPARPDB $DD/scgauss.parm
setenv ROTPAR $DD/rotamers_AM1_aura.10022007.parm
setenv TORPAR $DD/torsion_631Gdp.parm
setenv TORDPAR $DD/torsion_double_631Gdp.parm
setenv ELEPAR $DD/electr_631Gdp.parm
setenv SIDEPAR $DD/scinter_${POT}.parm
setenv FOURIER $DD/fourier_opt.parm.1igd_hc_iter3_3
#setenv SCCORPAR $DD/rotcorr_AM1.parm
setenv SCCORPAR $DD/sccor_pdb_shelly.dat
setenv SCPPAR $DD/scp.parm
setenv PATTERN $DD/patterns.cart
setenv PRINT_PARM NO
#-----------------------------------------------------------------------------
$UNRES_BIN $*

