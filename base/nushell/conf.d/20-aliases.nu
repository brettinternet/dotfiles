def --wrapped cat [...rest] {
    if not (which bat | is-empty) {
        ^bat --theme=ansi ...$rest
    } else {
        ^cat ...$rest
    }
}

def --wrapped kubectl [...rest] {
    if not (which kubecolor | is-empty) {
        ^kubecolor ...$rest
    } else {
        ^kubectl ...$rest
    }
}

alias k = kubectl

def --wrapped ls [...rest] {
    if not (which eza | is-empty) {
        ^eza --group-directories-first ...$rest
    } else if $nu.os-info.name == "macos" {
        ^ls -G ...$rest
    } else {
        ^ls --color=auto ...$rest
    }
}

def shell_stats [] {
    history
    | get command
    | each {|entry| $entry | split words | first }
    | group-by
    | transpose command entries
    | insert count {|row| $row.entries | length }
    | sort-by count --reverse
    | first 20
    | select count command
}

def disk_ids [] {
    ^find /dev/disk/by-id/ -type l -print0
    | ^xargs -0 -I{} ls -l {}
    | ^grep -v -E '[0-9]$'
    | ^sort -k11
    | ^cut -d' ' -f9,10,11,12
}

def palette [] {
    let escape = (char --unicode 1b)
    for color in 0..255 {
        print --no-newline $"($escape)[38;5;($color)m($color)($escape)[0m "
        if (($color + 1) mod 16) == 0 {
            print ""
        }
    }
}

def terminal_title [title: string = ""] {
    print --no-newline $"(char --unicode 1b)]0;($title)(char --unicode 07)"
}

def --env home [] { cd ~ }
alias .. = cd ..
alias ... = cd ../..
alias .... = cd ../../..
def --env cdb [] { cd - }
def --env cls [] { clear; ls }
def --env ":q" [] { exit }

def --env up [levels: int = 1] {
    if $levels < 1 {
        error make {msg: "up: levels must be at least 1"}
    }
    cd (1..$levels | each { ".." } | path join)
}

def --env dotfiles [] { cd ~/.dotfiles }

alias ll = ls -lhF
alias lla = ls -lhAF
alias la = ls -AF
alias lsa = la
def lsg [pattern: string] { lla | ^grep $pattern }

alias psa = ^ps aux
def psg [pattern: string] { ^ps aux | ^grep -v grep | ^grep $pattern }
alias ka9 = killall -9
alias k9 = kill -9

alias df = ^df -h
alias du = ^du -h -d 2
alias grep = ^grep --color=auto
alias less = ^less -R
alias tf = ^tail -f
alias l = less
def lh [] { ls -alt | first 10 }

alias e = emacs
alias vi = vim
alias v = vim
alias gz = tar -zcvf

alias ta = tmux attach -t
alias tad = tmux attach -d -t
alias ts = tmux new-session -s
alias tl = tmux list-sessions
alias tksv = tmux kill-server
alias tkss = tmux kill-session -t

alias ce = context-editor
alias lg = lazygit

alias ha = herdr session attach
alias had = herdr session attach default
alias has = herdr session attach scratch
alias hl = herdr session list
alias h = herdr
