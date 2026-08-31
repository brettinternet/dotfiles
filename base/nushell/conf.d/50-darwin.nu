if $nu.os-info.name == "macos" {
    $env.DEV_DIR = ($env.HOME | path join "dev")
    $env.PERSONAL_DIR = ($env.MY_PROJECTS? | default ($env.DEV_DIR | path join "me"))
}

alias c = code .
def --env dev [] { cd $env.DEV_DIR }
def --env me [] { cd $env.PERSONAL_DIR }
def --env sandbox [] { cd ($env.DEV_DIR | path join "sandbox") }
def --env work [] { cd ($env.DEV_DIR | path join "work") }
def --env ai [] { cd ($env.PERSONAL_DIR | path join "ai") }
def --wrapped claude [...rest] { ^claude --ide ...$rest }

def flush_dns [] {
    ^sudo dscacheutil -flushcache
    ^sudo killall -HUP mDNSResponder
}

alias vim = nvim

def mix_test [file_match?: string] {
    if $file_match == null {
        print "No file match provided, running all tests."
        ^mix test
        return
    }

    let named_files = (
        ^find lib test -type f -iname $"*($file_match)*_test.exs"
        | lines
    )
    let all_test_files = (
        glob "lib/**/*_test.exs"
        | append (glob "test/**/*_test.exs")
    )
    let matching_lines = (
        if ($all_test_files | is-empty) {
            []
        } else {
            ^rg $"(test\\s|describe\\s).*($file_match)" ...$all_test_files --vimgrep -s
            | lines
        }
    )
    let named_file_lines = (
        $named_files
        | each {|file| ^rg 'test\s' --vimgrep -s $file | lines }
        | flatten
    )
    let locations = (
        $named_file_lines
        | append $matching_lines
        | parse --regex '^(?<file>.*?):(?<line>\d+):'
        | each {|match| $"($match.file):($match.line)" }
        | uniq
    )

    ^mix test ...$locations
}

def mix_test_watch [] {
    ^fswatch lib test | ^mix test --listen-on-stdin --stale
}

def wt-list [] {
    ^git worktree list
    | lines
    | skip 1
    | each {|line|
        $line
        | parse --regex '\[(?<branch>[^\]]+)\]$'
        | get branch.0?
    }
    | compact
}

def wt-root [] {
    ^git worktree list --porcelain
    | lines
    | first
    | str replace "worktree " ""
}

def wt-current-branch [] {
    ^git branch --show-current | str trim
}

def wt-default-branch [root: string] {
    let result = (^git -C $root symbolic-ref --short refs/remotes/origin/HEAD | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim | str replace "origin/" ""
    } else {
        "main"
    }
}

def wt-new [branch: string] {
    ^git worktree add -b $branch $".trees/($branch)" main
    ^open -a ($env.TERM_PROGRAM? | default "Ghostty") ($env.PWD | path join ".trees" $branch)
}

def --env wt-delete [branch?: string] {
    let selected = ($branch | default (wt-current-branch))
    let root = (wt-root)

    ^git -C $root worktree remove $".trees/($selected)" --force
    ^git -C $root branch -d $selected
    cd $root
}

def --env wt-clean [branch?: string, --force(-f)] {
    let selected = ($branch | default (wt-current-branch))
    let root = (wt-root)
    let tree = ($root | path join ".trees" $selected)

    if not $force {
        let unstaged = (^git -C $tree diff --quiet | complete)
        let staged = (^git -C $tree diff --cached --quiet | complete)
        if $unstaged.exit_code != 0 or $staged.exit_code != 0 {
            error make {msg: $"wt-clean: '($selected)' has uncommitted changes. Use -f to force."}
        }

        let upstream = (^git -C $tree rev-parse --abbrev-ref '@{upstream}' | complete)
        if $upstream.exit_code != 0 or ($upstream.stdout | str trim | is-empty) {
            error make {msg: $"wt-clean: '($selected)' has no remote tracking branch. Use -f to force."}
        }

        let unpushed = (^git -C $tree log $"($upstream.stdout | str trim)..HEAD" | complete)
        if $unpushed.exit_code == 0 and not ($unpushed.stdout | str trim | is-empty) {
            error make {msg: $"wt-clean: '($selected)' has unpushed commits. Use -f to force."}
        }
    }

    ^git -C $root worktree remove $tree --force
    let deleted = (^git -C $root branch -d $selected | complete)
    if $deleted.exit_code != 0 {
        ^git -C $root branch -D $selected
    }
    cd $root
}

def wt-switch [branch?: string] {
    let root = (wt-root)
    let default = (wt-default-branch $root)
    let selected = if $branch == null {
        if not (which fzf | is-empty) {
            wt-list | str join (char nl) | ^fzf --prompt="worktree> " | str trim
        } else {
            print --stderr "Usage: wt-switch <branch>"
            ^git worktree list
            return
        }
    } else {
        $branch
    }

    if $selected == $default {
        ^open -a ($env.TERM_PROGRAM? | default "Ghostty") $root
        return
    }

    let tree = ($root | path join ".trees" $selected)
    if not ($tree | path exists) {
        error make {msg: $"wt-switch: no worktree for '($selected)'. Use wt-new to create one."}
    }

    ^open -a ($env.TERM_PROGRAM? | default "Ghostty") $tree
}
