cmd=~/work/britt/KChIP3/simul/cmd
#export GRAMMDAT=/opt/structure/gramm
export GRAMMDAT=$HOME/contrib/gramm
export PATH=~/bin:$PATH

f=${f:-$1}
dir=`dirname $f`
base=`basename $f .pdb`

# Change to working directory and set up link to model data file
cd $dir

if [ -e gramm/DONE ] ; then exit ; fi

if [ ! -d gramm ] ; then mkdir gramm ; fi
cd gramm

ln -s ../$base.pdb model.pdb
ln -s $cmd/gramm-rpar.gr rpar.gr
ln -s $cmd/gramm-rmol.gr rmol.gr
ln -s $cmd/gramm-wlist.gr wlist.gr

$GRAMMDAT/gramm scan coord

touch DONE
