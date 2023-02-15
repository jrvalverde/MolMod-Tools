# SYNOPSIS
#   fileSize file ...
# DESCRIPTION
#   Returns the size of the specified file(s) in bytes, with each file's 
#   size on a separate output line.
fileSize() {
  local optChar='c' fmtString='%s'
  [[ $(uname) =~ Darwin|BSD ]] && { optChar='f'; fmtString='%z'; }
  stat -$optChar "$fmtString" "$@"
}

# Sample use:
if (( $(fileSize $1) != $(fileSize $2) )); then
  echo "They're different."
fi
