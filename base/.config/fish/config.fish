#!/usr/bin/fish

export SHELL=/bin/fish

# jomik/fish-gruvbox
theme_gruvbox dark hard

# No greeting when starting an interactive shell.
# https://github.com/fish-shell/fish-shell/issues/4706#issuecomment-363327906
function fish_greeting
end

export PATH="$PATH:$HOME/.local/bin"
