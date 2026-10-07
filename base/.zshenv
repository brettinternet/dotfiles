# zsh reads only this file for non-interactive commands such as `ssh host cmd`.
# Daemons started that way (an auto-started herdr server and its plugins)
# otherwise get sshd's bare PATH and macOS's system python3. Interactive shells
# still configure PATH in .profile/.zshrc; mise activate takes precedence there.
mise_shims="$HOME/.local/share/mise/shims"
if [[ -d "$mise_shims" && ":$PATH:" != *":$mise_shims:"* ]]; then
  export PATH="$mise_shims:$HOME/.local/bin:$PATH"
fi
unset mise_shims
