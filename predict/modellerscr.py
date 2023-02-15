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
# This function converts a given file in fasta formart with the sequence of the protein
# whose structure we want to predict, to pir format which is the one used as input
# by the modeller software. It has two arguments, the first one is the fasta file
# which will be the input of the function. And the second one will be the name of
# pir file that will be returned by the function
# Usage: 
#       convert_fasta_to_pir(sequence.fasta, sequence.ali)
    records = SeqIO.parse(fastafile, "fasta")
    count = SeqIO.write(records, outputpir, "pir")
    return(count) 

log.verbose()

def align_multiple_templates(outputali):
# This function makes a multiple alignment of the different templates that will
# be used to predict the structure of the query protein. For that purpose, pdb files
# of these proteins will be used. It has only one argument which is the name of the
# output PIR file that will be returned by the function.  
# Usage:
#       align_multiple_templates(templatesalign.ali) 
    env = Environ()    # Create an object of the Environ class
    aln = Alignment(env)    # Create an object of the Alignment class
    #env.io.atom_files_directory = [pdbsdirectory]

    # Obtain the code name and the chain of each template
    for (code, chain) in (('2mdh', 'A'), ('1bdm', 'A'), ('1b8p', 'A')):
       mdl = Model(env, file=code, model_segment=('FIRST:'+chain, 'LAST:'+chain))
       aln.append_model(mdl, atom_files=code, align_codes=code+chain)
    # Make the alignment multiple times to get a first alignment and then
    # improve it using more information
    for (weights, write_fit, whole) in (((1., 0., 0., 0., 1., 0.), False, True),
                                       ((1., 0.5, 1., 1., 1., 0.), False, True),
                                       ((1., 1., 1., 1., 1., 0.), True, False)):
       # Make the alignment                                
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
                  
    # Generate the output files with the alignment in PAP and PIR formats 
    aln.write(file='templatesalign.pap', alignment_format='PAP')
    aln.write(file=outputali, alignment_format='PIR')

    # Get a quality score
    aln.salign(rms_cutoff=1.0, normalize_pp_scores=False,
              rr_file='$(LIB)/as1.sim.mat', overhang=30,
              gap_penalties_1d=(-450, -50), gap_penalties_3d=(0, 3),
              gap_gap_score=0, gap_residue_score=0, dendrogram_file='improved_dendrogram.tree',
              alignment_type='progressive', feature_weights=[0]*6,
              improve_alignment=False, fit=False, write_fit=True,
              write_whole_pdb=False, output='QUALITY')
    return(outputali)

def align_query_to_templates(alignmentfile, pirfile, outputali):
# This function aligns the templates alignment done previously, with our query sequence.
# It has 3 arguments. The first one is the file in PIR formart with the templates
# alignment. The second one is the file with the query protein also in PIR format.
# And the third one is the name of the output file in PIR format returned by the function.
# Usage:
#       align_query_to_templates(templatesalign.ali, sequence.ali, multiplealign.ali)              
    env = Environ()    # Create an object of the Environ class
    aln = Alignment(env)    #Create an object of the Alignment class
    # Read the topology file from the MODELLER library
    env.libs.topology.read(file='$(LIB)/top_heav.lib')   
    
    # Read aligned structures             
    aln.append(file=alignmentfile, align_codes='all')
    aln_block = len(aln)

    # Read query sequence:
    aln.append(file=pirfile, align_codes='TvLDH')

    # Structure sensitive variable gap penalty sequence-sequence alignment:
    aln.salign(output='', max_gap_length=20,
              gap_function=True,   # to use structure-dependent gap penalty
              alignment_type='PAIRWISE', align_block=aln_block,
              feature_weights=(1., 0., 0., 0., 0., 0.), overhang=0,
              gap_penalties_1d=(-450, 0),
              gap_penalties_2d=(0.35, 1.2, 0.9, 1.2, 0.6, 8.6, 1.2, 0., 0.),
              similarity_flag=True)
              
    # Generate the output files with the alignment in PAP and PIR formats 
    aln.write(file='multiplealign.pap', alignment_format='PAP')
    aln.write(file=outputali, alignment_format='PIR')
    
    return(outputali)   

def build_model(malignfile):
# This function builds the model for our query protein from its alignment with 
# the different templates obtained earlier. It has one argument which is the file
# with the query-templates alignment in PIR format. 
# Usage:
#       build_model(multiplealign.ali) 

   env = Environ()   # Create an object of the Environ class
   # Create an object of the AutoModel class
   a = AutoModel(env, alnfile=malignfile,
                knowns=('1bdmA','2mdhA','1b8pA'), sequence='TvLDH')
   # Define the number of models we want to make which will be 5  
   a.starting_model = 1
   a.ending_model = 5
   # Make the models
   a.make()
   
   
def model_evaluation(inputpdb):
# This function evaluates the models obtained for the query proteins and gives
# them a score to assess which one is the best. It calculates the DOPE score for the model.
# It has one argument, a pdb file with the predicted model. 
# Usage:
#       model_evaluation(model.pdb)
 
   env = Environ() # Create an object of the Environ class
   env.libs.topology.read(file='$(LIB)/top_heav.lib') # read topology from the MODELLER library
   env.libs.parameters.read(file='$(LIB)/par.lib') # read parameters from the MODELLER library

   mdl = complete_pdb(env, inputpdb)  # read the PDB file
   # Calculate the DOPE score for the model
   s = Selection(mdl)
   s.assess_dope(output='ENERGY_PROFILE NO_REPORT', file='TvLDH.profile',
                normalize_profile=True, smoothing_window=15)
   
   
   
# Here we define the arguments for the script modellerscr.py

parser = argparse.ArgumentParser(description='''Fusion of the structures predicted 
for the different fragments that form a protein by using the modeller software''')
parser.add_argument("-i", "--input_fasta", type=str, help="input fasta file with the sequence of the protein")
parser.add_argument("-o", "--output_pir", type=str, help="name for the fasta file converted to pir format")
parser.add_argument("-pd", "--pdbsdirectory")
parser.add_argument("-t", "--templatesalignment", type=str, help='''name for the output file with 
the multiple templates aligned''')
parser.add_argument("-mf", "--multiplealignmentfile", type=str, help='''name for the output file with
the alignment of the entire protein with the templates''')
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
   #if args.pdbsdirectory:
   #   pdbsdirectory = args.pdbsdirectory
   if args.templatesalignment:
      outputali = args.templatesalignment
   if args.multiplealignmentfile:
      malignname = args.multiplealignmentfile
   return (fastafile, outputpir, pirfile, outputali, malignname)
   
(fastafile, outputpir, pirfile, outputali, malignname) = search_args(args)

# Call all the functions      
pirfile=convert_fasta_to_pir(fastafile, outputpir)
alignmentfile=align_multiple_templates(outputali)
malignfile=align_query_to_templates(alignmentfile, pirfile, malignname)
build_model(malignfile)
model_evaluation('TvLDH.B99990001.pdb')
# revisar el bucle for de la funcion align multiple templates porque habra que
# cambiarlo para que sea más general.   

