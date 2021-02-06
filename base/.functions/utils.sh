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

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/c52e646bb7b109e15f6dc4047b29ca8c8e029433/lib/functions.zsh
function zsh_stats {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -20 | column -c3 -s " " -t | nl
}

function alias_value {
    (( $+aliases[$1] )) && echo $aliases[$1]
}
