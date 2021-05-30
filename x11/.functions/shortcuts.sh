#!/bin/bash

# Helpers
# e.g. <some output> | xcopy
alias xcopy="xclip -rmlastnl -selection clipboard"
alias xpaste="xclip -rmlastnl -selection clipboard -o"

# Applications
alias c="code ."

# Navigation
# associated with a private folder with notes, delcared as `$MY_NOTES` in ~/.env
alias notes="cd $MY_NOTES"
alias todo="$EDITOR $MY_NOTES/daily/todo"
alias note="$EDITOR $MY_NOTES/daily/notes"
