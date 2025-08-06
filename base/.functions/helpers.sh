#!/bin/bash

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/c52e646bb7b109e15f6dc4047b29ca8c8e029433/lib/functions.zsh
function shell_stats {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -20 | column -c3 -s " " -t | nl
}

function disk_ids {
  find /dev/disk/by-id/ -type l|xargs -I{} ls -l {}|grep -v -E '[0-9]$' |sort -k11|cut -d' ' -f9,10,11,12
}

# Print console colors
function palette {
  local colors
  for n in {000..255}; do
    colors+=("%F{$n}$n%f")
  done
  print -cP "${colors[@]}"
}

function password {
  LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32; echo ''
}

# Moving around
alias home='cd ~'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias cdb='cd -'
alias cls='clear;ls'
alias :q='exit'

# "up 6" to "cd ../../../../../.."
function up {
  if [[ "$#" -lt 1 ]] ; then
    cd ..
  else
    CDSTR=""
    for ((i=0; i<n; i++))
    do
      CDSTR="../$CDSTR"
    done
    cd $CDSTR || exit
  fi
}

# fzy (see .functions for more)
alias ff="find . -type f | fzy"
alias fh="history | fzy"

# https://wiki.archlinux.org/index.php/Sudo#Passing_aliases
alias sudo="sudo "

# Directories
alias dotfiles='cd ~/.dotfiles'

# ls
# note: alias ls is in .profile
alias ll='ls -lhF'
alias lla='ls -lhAF'
alias la='ls -AF'
alias lsa='la'
alias lsg='lla | grep'

# PS
alias psa="ps aux"
alias psg="ps aux | grep -v grep | grep"
alias ka9='killall -9'
alias k9='kill -9'

# Show human friendly numbers and colors
alias df='df -h'
alias du='du -h -d 2'

alias grep='grep --color=auto'

# Common shell functions
alias less='less -r'
alias tf='tail -f'
alias l='less'
alias lh='ls -alt | head' # see the last modified files
alias screen='TERM=screen screen'
alias ssh='TERM=xterm-256color; ssh'

# Editors
alias e='emacs'
alias vi='vim'
alias v='vim'

# Zippin
alias gz='tar -zcvf'
