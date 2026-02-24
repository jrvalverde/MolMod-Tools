function usage
{
    echo "AddToGit.sh allows user to push files to git in just one command,"
    echo "rather than using at least three (add, commit and push)"
    echo "To use this program, please type in the command line:"
    echo "bash AddToGit.sh -i fileToAdd -m \"Message to print\""
    echo "To see this help message again, type in the command line:"
    echo "bash AddToGit.sh -h"
}


if [ $# -ne 4 ]; then echo "Wrong number of arguments supplied!!"; usage; exit; fi
if [ $1 == "-i" ]; then file=$2 ; fi
if [ $3 == "-m" ]; then message=$4 ; fi
if [ $1 == "-h" ]; then usage ; exit ; fi



git add $file
echo "$file added to Git"

git commit -m $message
echo "$file commited with $message"

git push
echo "$file correctly pushed to Git"
