#
# First released version
#
# potSel, gets estatic grid via Delphi for VMD volume data
# Oct 2001, Barry I.
#
# potSel <VMD_selection> <grid count> <dielectric_in> <dielectric_out>
#
# Example usage:
#  source potSel.01.tcl
#  mol pdbload 1bnf
#  set sel [atomselect top "not water"]      
#  potSel $sel 63 2 80
#   [then make new isosurface and volume_slice representations]
#
#
# Note: Super-hacky, charge and radius problems still pending
#        
#       Also, requires Delphi installation, not ubiquitous. 
#
proc potSel {sel igrid diel_in diel_out} {
    

	# since delphi uses fixed filename fortran fort.* files,
	# must work in a unique directory to avoid conflicts
	# needs local compilation of delphi... or ssh to sgi machine 
	#evntually make this a unique directory
	#fix the pwd changing by using filejoins on all filenames
	set scratchDir  "/tmp/delphiTest"
	file mkdir $scratchDir 
	set delphiBinDir "/Home/g1/barryi/projects/vmd/delphi/bin/BIN.solaris"
	set delphiDataDir "/Home/g1/barryi/projects/vmd/delphi/data"
	set pdbFileName [file join $scratchDir "vmd-delphi.pdb"] 
	set paramFileName [file join $scratchDir "vmd-delphi.param"]
	#set chargeFileName  [file join $scratchDir "vmd-delphi.crg"]
	set sizeFileName [file join $scratchDir "vmd-delphi.siz"]
	#need to know mol so can load vol data into right mol
	set mol [$sel molid]
	$sel writepdb $pdbFileName 
	#run delphi, read results
	#need to set some params to fit molecule
	#should report anything (i.e. boxsize) we or delphi calculates.
	#catch[exec "/usr/bin/mkdir $scratchDir"]
	#cd $scratchDir
	#puts "working directory is [pwd], scratch dir is $scratchDir"
	# 
	# lindex [lsort -real [$sel get x] ] 0  

   #start by checking the radii, the charge code is commented out
   #set selRads [$sel get {name radius charge}]
   set selRads [$sel get {name radius}]
   set uniqueRads [lsort -unique -index 0 $selRads]

	set sizeFile  [open $sizeFileName w]
    puts $sizeFile "!atomic radii"
    #note that file ignores this first non-comment line
    puts $sizeFile "atom__res_radius_" 
   
    ##uncomment to allow charges to read from VMD 
    #set chargeFile [open $chargeFileName w]
    #puts $chargeFile "!atomic charges"
    #puts $chargeFile "atom__resnumbc_charge_"
     
    foreach a $uniqueRads {
        #note we are not specifying resname (maybe later, ever needed?), just put "" for this
        #send to sizeFile 
		set outText [format "%-6.6s%3.3s%8.3f" [lindex $a 0] "" [lindex $a 1] ]
		puts $sizeFile $outText

        #send to chargeFile, we're not using most fields 
        #set outText [format "%-6.6s%3.3s%4.4s%1.1s%8.3f" [lindex $a 0] "" "" "" [lindex $a 2] ]
        #puts $chargeFile $outText
	}
	close $sizeFile
    #close $chargeFile


		set paramFile [open $paramFileName w] 
		puts $paramFile "$igrid"
		puts $paramFile "60"
		puts $paramFile "0,0,0"
		puts $paramFile "$diel_in,$diel_out"
		puts $paramFile "0.145"
		puts $paramFile "0.,1.8"
		puts $paramFile "0"
		puts $paramFile "f,f,f"
		puts $paramFile "100"
		puts $paramFile "0"
		puts $paramFile "f,t"
		puts $paramFile "f"
		puts $paramFile "t"
		puts $paramFile "a=ion/c=ion/2,80,4nl/bc=c80/n=a"
		puts $paramFile "f"
		puts $paramFile "f"
		puts $paramFile "f"
		puts $paramFile "GCSA"
		puts $paramFile "f,f,10,1"

		close $paramFile

		puts "Using param file $paramFileName"
		#use exec for .com commands to run delphi

		exec  touch  [file join  $scratchDir fort.10] [file join  $scratchDir fort.11] [file join  $scratchDir fort.12] [file join  $scratchDir fort.13] [file join  $scratchDir fort.14] [file join  $scratchDir fort.17] [file join  $scratchDir fort.19]
		exec  rm  [file join  $scratchDir fort.10] [file join  $scratchDir fort.11] [file join  $scratchDir fort.12] [file join  $scratchDir fort.13] [file join  $scratchDir fort.14] [file join  $scratchDir fort.17] [file join  $scratchDir fort.19]

		 
		exec ln -s $paramFileName  [file join  $scratchDir fort.10]
		exec ln -s $sizeFileName  [file join  $scratchDir fort.11]
		exec ln -s [file join $delphiDataDir "default.crg"] [file join  $scratchDir fort.12]
		exec ln -s $pdbFileName [file join  $scratchDir fort.13]
		exec ln -s [file join $scratchDir  "out.phi"]  [file join  $scratchDir fort.14]
		exec ln -s [file join $scratchDir  "out.eps"]  [file join  $scratchDir fort.17]
		exec ln -s [file join $scratchDir "out.pdb"] [file join  $scratchDir fort.19]
		set cmnd "(cd $scratchDir; $delphiBinDir/qdiffxs >! out.log)"  
		puts "Now to execute: $cmnd"
		catch { exec  /bin/csh -c $cmnd } 
		#exec ssh titan $delphiBinDir/qdiffxs  
		# exec "/bin/rm fort* *.eps *.phi" 
		puts "Now to read in results from Delphi"
		readInsight  [file join $scratchDir  "out.phi"] $igrid
		#now give this to vmd 
		#mol volume $mol "test-sel-mol Potl Delphi/Insight, (1 unit)=(kT)=(25.6mV) " [list $xOrigin $yOrigin $zOrigin ] $xVec $yVec $zVec $igrid $igrid $igrid $valList
			
		# find out how to query for # of datasets for given mol's dataset 
		# then specify molid and add rep, so we see results onscreen
		#mol representation Isosurface 0.500000 $dataSet 1.000000 1.000000
		#mol selection all
		#mol material Opaque
		#mol addrep 3
}   



proc readInsight {fileName igrid} {
    #igrid is only for testing, should read from file directly... 
    #Do with big endian first, then make auto-switching on checking
    #the file. Note since some commands use native, others let one specify.
    # so, read read cell angle (sure to be 90), then
    #check $tcl_platform(byteOrder)   
    #  to find endian-ness, and set for appropriate
    # case statements (or formatting string vars.) to match with file / give error message. 
    # also-- signed or unsigned?
    puts "Reading in Delphi (Insight formatted) volume data  ..."
    set valList ""
    set count 0
    set in [open $fileName r]
    fconfigure $in -encoding binary -translation binary
   # Here, position file reading at FIRSt unit cell angle.
   #determine endianness of file 
   #although docs and some code comments claim insight format wants
   # 132 chars for toplbl, looks like toplbl var (what is written) is only 60 chars long
    binary scan [read $in 4] a4 dummyHeader
    binary scan [read $in 68] a68 topLabel
    puts "topLabel = >$topLabel<"
    binary scan [read $in 4] I ivary
      # 'i' is 32-bit big-endian integer
      #  !0  =>  x  index  varys  most rapidly
    puts "ivary= $ivary"
    binary scan [read $in 4] I nbyte 
    puts "nbyte= $nbyte"
    binary scan [read $in 4] I intdat 
    puts "intdat= $intdat"
    binary scan [read $in 4] f extent
    #repeat extent 3 times (in output code)
    puts "extent1= $extent"
    binary scan [read $in 4] f extent
    puts "extent2= $extent"
    binary scan [read $in 4] f extent
    puts "extent3= $extent"
    binary scan [read $in 4] f xang  
    binary scan [read $in 4] f yang 
    binary scan [read $in 4] f zang
    puts "xang= $xang, yang= $yang, zang= $zang"
    binary scan [read $in 4] f xstart
    binary scan [read $in 4] f xend
    puts "xstart= $xstart, xend= $xend"
    binary scan [read $in 4] f  ystart
    binary scan [read $in 4] f  yend
    puts "ystart= $ystart, yend= $yend"
    binary scan [read $in 4] f zstart
    binary scan [read $in 4] f zend
    puts "zstart = $zstart, zend= $zend"
    binary scan [read $in 4 ] I  intx 
    binary scan [read $in 4 ] I  inty 

    binary scan [read $in 4]  I  intz
    puts "intx =$intx, inty= $inty, intz= $intz"
    binary scan [read $in 4] I checka
    binary scan [read $in 4] I checkb
    puts "checka = $checka, checkb = $checkb"
    
    set valCount [expr $igrid * $igrid * $igrid]
  
    #binary scan [read $in [expr 4 * $valCount] ] f$valCount valList 
    	
 
      
  set valList "" 
   #if {$igrid <= 8 } {
	for {set i 0} {$i< $igrid} {incr i} { 
		for {set j 0} {$j< $igrid} {incr j} { 
                       # read valCount +2 because of fortran weirdness of putting to 0's at the end of each array line it emits
                       binary scan  [read $in [expr 4 * ($igrid + 2)] ] f$igrid readList 
                       append valList " "
                       append valList $readList 
                       #puts -nonewline "i=$i j=$j: "  
			for {set k 0} {$k < $igrid} {incr k} {
	                  set num  [expr ( $igrid*$igrid * $i) + ($igrid * $j) + $k] 
                          #puts -nonewline  " [lindex $valList $num] "
	}
       #puts "\n"
	}
	} 
#}
    puts "valList(9)= [lindex $valList 9], valList(27) = [lindex $valList 27], valList(0)= [lindex $valList 0], valList(1)= [lindex $valList 1], valList(2)= [lindex $valList 2], valList(3)= [lindex $valList 3], valList(4) = [lindex $valList 4], valList(5)= [lindex $valList 5], valList(6)= [lindex $valList 6],  valList(26)= [lindex $valList 26], valList([expr $valCount - 1])= [lindex $valList [expr $valCount - 1] ]"

    puts "Length of list is [llength $valList], count = $count, wanted total= $valCount"

   set xOrigin [expr $xstart * $extent] 
   set yOrigin [expr $ystart * $extent]
   set zOrigin [expr $zstart * $extent]	
   
   #for now, only implement for 90,90,90 degrees for all axis (what Delphi outputs)
   set xVec [list [expr ($xend  - $xstart) * $extent] 0 0] 
   set yVec [list 0 [expr ($yend - $ystart) * $extent] 0]
   set zVec [list 0 0 [expr ($zend - $zstart) * $extent] ] 
   puts "origin is $xOrigin $yOrigin $zOrigin"
   puts "xVec = $xVec"
   puts "yVec = $yVec"
   puts "zVec = $zVec" 
	 puts "Now to show surface in vmd..."
    # The vmd tcl command to load the volume data and build the isosurface
    # allows non-orthogonal vectors.  Here we just 
    mol volume top "SOD Potl Delphi/Insight, (1 unit)=(kT/2000e)=(25.6/2000mV) " [list $xOrigin $yOrigin $zOrigin] $xVec $yVec $zVec $igrid $igrid $igrid $valList
}
