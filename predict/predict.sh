
# the first argument should be the PDB code
code=$1

# create working directory
mkdir -p unicon3d/$code

# copy sequence to working directory
cp seq/rcsb_pdb_$code.fasta unicon3d/$code/rcsb_pdb_$code.faa

cd unicon3d/$code

if [ ! -e nncon/rcsb_pdb_${code}_000001.rebuilt.pdb ] ; then
    # run NNCON
    ../../script/nncon.sh rcsb_pdb_$code
fi

if [ ! -e nncon+homo/rcsb_pdb_${code}_000001.rebuilt.pdb ] ; then
    # run NNCON with homology
    ../../script/nncon+homo.sh rcsb_pdb_$code
fi

