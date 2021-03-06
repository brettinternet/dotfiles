#!/bin/bash

# Helpers
# e.g. <some output> | xcopy
alias xcopy="xclip -rmlastnl -selection clipboard"
alias xpaste="xclip -rmlastnl -selection clipboard -o"

# Applications
alias c="code ."

# Navigation
DEV_DIR="$HOME/dev"
PERSONAL_DIR="${MY_PROJECTS:-$DEV_DIR/me}"
alias dev="cd $DEV_DIR"
alias me="cd $PERSONAL_DIR"
alias sandbox="cd $DEV_DIR/sandbox"

NOTES_DIR="${MY_NOTES:-$PERSONAL_DIR/notes}"
# associated with a private folder with notes, delcared as `$MY_NOTES` in ~/.env
alias notes="cd $NOTES_DIR"
alias todo="$EDITOR $NOTES_DIR/daily/todo"
alias note="$EDITOR $NOTES_DIR/daily/notes"
