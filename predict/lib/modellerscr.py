# Here we will find several functions which can be used to fuse all the fragments
# from a protein after their structure was predicted and therefore predict the
# overall structure of the protein. To accomplish this a python script was written
# which uses the MODELLER software. 
#!/usr/bin/env python3

import argparse
from modeller import *
from Bio import SeqIO
from modeller.automodel import *
from modeller.scripts import complete_pdb

# SLIB is /usr/lib/modeller10.2/modlib/ in our installation

def convert_fasta_to_pir(fastafile, outputpir):
	records = SeqIO.parse(fastafile, "fasta")
	count = SeqIO.write(records, outputpir, "pir")
	return(count) 

log.verbose()

def align_multiple_templates(outputali, pdbsdirectory):

   env = Environ()
   aln = Alignment(env)
   env.io.atom_files_directory = [pdbsdirectory]

   for num in range(0, 81):
      name = 'model_' + str(num) 
      
      for (code, chain) in (name, 'A'):
         mdl = Model(env, file=code, model_segment=('FIRST:'+chain, 'LAST:'+chain))
         aln.append_model(mdl, atom_files=code, align_codes=code+chain)

   for (weights, write_fit, whole) in (((1., 0., 0., 0., 1., 0.), False, True),
				      ((1., 0.5, 1., 1., 1., 0.), False, True),
				      ((1., 1., 1., 1., 1., 0.), True, False)):
      aln.salign(rms_cutoff=3.5, normalize_pp_scores=False,
		 rr_file='$(LIB)/as1.sim.mat', overhang=30,
		 gap_penalties_1d=(-450, -50),
		 gap_penalties_3d=(0, 3), gap_gap_score=0, gap_residue_score=0,
		 dendrogram_file='dendrogram.tree',
		 alignment_type='tree', # If 'progresive', the tree is not
					# computed and all structues will be
					# aligned sequentially to the first
		 feature_weights=weights, # For a multiple sequence alignment only
					  # the first feature needs to be non-zero
		 improve_alignment=True, fit=True, write_fit=write_fit,
		 write_whole_pdb=whole, output='ALIGNMENT QUALITY')

   aln.write(file='templatesalign.pap', alignment_format='PAP')
   aln.write(file=outputali, alignment_format='PIR')

   aln.salign(rms_cutoff=1.0, normalize_pp_scores=False,
	     rr_file='$(LIB)/as1.sim.mat', overhang=30,
	     gap_penalties_1d=(-450, -50), gap_penalties_3d=(0, 3),
	     gap_gap_score=0, gap_residue_score=0, dendrogram_file='improved_dendrogram.tree',
	     alignment_type='progressive', feature_weights=[0]*6,
	     improve_alignment=False, fit=False, write_fit=True,
	     write_whole_pdb=False, output='QUALITY')
   return(outputali)
		
def align_query_to_templates(alignmentfile, pirfile, outputali):
	  
   env = Environ()
   aln = Alignment(env)
   env.libs.topology.read(file='$(LIB)/top_heav.lib')
   # Read aligned structures             
   aln.append(file=alignmentfile, align_codes='all')
   aln_block = len(aln)

   # Read aligned sequence(s):
   aln.append(file=pirfile, align_codes='Q7Z333_canonical')

   # Structure sensitive variable gap penalty sequence-sequence alignment:
   aln.salign(output='', max_gap_length=20,
	     gap_function=True,   # to use structure-dependent gap penalty
	     alignment_type='PAIRWISE', align_block=aln_block,
	     feature_weights=(1., 0., 0., 0., 0., 0.), overhang=0,
	     gap_penalties_1d=(-450, 0),
	     gap_penalties_2d=(0.35, 1.2, 0.9, 1.2, 0.6, 8.6, 1.2, 0., 0.),
	     similarity_flag=True)

   aln.write(file='multiplealign.pap', alignment_format='PAP')
   aln.write(file=outputali, alignment_format='PIR')
   return(outputali)   
   
def build_model(malignfile):

   env = Environ()
   a = AutoModel(env, alnfile=malignfile,
		knowns=('model'), sequence='Q7Z333_canonical')
   a.starting_model = 1
   a.ending_model = 5
   a.make()
   
   
def model_evaluation(inputpdb):

   env = Environ()
   env.libs.topology.read(file='$(LIB)/top_heav.lib') # read topology
   env.libs.parameters.read(file='$(LIB)/par.lib') # read parameters

   mdl = complete_pdb(env, inputpdb)
   s = Selection(mdl)
   s.assess_dope(output='ENERGY_PROFILE NO_REPORT', file='TvLDH.profile',
		normalize_profile=True, smoothing_window=15)
   
   
   
# Here we define the arguments for the script modellerscr.py

parser = argparse.ArgumentParser(description='''Fusion of the structures predicted 
for the different fragments that form a protein by using the modeller software''')
parser.add_argument("-i", "--input_fasta", type=str, help="Input fasta file with the sequence of the protein")
parser.add_argument("-o", "--output_pir", type=str, help="Name for the fasta file converted to pir format")
parser.add_argument("-pd", "--pdbsdirectory", help="Path to the directory where the pdb templates are stored")
parser.add_argument("-t", "--templatesalignment", type=str, help="Name for the file of the templates alignment in pir format")
parser.add_argument("-mf", "--multiplealignmentfile", type=str, help="Name for the file with the templates alignment and the query sequence in pir format")
args = parser.parse_args()

def search_args(args):
 #This function parses the arguments we give in the command line and stores 
 #them in variables
   #default values
   fastafile = 'input.fasta'
   outputpir = 'output.pir'
   
   if args.input_fasta:
      fastafile = args.input_fasta
   if args.output_pir:
      outputpir = args.output_pir
      pirfile = args.output_pir
   if args.pdbsdirectory:
      pdbsdirectory = args.pdbsdirectory
   if args.templatesalignment:
      outputali = args.templatesalignment
   if args.multiplealignmentfile:
      malignname = args.multiplealignmentfile
   return (fastafile, outputpir, pirfile, pdbsdirectory, outputali, malignname)
   
(fastafile, outputpir, pirfile, pdbsdirectory, outputali, malignname) = search_args(args)
      
pirfile=convert_fasta_to_pir(fastafile, outputpir)
alignmentfile=align_multiple_templates(outputali, pdbsdirectory)
malignfile=align_query_to_templates(alignmentfile, pirfile, malignname)
build_model(malignfile)
#model_evaluation('TvLDH.B99990001.pdb')
# revisar el bucle for de la funcion align multiple templates porque habra que
# cambiarlo para que sea más general.   

