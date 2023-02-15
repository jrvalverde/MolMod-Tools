n=$1

MENCODER='no'
FFMPEG='yes'


if [ "$MENCODER" == 'yes' ] ; then
    for i in $n.*.ppm ; do
	if [ ! -s `basename $i ppm`jpg ] ; then
            echo -n "$i -> "`basename $i ppm`jpg
            #convert -quality 100 $i `basename $i ppm`jpg
	fi
	if [ ! -s `basename $i ppm`png ] ; then
            echo " $i -> "`basename $i ppm`png
            convert -quality 100 $i `basename $i ppm`png
	fi
	#rm $i
    done

#    # simple encoding
    mencoder "mf://$n.*.png" -mf type=png:fps=25 -ovc lavc -o ${n}_lq.mp4

#    # medium quality
    mencoder mf://$n.*.png -mf w=800:h=800:fps=25:type=png \
            -ovc lavc \
            -lavcopts vcodec=mpeg4:mbd=2:trell -oac copy -o ${n}_mq.mp4

#    # encoding with msmpeg4v2
    mencoder -mc 0 -noskip -skiplimit 0 \
             -ovc lavc \
             -o vcodec=msmpeg4v2:vhq \
             mf://$n.*.png -mf type=png:fps=18 -o ${n}_ms.mp4

    # enhanced AVI encoding
    mencoder -mc 0 -noskip -skiplimit 0 \
             -ovc lavc -o \
             vcodec=mpeg4:vhq:trell:mbd=2:vmax_b_frames=1:v4mv:vb_strategy=0:o=luma_elim_threshold=0:vcelim=0:cmp=6:subcmp=6:precmp=6:predia=3:dia=3:vme=4:vqscale=1 \
             mf://$n.*.png -mf type=png:fps=18 -o $n.mp4

    if [ -e zygBSO.mp3 ] ; then
        # add audio
        mencoder $n.mp4 -o ${n}+s.mp4 -ovc copy -oac copy -audiofile zygBSO.mp3
    fi
fi

if [ "$FFMPEG" == 'yes' ] ; then
    if [ ! -s $n.avi ] ; then	
        ffmpeg -r 20 -i $n.%05d.ppm -q:v 0 -vcodec libx264 \
	        -pix_fmt rgba $n.avi
    fi
    
    codec='libx264 -crf 18 -preset veryslow'
    #codec=mpeg4	    
    if [ -e zygBSO.mp3 -a ! -e ${n}+s.avi ] ; then
	# add audio
	# this one reencodes
	#ffmpeg -i $n.avi -i zygBSO.mp3 -codec copy -shortest ${n}+s.avi
	# this may be better
	# ffmpeg  -i $n.avi -i zygBSO.mp3 -c:v copy -c:a copy -shortest ${n}+s.avi
        ffmpeg  -i $n.%05d.ppm -i zygBSO.mp3 \
	        -vb 20M -q:v 0 -vcodec $codec \
		-c:a copy  -pix_fmt rgba \
		-r 20 \
		-shortest ${n}+s.avi
    fi
    if [ -e zygBSO4.mp3 -a ! -e ${n}+ss.avi ] ; then
        ffmpeg  -i $n.%05d.ppm \
		-i zygBSO1.mp3 -i zygBSO2.mp3 -i zygBSO3.mp3 -i zygBSO4.mp3 \
		-map 0:v -map 1:a -map 2:a -map 3:a -map 4:a \
		-vb 20M -q:v 0 -vcodec $codec \
		-c:a copy \
		-shortest ${n}+ss.avi 
    fi
fi

exit
#
# some additional recipes
#

# if mpeg2encode or mjpegtools is available convert may be used as well
convert $n.*.png $n.mpeg

# or for an animated GIF
convert $n.*.png $n.gif

exit
# replacing audio with mencoder
mencoder -ovc copy -nosound video.avi -o video_nosound.avi
mencoder -ovc copy -audiofile soundtrack.mp3 -oac copy video_nosound.avi -o video_new.avi

# replace audio and encode to mpeg
mencoder -ovc copy -audiofile PandaKing.zh.ac3 -oac copy KFP.avi -of mpeg -mpegopts \
format=mpeg2:vaspect=16/9 -o KFP.mpg

