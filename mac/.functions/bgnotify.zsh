#!/usr/bin/env zsh

# Forked from https://github.com/t413/zsh-background-notify
# Adapted for mac only

## setup ##

[[ -o interactive ]] || return #interactive only!
zmodload zsh/datetime || { print "can't load zsh/datetime"; return } # faster than date()
autoload -Uz add-zsh-hook || { print "can't add zsh hook!"; return }

(( ${+bgnotify_threshold} )) || bgnotify_threshold=5 #default 10 seconds


## definitions ##

if ! (type bgnotify_formatted | grep -q 'function'); then ## allow custom function override
  function bgnotify_formatted { ## args: (exit_status, command, elapsed_seconds)
    elapsed="$(( $3 % 60 ))s"
    (( $3 >= 60 )) && elapsed="$((( $3 % 3600) / 60 ))m $elapsed"
    (( $3 >= 3600 )) && elapsed="$(( $3 / 3600 ))h $elapsed"
    [ $1 -eq 0 ] && bgnotify "#win (took $elapsed)" "$2" || bgnotify "#fail (took $elapsed)" "$2"
  }
fi

currentWindowId () {
  osascript -e 'tell application (path to frontmost application as text) to id of front window' 2&> /dev/null || echo "0"
}

bgnotify () { ## args: (title, subtitle)
  [[ "$TERM_PROGRAM" == 'iTerm.app' ]] && term_id='com.googlecode.iterm2';
  [[ "$TERM_PROGRAM" == 'Apple_Terminal' ]] && term_id='com.apple.terminal';
  ## now call terminal-notifier, (hopefully with $term_id!)
  [ -z "$term_id" ] && terminal-notifier -message "$2" -title "$1" >/dev/null ||
  terminal-notifier -message "$2" -title "$1" -activate "$term_id" -sender "$term_id" >/dev/null
}


## Zsh hooks ##

bgnotify_begin() {
  bgnotify_timestamp=$EPOCHSECONDS
  bgnotify_lastcmd="$1"
  bgnotify_windowid=$(currentWindowId)
}

bgnotify_end() {
  didexit=$?
  elapsed=$(( EPOCHSECONDS - bgnotify_timestamp ))
  past_threshold=$(( elapsed >= bgnotify_threshold ))
  if (( bgnotify_timestamp > 0 )) && (( past_threshold )); then
    if [ $(currentWindowId) != "$bgnotify_windowid" ]; then
      print -n "\a"
      bgnotify_formatted "$didexit" "$bgnotify_lastcmd" "$elapsed"
    fi
  fi
  bgnotify_timestamp=0 #reset it to 0!
}

## only enable if a local (non-ssh) connection
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
  add-zsh-hook preexec bgnotify_begin
  add-zsh-hook precmd bgnotify_end
fi
