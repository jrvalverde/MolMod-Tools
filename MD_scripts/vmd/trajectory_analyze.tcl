
# The analyze command defined in this script lets you analyze DCD files on
# the fly.  To use it, source this file, then call analyze with the name
# of the script you want to be called each frame.  The script will be called
# with the current frame as its only argument.

proc analyze_callback { name1 name2 op } {
  global analyze_proc

  upvar $name1 arr
  set frame $arr($name2)
  uplevel #0 $analyze_proc $frame
}

proc analyze { script } {
  global analyze_proc

  set analyze_proc $script
  uplevel #0 trace variable vmd_frame w analyze_callback
}


