def work_in_progress [] {
    let result = (^git log -n 1 | complete)
    if $result.exit_code == 0 and ($result.stdout | str contains "--wip--") {
        print "WIP!!"
    }
}

def gwip [] {
    ^git add -A
    let deleted = (^git ls-files --deleted | lines)
    if not ($deleted | is-empty) {
        ^git rm ...$deleted
    }
    ^git commit --no-verify --no-gpg-sign -m "--wip-- [skipci]"
}

def gunwip [] {
    let result = (^git log -n 1 | complete)
    if $result.exit_code == 0 and ($result.stdout | str contains "--wip--") {
        ^git reset HEAD~1
    }
}

def git_pickaxe [search: string] {
    ^git log -S $search --patch --reverse
}

def git_current_branch [] {
    let symbolic = (^git symbolic-ref --quiet HEAD | complete)
    if $symbolic.exit_code == 0 {
        $symbolic.stdout | str trim | str replace "refs/heads/" ""
    } else if $symbolic.exit_code != 128 {
        let revision = (^git rev-parse --short HEAD | complete)
        if $revision.exit_code == 0 {
            $revision.stdout | str trim
        }
    }
}

def gloc [filter?: string] {
    let extra = if $filter == null { [] } else { [$filter] }
    let files = (^git ls-files -- ':!:*lock.json' ...$extra | lines)
    $files
    | each {|file| open --raw $file | lines | length }
    | math sum
}

def guc [] { ^git pull origin (git_current_branch) }
def gpc [] { ^git push origin (git_current_branch) }
def gpcf [] { ^git push --force-with-lease --no-verify origin (git_current_branch) }
def gbsuc [] { ^git branch --set-upstream-to=$"origin/(git_current_branch)" }
def gpsuc [] { ^git push --set-upstream origin (git_current_branch) }

alias grbo = git rebase

def grbos [branch: string = "main"] {
    ^git rebase --exec "git commit --amend --no-edit -n -S" -i $"origin/($branch)"
}

def g_sign [email: string, key_id: string] {
    let key = (^gpg -k $key_id | complete)
    if $key.exit_code != 0 {
        error make {msg: "Unable to find GPG key by that ID"}
    }

    let matching_email = (^gpg -k $email | complete)
    if $matching_email.exit_code != 0 {
        error make {msg: "That email does not match a local GPG key"}
    }

    ^git config user.signingkey $key_id
    ^git config commit.gpgsign true
    ^git config tag.gpgsign true
    ^git config user.email $email
}

alias g = git
alias gb = git branch
alias gs = git status
alias gss = git status -s
alias gst = git stash
alias gsp = git stash pop
alias gsa = git stash apply
alias gsh = git show
alias gi = vim .gitignore
alias ga = git add
alias gaa = git add -A
alias gcm = git commit -m
alias gscm = git commit -S -m
alias grv = git remote -v
alias grr = git remote rm
alias gra = git remote add
alias glog = git l
alias gf = git fetch
alias gd = git diff
alias gp = git push
alias gu = git pull
alias guom = git pull origin main
alias gpom = git push origin main
alias gwch = git whatchanged -p --abbrev-commit --pretty=medium

alias gwtl = git worktree list
alias gwtr = git worktree remove
alias gwtp = git worktree prune
alias gwt = gwta

def --env gwta [worktree_name: string, branch_name?: string] {
    let branch = ($branch_name | default $worktree_name)
    let root = (^git rev-parse --show-toplevel | str trim)
    let repository = ($root | path basename)
    let worktree_path = ($root | path dirname | path join $"($repository)-($worktree_name)")

    ^git worktree add -b $branch $worktree_path
    cd $worktree_path
}
