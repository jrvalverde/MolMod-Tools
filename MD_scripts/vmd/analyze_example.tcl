
# This is a simple example script that shows how to use the analyze command
# to analyze DCD files on the fly.  I create a global data structure called
# mydata to hold the results for the whole trajectory.  The proc my_analysis
# is called each time a frame is loaded and appends data for that frame to
# mydata.

source trajectory_analyze.txt

set mydata {}

proc my_analysis { frame } {
  global mydata
  puts "The current frame is $frame"
  set sel [atomselect top "within 3 of resid 5"]
  lappend mydata [measure center $sel]
}
 
analyze my_analysis

cd /home/justin/vmd/vmd/proteins
mol load psf alanin.psf dcd alanin.dcd

