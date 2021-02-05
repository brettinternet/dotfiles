#!/bin/bash

# Print console colors
function palette {
    local colors
    for n in {000..255}; do
        colors+=("%F{$n}$n%f")
    done
    print -cP $colors
}

# "up 6" to "cd ../../../../../.."
function up {
    if [[ "$#" < 1 ]] ; then
        cd ..
    else
        CDSTR=""
        for i in {1..$1} ; do
            CDSTR="../$CDSTR"
        done
        cd $CDSTR
    fi
}
