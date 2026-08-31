INSTALL := ./install
ALL_GROUPS := base,darwin,x11,thinkpad,i3,ai

.DEFAULT_GOAL := help
.PHONY: help install update up update-zinit update-mise update-herdr update-brew update-gh update-nvim update-vim update-doom update-tmux update-mas update-dotbot update_dotbot uninstall base server darwin mac thinkpad i3 ai

help:
	@printf '%s\n' \
		'Targets:' \
		'  make base       install base dotfiles' \
		'  make server     install server-safe base dotfiles' \
		'  make darwin     install base + darwin dotfiles' \
		'  make thinkpad   install base + x11 + thinkpad dotfiles' \
		'  make i3         install i3 dotfiles' \
		'  make ai         install AI tool dotfiles' \
		'  make update        update user-managed dependencies' \
		'  make update-zinit  update Zinit and Zinit-managed plugins' \
		'  make update-mise   update tools installed by mise' \
		'  make update-herdr update GitHub-installed Herdr plugins' \
		'  make update-brew   update Homebrew formulae and casks' \
		'  make update-gh     update GitHub CLI extensions' \
		'  make update-nvim   update Neovim plugins and lazy-lock.json' \
		'  make update-vim    update Vim plugins through vim-plug' \
		'  make update-doom   update Doom Emacs' \
		'  make update-tmux   update installed tmux plugins' \
		'  make update-mas    update Mac App Store applications' \
		'  make update-dotbot update the pinned Dotbot revision' \
		'  make uninstall     uninstall all linked groups'

install:
	@$(INSTALL) $(ARGS)

up: update

update:
	@$(MAKE) --no-print-directory update-zinit
	@$(MAKE) --no-print-directory update-mise
	@$(MAKE) --no-print-directory update-herdr
	@$(MAKE) --no-print-directory update-gh
	@$(MAKE) --no-print-directory update-nvim
	@$(MAKE) --no-print-directory update-vim
	@$(MAKE) --no-print-directory update-doom
	@$(MAKE) --no-print-directory update-tmux
	@$(MAKE) --no-print-directory update-dotbot

update-zinit:
	@if command -v zsh >/dev/null 2>&1; then \
		zsh -ic 'if ! command -v zinit >/dev/null 2>&1; then print -r -- "Skipping Zinit update: Zinit is not installed"; exit 0; fi; zinit self-update || exit; for plugin_dir in "$$ZINIT[PLUGINS_DIR]"/*(N/); do plugin=$${plugin_dir:t}; [[ $$plugin = custom || $$plugin = _local---zinit ]] && continue; zinit update "$${plugin//---//}" || exit; done'; \
	else \
		printf '%s\n' 'Skipping Zinit update: zsh is not installed'; \
	fi

update-mise:
	@if command -v mise >/dev/null 2>&1; then \
		mise up --yes; \
	else \
		printf '%s\n' 'Skipping mise update: mise is not installed'; \
	fi

update-herdr:
	@if ! command -v herdr >/dev/null 2>&1; then \
		printf '%s\n' 'Skipping Herdr plugin update: herdr is not installed'; \
	elif ! command -v jq >/dev/null 2>&1; then \
		printf '%s\n' 'Skipping Herdr plugin update: jq is not installed'; \
	else \
		sources=$$(herdr plugin list --json | jq -r '.result.plugins[].source | select(.kind == "github") | .owner + "/" + .repo + (if (.subdir // "") == "" then "" else "/" + .subdir end)'); \
		if [ -z "$$sources" ]; then \
			printf '%s\n' 'Skipping Herdr plugin update: no GitHub plugins installed'; \
		else \
			printf '%s\n' "$$sources" | while IFS= read -r source; do \
				if [ "$$source" = dkarter/hwt/plugins/herdr ] && command -v hwt >/dev/null 2>&1; then \
					hwt plugin update || exit; \
				else \
					herdr plugin install "$$source" --yes || exit; \
				fi; \
			done; \
		fi; \
	fi

update-brew:
	@if command -v brew >/dev/null 2>&1; then \
		brew update && brew upgrade; \
	else \
		printf '%s\n' 'Skipping Homebrew update: brew is not installed'; \
	fi

update-gh:
	@if command -v gh >/dev/null 2>&1; then \
		gh extension upgrade --all; \
	else \
		printf '%s\n' 'Skipping GitHub CLI extension update: gh is not installed'; \
	fi

update-nvim:
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless '+Lazy! update' +qa; \
	else \
		printf '%s\n' 'Skipping Neovim update: nvim is not installed'; \
	fi

update-vim:
	@if ! command -v vim >/dev/null 2>&1; then \
		printf '%s\n' 'Skipping Vim plugin update: vim is not installed'; \
	elif [ ! -r "$$HOME/.vimrc" ] || [ ! -r "$$HOME/.vimrc.bundles" ] || [ ! -r "$$HOME/.vim/autoload/plug.vim" ]; then \
		printf '%s\n' 'Skipping Vim plugin update: vim-plug is not installed'; \
	else \
		vim -Nu "$$HOME/.vimrc" -n -es +'PlugUpgrade' +'PlugUpdate --sync' +qa; \
	fi

update-doom:
	@if command -v doom >/dev/null 2>&1; then \
		doom upgrade; \
	else \
		printf '%s\n' 'Skipping Doom update: Doom Emacs is not installed'; \
	fi

update-tmux:
	@if [ -x "$$HOME/.tmux/plugins/tpm/bin/update_plugins" ]; then \
		"$$HOME/.tmux/plugins/tpm/bin/update_plugins" all; \
	else \
		printf '%s\n' 'Skipping tmux plugin update: TPM is not installed'; \
	fi

update-mas:
	@if command -v mas >/dev/null 2>&1; then \
		mas update; \
	else \
		printf '%s\n' 'Skipping Mac App Store update: mas is not installed'; \
	fi

update-dotbot:
	@if command -v git >/dev/null 2>&1; then \
		git submodule update --remote --init dotbot && \
			git -C dotbot submodule update --init --recursive; \
	else \
		printf '%s\n' 'Skipping Dotbot update: git is not installed'; \
	fi

update_dotbot: update-dotbot

uninstall: export DOTFILE_GROUPS = $(ALL_GROUPS)
uninstall:
	@./uninstall.py

base: export DOTFILE_GROUPS = base
base: install

server: base

darwin: export DOTFILE_GROUPS = base,darwin
darwin: install

mac: darwin

thinkpad: export DOTFILE_GROUPS = base,x11,thinkpad
thinkpad: install

i3: export DOTFILE_GROUPS = i3
i3: install

ai: export DOTFILE_GROUPS = ai
ai: install
