export SHELL="${commands[zsh]:-/bin/zsh}"
typeset -U path PATH fpath

source "$HOME/.profile"

fpath+=( "$HOME/.functions" )

BREW_ZSH_FUNCTIONS="/opt/homebrew/share/zsh/site-functions"
if [[ "$OSTYPE" == darwin* ]] && [[ -d "$BREW_ZSH_FUNCTIONS" ]] && \
    [[ "$(stat -f "%Su" "$BREW_ZSH_FUNCTIONS")" == "$(id -un)" ]]; then
  fpath+=( "$BREW_ZSH_FUNCTIONS" )
fi
unset BREW_ZSH_FUNCTIONS


# -- Options ----------------------------------------

HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=50000
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
command mkdir -p "$ZSH_CACHE_DIR"

setopt interactive_comments
setopt append_history extended_history hist_expire_dups_first hist_find_no_dups
setopt hist_ignore_dups hist_ignore_space hist_reduce_blanks hist_verify
setopt inc_append_history
setopt pushd_ignore_dups
setopt auto_cd beep notify nomatch
setopt extended_glob glob_dots list_packed
setopt auto_pushd pushd_silent pushd_to_home pushd_ignore_dups pushd_minus
setopt auto_menu always_to_end complete_in_word
unsetopt flow_control menu_complete


# -- Bindkeys ----------------------------------------

bindkey -e # emacs mode
# Some terminals can send Shift+Enter as LF (^J) while plain Enter sends CR (^M).
# Keep Enter submitting, but make Shift+Enter/Ctrl-J insert a literal newline.
bindkey '^J' self-insert

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

if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start { echoti smkx }
	function zle_application_mode_stop { echoti rmkx }
	add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
	add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi


key[Control-Left]="${terminfo[kLFT5]}"
key[Control-Right]="${terminfo[kRIT5]}"
key[Alt-b]=$'\e[98;3u'
key[Alt-f]=$'\e[102;3u'
key[Alt-Left]=$'\e[1;3D'
key[Alt-Right]=$'\e[1;3C'

# [[ -n "${key[Control-Left]}"  ]] && bindkey -- "${key[Control-Left]}"  backward-word
# [[ -n "${key[Control-Right]}" ]] && bindkey -- "${key[Control-Right]}" forward-word
[[ -n "${key[Alt-b]}"        ]] && bindkey -- "${key[Alt-b]}"        backward-word
[[ -n "${key[Alt-f]}"        ]] && bindkey -- "${key[Alt-f]}"        forward-word
[[ -n "${key[Alt-Left]}"     ]] && bindkey -- "${key[Alt-Left]}"     backward-word
[[ -n "${key[Alt-Right]}"    ]] && bindkey -- "${key[Alt-Right]}"    forward-word


# -- Modules ----------------------------------------

zmodload -i zsh/complist


# -- Autoloads ----------------------------------------

autoload -Uz colors
colors

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^G' edit-command-line

context-scrollback-widget() {
  zle -I
  context-scrollback
  zle reset-prompt
}
zle -N context-scrollback-widget
bindkey '^[S' context-scrollback-widget # Alt+Shift+S

autoload -Uz select-word-style
select-word-style shell


# -- Hooks ----------------------------------------

autoload -Uz add-zsh-hook



# -- Zinit ----------------------------------------
# Comparison of all ZSH plugin managers https://www.reddit.com/r/zsh/comments/ak0vgi/a_comparison_of_all_the_zsh_plugin_mangers_i_used/

[[ ! -f ~/.zinit/bin/zinit.zsh ]] && {
    command mkdir -p ~/.zinit
    command git clone https://github.com/zdharma-continuum/zinit.git ~/.zinit/bin
}
source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit


# -- Local plugins ----------------------------------------
for DOTFILES_ZSH_FUNCTION_FILE in "$HOME/.functions/"*.(sh|zsh)(N); do
  source "$DOTFILES_ZSH_FUNCTION_FILE"
done
unset DOTFILES_ZSH_FUNCTION_FILE

# -- Plugins via zinit ----------------------------------------
# Helpful plugin list: https://github.com/zdharma/Zsh-100-Commits-Club

# Completion functions must be on fpath before the single compinit call below.
zinit ice light-mode atpull'zinit creinstall -q .'
zinit light zsh-users/zsh-completions
fpath+=( "${ZINIT[PLUGINS_DIR]}/zsh-users---zsh-completions/src" )

zinit wait lucid light-mode for \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  zsh-users/zsh-syntax-highlighting

autoload -Uz compinit
ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
if [[ -n $ZSH_COMPDUMP(#qN.mh-24) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
  zcompile "$ZSH_COMPDUMP"
fi
compdef _zinit zinit


# -- Programs ----------------------------------------

# https://zdharma-continuum.github.io/zinit/wiki/Direnv-explanation/
# https://github.com/direnv/direnv/issues/68
zinit from"gh-r" as"program" mv"direnv* -> direnv" \
  atclone'chmod u+x ./direnv && ./direnv hook zsh > zhook.zsh' atpull'%atclone' \
  pick"direnv" src="zhook.zsh" for \
    direnv/direnv


# Emacs
if [ -x "$(command -v emacs)" ]; then
  zinit ice as"program" atclone'./bin/doom install --env --fonts' pick"./bin/*"
  zinit light doomemacs/doomemacs
fi

zinit ice as"command" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" \
    atload'[[ -x ./atuin ]] && eval "$(./atuin init zsh)"'

zinit light atuinsh/atuin

zinit as="command" lucid from="gh-r" for \
    id-as="usage" \
    atpull="%atclone" \
    jdx/usage

mise_release_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
  esac
}

mise_release_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo x64 ;;
    arm64|aarch64) echo arm64 ;;
  esac
}

zinit as="command" lucid from="gh-r" for \
    id-as="mise" \
    bpick"mise-v*-$(mise_release_os)-$(mise_release_arch).tar.gz" \
    pick"mise" \
    atclone='[[ -x ./mise/bin/mise ]] && command mv -f ./mise/bin/mise ./mise-bin && command rm -rf ./mise && command mv -f ./mise-bin ./mise; chmod +x ./mise && ./mise completion zsh > _mise' \
    atpull="%atclone" \
    jdx/mise
unset -f mise_release_os mise_release_arch

eval "$(mise activate zsh)"

if [[ "$OSTYPE" == linux* ]]; then
  eza_release_target() {
    case "$(uname -m)" in
      x86_64|amd64) echo x86_64-unknown-linux-gnu ;;
      arm64|aarch64) echo aarch64-unknown-linux-gnu ;;
      armv7l|armv7) echo arm-unknown-linux-gnueabihf ;;
    esac
  }

  EZA_RELEASE_TARGET="$(eza_release_target)"
  if [[ -n "$EZA_RELEASE_TARGET" ]]; then
    zinit ice as"program" from"gh-r" \
      bpick"eza_$EZA_RELEASE_TARGET.tar.gz" pick"eza"
    zinit light eza-community/eza
  fi
  unset EZA_RELEASE_TARGET
  unset -f eza_release_target
fi

if (( ${+commands[eza]} )); then
  alias ls='eza --group-directories-first'
elif [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi


if (( ${+commands[fzf]} )) && [[ -t 0 && -t 1 ]]; then
  # Atuin owns Ctrl-R; use fzf's Ctrl-T, Alt-C, and fuzzy completion only.
  FZF_CTRL_R_COMMAND='' source <(fzf --zsh)
fi

# -- Prompt

# For multiple prompts, do: https://zdharma-continuum.github.io/zinit/wiki/Multiple-prompts/

function load_prompt {
  prompt_hostname() {
    ansi 008 "[${HOST%.local}]"
  }

  prompt_virtualenv() {
    local venv
    venv=$(geometry_virtualenv)
    if [[ -n "$venv" ]]; then
      echo -n "($venv)"
    fi
  }

  GEOMETRY_PATH_COLOR=04
  GEOMETRY_HOST_COLORS=({1..9})
  (( ${terminfo[colors]:-0} >= 256 )) && GEOMETRY_HOST_COLORS+=({17..230})
  GEOMETRY_STATUS_COLOR="$(geometry::hostcolor)"

  # Herdr panes can retain SSH variables from when a persistent session was created.
  # They do not describe the client currently attached to that session.
  if [[ -z "$HERDR_ENV" && ( -n "$SSH_CLIENT" || -n "$SSH_TTY" ) ]]; then
    GEOMETRY_PROMPT=(geometry_echo prompt_hostname prompt_virtualenv geometry_status geometry_path)
  else
    GEOMETRY_PROMPT=(geometry_echo prompt_virtualenv geometry_status geometry_path)
  fi
}

zinit ice silent atload"load_prompt"
# https://github.com/geometry-zsh/geometry/blob/a8033e0e9a987c1a6ee1813b7cad7f28cfd3c869/options.md
zinit load geometry-zsh/geometry


# -- Autocompletion

# Alt+l file completion
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

# if command -v task >/dev/null 2>&1; then
#   autoload -Uz compdef
#   eval "$(task --completion zsh)"
# fi

# -- Local configs

case "$OSTYPE" in
  darwin*) DOTFILES_ZSH_PLATFORM_CONFIG="$HOME/.zshrc.darwin" ;;
  linux*) DOTFILES_ZSH_PLATFORM_CONFIG="$HOME/.zshrc.linux" ;;
  *) DOTFILES_ZSH_PLATFORM_CONFIG="" ;;
esac

for DOTFILES_ZSH_CONFIG in "$DOTFILES_ZSH_PLATFORM_CONFIG" "$HOME/.zshrc.x11" "$HOME/.zshrc.local"; do
  if [[ -n "$DOTFILES_ZSH_CONFIG" ]] && [[ -f "$DOTFILES_ZSH_CONFIG" ]]; then
    source "$DOTFILES_ZSH_CONFIG"
  fi
done

unset DOTFILES_ZSH_CONFIG DOTFILES_ZSH_PLATFORM_CONFIG
