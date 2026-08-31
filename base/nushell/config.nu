$env.config.buffer_editor = "context-editor"
$env.config.edit_mode = "emacs"
$env.config.show_banner = false
$env.config.history = {
    max_size: 50_000
    sync_on_enter: true
    file_format: sqlite
    isolation: false
}
$env.config.completions = {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: fuzzy
    external: {
        enable: true
        max_results: 100
        completer: null
    }
    use_ls_colors: true
}

$env.config.keybindings ++= [
    {
        name: insert_newline
        modifier: control
        keycode: char_j
        mode: [emacs]
        event: { edit: insertnewline }
    }
    {
        name: edit_command_line
        modifier: control
        keycode: char_g
        mode: [emacs]
        event: { send: openeditor }
    }
    {
        name: context_scrollback
        modifier: alt_shift
        keycode: char_s
        mode: [emacs]
        event: {
            send: executehostcommand
            cmd: "context-scrollback"
        }
    }
    {
        name: file_completion
        modifier: alt
        keycode: char_l
        mode: [emacs]
        event: {
            send: menu
            name: completion_menu
        }
    }
]

let prompt_hostname = (sys host | get hostname | str replace --regex '\.local$' '')
let show_prompt_hostname = (
    $env.HERDR_ENV? == null
    and ($env.SSH_CLIENT? != null or $env.SSH_TTY? != null)
)

load-env {
    PROMPT_COMMAND: {||
        let virtualenv = if $env.VIRTUAL_ENV? != null {
            $"(ansi green)\(($env.VIRTUAL_ENV | path basename)\)(ansi reset) "
        } else {
            ""
        }
        let hostname = if $show_prompt_hostname {
            $"(ansi dark_gray)[($prompt_hostname)](ansi reset) "
        } else {
            ""
        }
        let jobs = try {
            let count = (job list | length)
            if $count > 0 {
                $"(ansi blue)⚙ ($count)(ansi reset) "
            } else {
                ""
            }
        } catch {
            ""
        }
        let status_color = if ($env.LAST_EXIT_CODE? | default 0) == 0 {
            "green"
        } else {
            "red"
        }
        let path = ($env.PWD | str replace $env.HOME "~")

        $"($hostname)($virtualenv)($jobs)(ansi $status_color)($path)(ansi reset)"
    }
}
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = $"(ansi dark_gray) > (ansi reset)"
$env.PROMPT_MULTILINE_INDICATOR = $"(ansi dark_gray) ::: (ansi reset)"

source ($nu.default-config-dir | path join "conf.d/10-environment.nu")
source ($nu.default-config-dir | path join "conf.d/20-aliases.nu")
source ($nu.default-config-dir | path join "conf.d/30-git.nu")
source ($nu.default-config-dir | path join "conf.d/40-integrations.nu")
source ($nu.default-config-dir | path join "conf.d/50-darwin.nu")
