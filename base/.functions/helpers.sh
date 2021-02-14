#!/bin/bash

# Source: https://github.com/ohmyzsh/ohmyzsh/blob/c52e646bb7b109e15f6dc4047b29ca8c8e029433/lib/functions.zsh
function shell_stats {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -20 | column -c3 -s " " -t | nl
}

# Print console colors
function palette {
  local colors
  for n in {000..255}; do
    colors+=("%F{$n}$n%f")
  done
  print -cP $colors
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

# Helpers
# https://github.com/andreafrancia/trash-cli
alias rm='echo \"No way, man!\"; false'
alias rrm="/bin/rm -i"

# fzy (see .functions for more)
alias ff="find . -type f | fzy"
alias fh="history | fzy"

# https://wiki.archlinux.org/index.php/Sudo#Passing_aliases
alias sudo="sudo "

# Directories
alias dotfiles='cd ~/.dotfiles'
alias dev='cd ~/dev'
alias me='cd ~/dev/me'
alias sandbox='cd ~/dev/sandbox'

# ls
alias ls='ls --color=auto'
alias ll='ls -lhF'
alias lla='ls -lhAF'
alias la='ls -AF'
alias lsa='la'
alias lsg='lla | grep'

# List only directories
alias lld="lla $colorflag | grep --color=never '^d'"

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


# Vim
alias vi='vim'

# vimrc editing
alias ve='vim ~/.vimrc'
# zsh profile editing
alias ze='vim ~/.zshrc'
# fish profile editing
alias fe='vim ~/.config/fish/config.fish'

# Zippin
alias gz='tar -zcvf'

# ansible
# source: https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/ansible/ansible.plugin.zsh
# alias a='ansible '
# alias aconf='ansible-config '
# alias acon='ansible-console '
# alias aver='ansible-version'
# alias arinit='ansible-role-init'
# alias aplaybook='ansible-playbook '
# alias ainv='ansible-inventory '
# alias adoc='ansible-doc '
# alias agal='ansible-galaxy '
# alias apull='ansible-pull '
# alias aval='ansible-vault'
