#!/bin/bash

alias vim='nvim'

# Thank you Cody
# https://github.com/cfbender/dotfiles/blob/1650ace463e7716c1a834fbf991a29ade7c1d9d4/.zshrc#L191-L204
function mix_test() {
  file_match="$1"
  if [ -z "$file_match" ]; then
    echo "No file match provided, running all tests."
    mix test
  else
    cat -p \
    <(find lib test -type f -iname "*$1*_test.exs" -exec rg "test\s" --vimgrep -s {} \; | cut -d':' -f1,2) \
    <(rg "(test\s|describe\s).*$1" lib/**/*_test.exs test/**/*_test.exs --vimgrep -s | cut -d':' -f1,2) \
    | xargs mix test
  fi
}

function mix_test_watch() {
  fswatch lib test | mix test --listen-on-stdin --stale
}
