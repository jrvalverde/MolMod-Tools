#!/bin/python
#
#	Calculate the total number of electrons in a neutral (non-ionic)
# molecule
#
#	The molecule is read from an XYZ file.
#
#	(C) 2013, Jose R. Valverde
#

#The sorted periodic table of elements
#elems = ["H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Uub", "Uut", "Uuq", "Uup", "Uuh", "Uuo" ]
#
# we'll use upper-case to be on the safe side
elems = ["H", "HE", "LI", "BE", "B", "C", "N", "O", "F", "NE", "NA", "MG", "AL", "SI", "P", "S", "CL", "AR", "K", "CA", "SC", "TI", "V", "CR", "MN", "FE", "CO", "NI", "CU", "ZN", "GA", "GE", "AS", "SE", "BR", "KR", "RB", "SR", "Y", "ZR", "NB", "MO", "TC", "RU", "RH", "PD", "AG", "CD", "IN", "SN", "SB", "TE", "I", "XE", "CS", "BA", "LA", "CE", "PR", "ND", "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM", "YB", "LU", "HF", "TA", "W", "RE", "OS", "IR", "PT", "AU", "HG", "TL", "PB", "BI", "PO", "AT", "RN", "FR", "RA", "AC", "TH", "PA", "U", "NP", "PU", "AM", "CM", "BK", "CF", "ES", "FM", "MD", "NO", "LR", "RF", "DB", "SG", "BH", "HS", "MT", "DS", "RG", "UUB", "UUT", "UUQ", "UUP", "UUH", "UUO" ]
#print elems[8-1]
#print elems.index('O')+1

import sys
import optparse

cmd_line = optparse.OptionParser()

cmd_line.add_option('-i', '--input-xyz',
                help='''The XYZ format coordinates input file''')

(opts, args) = cmd_line.parse_args()

# only for debugging
#print opts, args, len(args)


if len(args) == 0:
    if opts.input_xyz is None:
        sys.stderr.write("No molecule specified\n")
	print str(0)
        exit(-1)
    else:
        try:
            fin = open(opts.input_xyz, "r")
        except:
            sys.stderr.write("Cannot open" + opts.input_xyz + '\n')
            print str(0)
            exit(-1)
else:
    if args[0] == '-':
        fin = sys.stdin
    else:
        try:
            fin = open(args[0], "r")
        except:
            sys.stderr.write("Cannot open" + args[0] + '\n')
            print str(0)
            exit(-1)

natoms = int(fin.readline())
name = fin.readline()
#print str(natoms)
#print name,
i = 0
nelecs = 0
for line in fin:
    i += 1
    nelecs = nelecs + elems.index(line.split()[0].upper()) + 1
    #print str(nelecs), line,

if i != natoms:
    sys.stderr.write("Wrong number of atoms\n")
    print(0)
    exit(-1)  

print nelecs

fin.close()
