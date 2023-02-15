for i in *.profile ; do
    cat $i | sed -e 's/ \+/\t/g' -e 's/^\t//g' | grep -v '^$' > $i.tab
    gnuplot <<END
        set terminal png
        set output "$i.png"
        plot "$i.tab" using 1:42 with lines
END
    display $i.png
done
