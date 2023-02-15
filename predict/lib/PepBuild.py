#!/usr/bin/env python3

import getopt, sys
from Bio import SeqIO
from Bio.PDB.Polypeptide import PPBuilder
from Bio.PDB import PDBParser
from Bio.PDB.PDBIO import PDBIO

import PeptideBuilder
from PeptideBuilder import Geometry

def add_residues_extended(seq):
    """
    Build a linear peptide (beta strand parameters from ProBuilder On-line)
    """
    # typical values are
    phi = -135
    psi = 135
    
    structure = PeptideBuilder.initialize_res(seq[0])
    for aa in seq[1:]:
        PeptideBuilder.add_residue(structure, aa)

    PeptideBuilder.add_terminal_OXT(structure)

    # extract peptide from structure and compare to expected
    ppb = PPBuilder()
    pp = next(iter(ppb.build_peptides(structure)))
    assert pp.get_sequence() == seq
    return(structure)


def add_residues_sheet(seq):
    """
    Build a parallel beta strand (params from ProBuilder On-line)
    """
    phi = -135
    psi_im1 = 135
    # add first residue
    geo = Geometry.geometry(seq[0])
    geo.phi = phi
    geo.psi_im1 = psi_im1
    structure = PeptideBuilder.initialize_res(geo)
    
    # add subsequent residues
    for aa in seq[1:]:
        geo = Geometry.geometry(aa)
        geo.phi = phi
        geo.psi_im1 = psi_im1
        if aa == "Proline":
            geo.phi = -75
            geo.psi = 150
        
        PeptideBuilder.add_residue(structure, geo)
    
    PeptideBuilder.add_terminal_OXT(structure)

    # extract peptide from structure and compare to expected
    ppb = PPBuilder()
    pp = next(iter(ppb.build_peptides(structure)))
    assert pp.get_sequence() == seq
    return(structure)



def add_residues_helix(seq):
    """
    Build an alpha helix (parameters from ProBuilder On-line)
    """
    phi = -57.80
    psi_im1 = -47.00
    # add first residue
    geo = Geometry.geometry(seq[0])
    geo.phi = phi
    geo.psi_im1 = psi_im1
    structure = PeptideBuilder.initialize_res(geo)
    
    # add subsequent residues
    for aa in seq[1:]:
        geo = Geometry.geometry(aa)
        geo.phi = phi
        geo.psi_im1 = psi_im1
        if aa == "Proline":
            geo.phi = -75
            geo.psi = 150
        
        PeptideBuilder.add_residue(structure, geo)
    
    PeptideBuilder.add_terminal_OXT(structure)

    # extract peptide from structure and compare to expected
    ppb = PPBuilder()
    pp = next(iter(ppb.build_peptides(structure)))
    assert pp.get_sequence() == seq
    return(structure)


def add_residues_coiledcoil(seq):
    """
    Build a helix containing all 20 amino acids, with slowly varying backbone angles
    """
    phi = -65
    psi_im1 = -40
    # add first residue
    geo = Geometry.geometry(seq[0])
    geo.phi = phi
    geo.psi_im1 = psi_im1
    structure = PeptideBuilder.initialize_res(geo)
    
    # add subsequent residues
    for aa in seq[1:]:
        geo = Geometry.geometry(aa)
        geo.phi = phi
        geo.psi_im1 = psi_im1
        if aa == "Proline":
            geo.phi = -75
            geo.psi = 150
        
        PeptideBuilder.add_residue(structure, geo)
    
    PeptideBuilder.add_terminal_OXT(structure)

    # extract peptide from structure and compare to expected
    ppb = PPBuilder()
    pp = next(iter(ppb.build_peptides(structure)))
    assert pp.get_sequence() == seq
    return(structure)



def make_ss3_structure(seq, ss):
# phi psi values for helix --> -60 and -60 // -60..-120 and -60  // -60 and -50
# phi psi values for sheet --> -120 and 120 // -135 and +135 // -120 and +135 // -140 and 130
# phi psi for coiled-coil --> -65 -40
# coil: -180/180
# helix: -60/-40
# sheet: -120/120
# ProBuilder Online: phi -135 / psi 135 / omega 180
#                    
    """
    Build a structure from sequence using a secondary-structure reference
    Parameters taken from ProBuilder On-line
    """
    phi_a = -57.80	# alpha helix
    psi_a = -47.00
    phi_a_3_10 = -74.00	# 3.10 helix
    psi_a_3_10 = -4.00
    phi_a_pi = 57.10	# Pi alpha helix
    psi_a_pi = -69.70
    phi_a_left = 57.80	# left-handed alpha helix
    psi_a_left = -47.00
    phi_b = -135	# beta strand
    psi_b = 135
    phi_b_parallel = -120.00	# parallel beta sheet
    psi_b_parallel = 115.00
    phi_b_antiparallel = -140.00	# anti-parallel beta sheet
    psi_b_antiparallel = 135-00
    phi_c = -180	# random coil (we'll assign an extended conformation)
    psi_c = 180
    phi_pro = -75	# proline
    psi_pro = 150
    # initialize structure
    structure = PeptideBuilder.initialize_res(seq[0])
    for i in range(1, len(seq)):
        aa = seq[i]
        geo = Geometry.geometry(aa)
        if ss[i] == "H":	# helix
            geo.phi = phi_a
            geo.psi_im1 = psi_a
        elif ss[i] == "E":	# strand
            geo.phi = phi_b
            geo.psi_im1 = psi_b
        elif ss[i] == "C":	# extended/random coil
            geo.phi = phi_c
            geo.psi_im1 = psi_c
        if aa == "P":
            geo.phi = phi_pro
            geo.psi_im1 = psi_pro
        PeptideBuilder.add_residue(structure, geo)
    PeptideBuilder.add_terminal_OXT(structure)
    return(structure)


# for 8 states we must consider:
# the DSSP algorithm designated helix into three types (G or 3-10 helix, 
# H or alpha-helix, and I or pi-helix), two kinds for strand (E or 
# beta-strand, and B or beta=bridge), and coil into three states (T or 
# hydrogen-bonded turn, S or high curvature loop, and L or, irregular)

def make_phi_psi_structure(seq, phi, psi):
    """
    Make a structure from a sequence and two arrays, one giving the 
    phi angles and one giving the psi angles, that have been 
    computed by ANGLOR
    """
    geo = Geometry.geometry(seq[0])
    geo.phi = phi[0]		# this should be unneeded
    geo.psi_im1 = psi[0]	# ditto.
    structure = PeptideBuilder.initialize_res(geo)
    # add subsequent residues
    for i in range(1, len(seq)):
        print(repr(i+1), '\t', phi[i], '\t', psi[i])
        geo = Geometry.geometry(seq[i])	# obtain this aa structure
        geo.phi = float(phi[i])		# modify its phi and psi angles
        geo.psi_im1 = float(psi[i])
        
        PeptideBuilder.add_residue(structure, geo)	# add the a.a.
    
    PeptideBuilder.add_terminal_OXT(structure)
    return(structure)



"""
PepBuild: create a draft peptidic structure from a FASTA sequence
"""

allargs = sys.argv
me = sys.argv[0]
nargs = len(sys.argv) - 1

arglist = allargs[1:]		# remove arg[0] (my own name)
short_opts = "hi:o:s:P:S:abcde"
long_opts = [ "help", "input=", "output=", 
	      "ss=", "phi=", "psi=", 
              "alpha", "beta", "coiledcoil", "disordered", "extended" ]
# extract arguments
try:
    args, values = getopt.getopt(arglist, short_opts, long_opts)
except getopt.error as err:
    print(str(err))
    sys.exit(1)

# defaults
alpha = beta = coil = disordered = extended = ss = pp = False
fastafile = 'seq.txt'
pdbfile = 'seq.pdb'
phi = []
psi = []

# parse arguments
for arg, val in args:
    if arg in ("-h", "--help"):
        print("Usage: PepBuild.py -h -i infile.fasta -o outfile.pdb")
        sys.exit(2)
    elif arg in ("-i", "--input"):
        fastafile = val
    elif arg in ("-o", "--output"):
        pdbfile = val
    elif arg in ("-s", "--ss"):
        # ss is specified as a fasta file where each "residue" indicates the 
        # secondary structure of the corresponding residue in the real sequence
        secstr = list(SeqIO.parse(val, "fasta"))[0] .seq
        ss = True
    elif arg in ("-P", "--phi"):
        phi = open(val, 'r').readlines()
        phi = [float(x.strip().split()[1]) for x in phi]
        pp = True
    elif arg in ("-S", "--psi"):
        psi = open(val, 'r').readlines()
        psi = [float(x.strip().split()[1]) for x in psi]
        pp = True
    elif arg in ("-a", "--alpha"):
        alpha = True
    elif arg in ("-b", "--beta"):
        beta = True
    elif arg in ("-c", "--coiledcoil"):
        coil = True
    elif arg in ("-d", "--disordered"):
        disordered = True
    elif arg in ("-e", "--extended"):
        extended = True


#for i in range(len(phi)):
#    print(repr(i+1), '    ', phi[i], '    ', psi[i])
#sys.exit(0)

for sequence in SeqIO.parse(fastafile, "fasta"):
    print(sequence.id)
    print(repr(sequence.seq))
    print(len(sequence))
    if alpha:
        structure = add_residues_helix(sequence.seq)
    elif beta:
        structure = add_residues_sheet(sequence.seq)
    elif coil:
        structure = add_residues_coiledcoil(sequence.seq)
    elif extended:
        structure = add_residues_extended(sequence.seq)
    elif ss:
        structure = make_ss3_structure(sequence.seq, secstr)
    elif pp:
        structure = make_phi_psi_structure(sequence.seq, phi, psi)
        # NOTE: for phi-psi prediction SPINE-X (Sparks) may work better 
        # than ANGLOR.
    else:
        structure = PeptideBuilder.make_extended_structure(sequence.seq)

io = PDBIO()
io.set_structure(structure)
io.save(pdbfile)


sys.exit(0)

