" To use defaults instead
"unlet! skip_defaults_vim
"source $VIMRUNTIME/defaults.vim

filetype plugin on
syntax on

" Only source plugin declarations when vim-plug is actually installed, otherwise
" every launch dies in E117/E492 errors. Bootstrap with:
"   curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
"     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
" then run :PlugInstall
let s:has_plugins = filereadable(expand("~/.vim/autoload/plug.vim")) && filereadable(expand("~/.vimrc.bundles"))

if s:has_plugins
    source ~/.vimrc.bundles
endif

" -- General ----------------------------------------

set encoding=utf-8
set autoindent
set autoread                                " reload files when changed on disk, i.e. via `git checkout`
set backspace=2                             " Fix broken backspace in some setups
set backupcopy=yes                          " see :help crontab
if has('clipboard')
    " yank and paste with the system clipboard
    set clipboard=unnamedplus
endif
set directory-=.                            " don't store swapfiles in the current directory
set laststatus=2                            " always show statusline
set list                                    " show trailing whitespace
set listchars=tab:▸\ ,trail:▫
set number                                  " show line numbers
set ruler                                   " show where you are
set scrolloff=3                             " show context above/below cursorline
set showcmd
set tabstop=8                               " actual tabs occupy 8 characters
set wildignore=log/**,node_modules/**,target/**,tmp/**,*.rbc
set wildmenu                                " show a navigable menu for tab completion
set wildmode=longest,list,full
"set nocursorline                            " don't highlight current line
set expandtab                               " expand tabs to spaces - https://vim.fandom.com/wiki/Indenting_source_code
set shiftwidth=4                            " normal mode indentation commands use 2 spaces
set softtabstop=4                           " insert mode tab and backspace use 2 spaces
set ignorecase                              " case-insensitive search
set smartcase                               " case-sensitive search if any caps
set incsearch                               " search as you type
set wrapscan
set hlsearch

" Enable basic mouse behavior such as resizing buffers.
" Vim 9 auto-detects the right ttymouse (sgr) inside tmux; forcing xterm2 here
" only breaks mouse reporting past column 223.
set mouse=a
"nmap <leader>hl :let @/ = ""<CR>


" -- Shortcuts ----------------------------------------

" mapleader must be set before any <leader> mapping is defined.
let mapleader = ','

inoremap jj <ESC>
noremap <C-h> <C-w>h
noremap <C-j> <C-w>j
noremap <C-k> <C-w>k
noremap <C-l> <C-w>l
noremap <silent> <leader>V :source ~/.vimrc<CR>:filetype detect<CR>:exe ":echo 'vimrc reloaded'"<CR>

" in case you forgot to sudo
cnoremap w!! %!sudo tee > /dev/null %

" Plugin mappings and settings; these commands do not exist without vim-plug.
if s:has_plugins
    nnoremap <leader>b :CtrlPBuffer<CR>
    nnoremap <leader>d :NERDTreeToggle<CR>
    nnoremap <leader>t :CtrlP<CR>
    nnoremap <leader>T :CtrlPClearCache<CR>:CtrlP<CR>
    nnoremap <leader>] :TagbarToggle<CR>
    nnoremap <leader>g :GitGutterToggle<CR>

    let g:ctrlp_match_window = 'order:ttb,max:20'
    let g:gitgutter_enabled = 0
endif


" -- Integrations ----------------------------------------

" Terminal fuzzy file open, no plugin required. Uses fzf (provisioned in base
" mise) and prefers fd for the file list, falling back to find.
" `fzy` was used here before but is installed on none of these machines.
"
" fzf is run through `silent !` with its selection redirected to a tempfile:
" it is a full-screen UI and needs the real terminal, which `system()` does
" not hand over (the picker never becomes visible).
function! s:FuzzyOpen(vim_command) abort
    if !executable('fzf')
        echohl WarningMsg | echo 'fzf not found' | echohl NONE
        return
    endif

    if executable('fd')
        let l:finder = 'fd --type f --hidden --exclude .git'
    else
        let l:finder = 'find . -type f -not -path "*/.git/*"'
    endif

    let l:tmp = tempname()

    try
        execute 'silent !' . l:finder . ' | fzf > ' . shellescape(l:tmp)
    finally
        redraw!
    endtry

    if filereadable(l:tmp)
        let l:lines = readfile(l:tmp)
        call delete(l:tmp)

        if !empty(l:lines) && !empty(trim(l:lines[0]))
            execute a:vim_command . ' ' . fnameescape(trim(l:lines[0]))
        endif
    endif
endfunction

nnoremap <silent> <leader>e :call <SID>FuzzyOpen(':e')<CR>
nnoremap <silent> <leader>v :call <SID>FuzzyOpen(':vs')<CR>
nnoremap <silent> <leader>s :call <SID>FuzzyOpen(':sp')<CR>

" -- Appearance ----------------------------------------

" Never `set term=...` here: it resets all terminal options (clobbering the
" cursor-shape and true-colour escapes set below) and lies to Vim about the
" real terminal. $TERM is the terminal's job.

" True-colour escapes must be defined *before* enabling termguicolors so Vim
" knows how to emit 24-bit colour outside xterm.
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"

if has('termguicolors')
    set termguicolors
endif
set background=dark

" Prefer a plugin colourscheme when plugins are present, else fall back to a
" scheme that ships with Vim 9. `onedark` here previously never loaded at all:
" navarasu/onedark.nvim is Lua-only and cannot run in Vim.
if s:has_plugins
    let g:gruvbox_material_background = 'medium'
    silent! colorscheme gruvbox-material
endif

if !exists('g:colors_name')
    silent! colorscheme retrobox
endif

" Cursor shape per mode (block in normal, bar in insert).
if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

" Inherit the terminal's background instead of painting our own.
hi Normal guibg=NONE ctermbg=NONE


" -- Functions ----------------------------------------

" Source: https://news.ycombinator.com/item?id=22280267
command! -nargs=* Date call s:RunDate()

function! s:RunDate()
  let s:tm = strftime("%a %d %b %Y") . "\n"
  execute "normal! i" . s:tm
  execute "startinsert"
endfunction

command! -nargs=* Timestamp call s:RunTimestamp()

function! s:RunTimestamp()
  " %c - https://vim.fandom.com/wiki/Insert_current_date_or_time
  let s:tm = strftime("%c")
  execute "normal! i" . s:tm
endfunction
