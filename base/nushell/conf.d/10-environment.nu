use std/util "path add"

$env.SHELL = $nu.current-exe

path add ($env.HOME | path join ".bin")
path add "/opt/bin"
path add ($env.HOME | path join ".npm-global/bin")
path add ($env.HOME | path join ".local/bin")
path add ($env.HOME | path join ".local/share/mise/shims")
path add ($env.HOME | path join ".go/bin")
path add ($env.HOME | path join ".cargo/bin")
path add ($env.HOME | path join ".config/emacs/bin")
path add ($env.HOME | path join ".bun/bin")

$env.GOPATH = ($env.HOME | path join ".go")

let context_editor = ($env.HOME | path join ".bin/context-editor")
$env.VISUAL = if ($context_editor | path exists) {
    $context_editor
} else {
    "vim"
}
$env.EDITOR = $env.VISUAL
$env.SYSTEMD_EDITOR = $env.EDITOR
$env.config.buffer_editor = $env.VISUAL

if $env.DISPLAY? == null {
    $env.BROWSER = "w3m"
}

let dircolors = ($env.HOME | path join ".dircolors")
if ($dircolors | path exists) and not (which dircolors | is-empty) {
    let result = (^dircolors --sh $dircolors | complete)
    if $result.exit_code == 0 {
        let colors = (
            $result.stdout
            | parse --regex "LS_COLORS='(?<colors>[^']*)'"
            | get colors.0?
        )
        if $colors != null {
            $env.LS_COLORS = $"($colors):ow=01;31:tw=01;33"
        }
    }
} else if not (which eza | is-empty) {
    $env.LS_COLORS = $"($env.LS_COLORS? | default ''):ow=01;31:tw=01;33"
} else if $nu.os-info.name == "macos" {
    $env.LSCOLORS = "exfxcxdxbxegedabagxxxx"
}

if $nu.os-info.name == "macos" {
    let homebrew_prefix = if ("/opt/homebrew/bin/brew" | path exists) {
        "/opt/homebrew"
    } else if ("/usr/local/bin/brew" | path exists) {
        "/usr/local"
    } else {
        null
    }
    if $homebrew_prefix != null {
        $env.HOMEBREW_PREFIX = $homebrew_prefix
        $env.HOMEBREW_CELLAR = ($homebrew_prefix | path join "Cellar")
        $env.HOMEBREW_REPOSITORY = if $homebrew_prefix == "/usr/local" {
            "/usr/local/Homebrew"
        } else {
            $homebrew_prefix
        }
        $env.MANPATH = $"($homebrew_prefix)/share/man:($env.MANPATH? | default '')"
        $env.INFOPATH = $"($homebrew_prefix)/share/info:($env.INFOPATH? | default '')"
        path add ($homebrew_prefix | path join "bin")
        path add ($homebrew_prefix | path join "sbin")
    }

    if ("/Applications/Ghostty.app" | path exists) {
        path add "/Applications/Ghostty.app/Contents/MacOS"
    }

    if ("/opt/google-cloud-sdk/bin" | path exists) {
        path add "/opt/google-cloud-sdk/bin"
    }
}

try { ulimit -n 4096 }
