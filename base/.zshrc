export SHELL="/bin/zsh"

source $HOME/.profile
source $HOME/.aliases

[ -d "$HOME/.config/broot" ] && source $HOME/.config/broot/launcher/bash/br
[ -d "/usr/share/nvm" ] && source /usr/share/nvm/init-nvm.sh

fpath+=( "$HOME/.functions" )
autoload -Uz clock zman colortest


# -- Options ----------------------------------------

HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=10000

setopt interactive_comments
setopt append_history hist_ignore_dups hist_ignore_space hist_expire_dups_first
setopt inc_append_history # OR share_history
setopt pushd_ignore_dups
setopt auto_cd beep notify nomatch
setopt extended_glob glob_dots list_packed
setopt auto_pushd pushd_silent pushd_to_home pushd_ignore_dups pushd_minus
setopt auto_menu always_to_end complete_in_word
unsetopt flow_control menu_complete


# -- Bindkeys ----------------------------------------

bindkey -e # emacs mode

# Source: https://wiki.archlinux.org/index.php/Zsh#Key_bindings
#
# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[ShiftTab]="${terminfo[kcbt]}"

# setup key accordingly
[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"      beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"       end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"    overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}" backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"    delete-char
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"        up-line-or-history
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"      down-line-or-history
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"      backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"     forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"    beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"  end-of-buffer-or-history
[[ -n "${key[ShiftTab]}"  ]] && bindkey -- "${key[ShiftTab]}"  reverse-menu-complete

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -Uz add-zle-hook-widget
    function zle_application_mode_start {
        echoti smkx
    }
    function zle_application_mode_stop {
        echoti rmkx
    }
    add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
    add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

[[ -n "${key[Up]}"   ]] && bindkey -- "${key[Up]}"   up-line-or-beginning-search
[[ -n "${key[Down]}" ]] && bindkey -- "${key[Down]}" down-line-or-beginning-search


# -- Modules ----------------------------------------

zmodload -i zsh/complist


# -- Autoloads ----------------------------------------

autoload -Uz colors
colors

autoload -Uz edit-command-line
zle -N edit-command-line

autoload -Uz select-word-style
select-word-style shell


# -- Hooks ----------------------------------------

autoload -Uz add-zsh-hook

# Source: https://wiki.archlinux.org/index.php/Zsh#On-demand_rehash
ZSHCACHE_TIME="$(date +%s%N)"
rehash_precmd() {
    local REHASH_FILE="$HOME/.cache/zsh/rehash"
    if [[ -a "$REHASH_FILE" ]]; then
        local CACHE_TIME="$(date -r $REHASH_FILE +%s%N)"
        if (( ZSHCACHE_TIME < CACHE_TIME )); then
            rehash
            ZSHCACHE_TIME="$CACHE_TIME"
        fi
    fi
}

add-zsh-hook -Uz precmd rehash_precmd


# -- Zinit ----------------------------------------
# Comparison of all ZSH plugin managers https://www.reddit.com/r/zsh/comments/ak0vgi/a_comparison_of_all_the_zsh_plugin_mangers_i_used/

[[ ! -f ~/.zinit/bin/zinit.zsh ]] && {
    command mkdir -p ~/.zinit
    command git clone https://github.com/zdharma/zinit ~/.zinit/bin
}
source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit


# -- Local plugins ----------------------------------------

zinit ice atinit'local i; for i in *.(sh|zsh); do source $i; done'
zinit light ~/.functions

# -- Plugins via zinit ----------------------------------------
# Helpful plugin list: https://github.com/zdharma/Zsh-100-Commits-Club

# Fast-syntax-highlighting & autosuggestions
zinit wait lucid light-mode for \
  zsh-users/zsh-syntax-highlighting \
  atload"_zsh_autosuggest_start" \
  atinit"ZSH_AUTOSUGGEST_USE_ASYNC=true" \
    zsh-users/zsh-autosuggestions \
  atload"zicompinit; zicdreplay" \
    blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions


# -- Colorscheme

# dark version
zinit ice as"program" id-as"gruvbox-material-dark"
zinit snippet https://github.com/sainnhe/dotfiles/blob/b13cfb736a7ab27dacfc60a8df8b3485b9d00010/.zsh-theme-gruvbox-material-dark
# light version
# zinit ice as"program" id-as"gruvbox-material-light"
# zinit snippet https://github.com/sainnhe/dotfiles/blob/b13cfb736a7ab27dacfc60a8df8b3485b9d00010/.zsh-theme-gruvbox-material-light


# -- Prompt

# Prompt selection method: https://github.com/zdharma/zinit-configs/blob/b47a3a92f77cf4d7afbea9070a0a1db69cfed517/psprint/zshrc.zsh#L310

# https://github.com/geometry-zsh/geometry/blob/a8033e0e9a987c1a6ee1813b7cad7f28cfd3c869/options.md
zinit load geometry-zsh/geometry

get_hostname() {
  ansi 008 "[$(uname -n)]"
}

virtualenv() {
  venv=$(geometry_virtualenv)
  if [ -n "$venv" ]; then
    echo -n "($venv)"
  fi
}

GEOMETRY_PATH_COLOR=04
GEOMETRY_STATUS_COLOR="$(geometry::hostcolor)"
if [[ $SHOW_PROMPT_HOSTNAME = true ]]; then
  GEOMETRY_PROMPT=(geometry_echo get_hostname virtualenv geometry_status geometry_path)
else
  GEOMETRY_PROMPT=(geometry_echo virtualenv geometry_status geometry_path)
fi


# -- Autocompletion

# Fish Alt+l mimic
zstyle ":completion:file-complete::::" completer _files
zle -C file-complete complete-word _generic
zstyle -e ':completion:*:default' list-colors 'reply=("${PREFIX:+=(#bi)($PREFIX:t)(?)*==04=02}:${(s.:.)LS_COLORS}")'
zstyle ':completion:*' menu select
bindkey '^[l' file-complete

zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path $ZSH_CACHE_DIR
# zstyle ':completion:*' list-colors ''
# zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always
zstyle ":completion:*:descriptions" format "%B%d%b"
#zstyle ':completion:*:*:*:default' menu yes select search
