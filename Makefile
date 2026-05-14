INSTALL := ./install
ALL_GROUPS := base,darwin,x11,thinkpad,i3,ai

.DEFAULT_GOAL := help
.PHONY: help install update-dotbot update_dotbot uninstall base server darwin mac thinkpad i3 ai

help:
	@printf '%s\n' \
		'Targets:' \
		'  make base       install base dotfiles' \
		'  make server     install server-safe base dotfiles' \
		'  make darwin     install base + darwin dotfiles' \
		'  make thinkpad   install base + x11 + thinkpad dotfiles' \
		'  make i3         install i3 dotfiles' \
		'  make ai         install AI tool dotfiles' \
		'  make uninstall  uninstall all linked groups'

install:
	@$(INSTALL) $(ARGS)

update-dotbot:
	@git submodule update --remote --init --recursive dotbot

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
