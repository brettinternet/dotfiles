#!/bin/bash

# Applications
alias c="code ."

# Navigation
DEV_DIR="$HOME/dev"
PERSONAL_DIR="${MY_PROJECTS:-$DEV_DIR/me}"
alias dev='cd $DEV_DIR'
alias me='cd $PERSONAL_DIR'
alias sandbox='cd $DEV_DIR/sandbox'
alias work='cd $DEV_DIR/work'

# shellcheck disable=SC2034
NOTES_DIR="${MY_NOTES:-$PERSONAL_DIR/notes}"
# associated with a private folder with notes, delcared as `$MY_NOTES` in ~/.envrc
alias notes='cd $NOTES_DIR'
alias todo='$EDITOR $NOTES_DIR/daily/todo'
alias note='$EDITOR $NOTES_DIR/daily/notes'
