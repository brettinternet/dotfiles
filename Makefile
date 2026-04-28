# ISSUES:
# - https://github.com/anishathalye/dotbot/issues/282

.PHONY: update_dotbot setup install uninstall base thinkpad darwin lint ai

install:
	@./install $(ARGS)

update_dotbot:
	@git submodule update --remote dotbot

uninstall: export DOTFILE_GROUPS = archlinux,base,thinkpad,darwin,x11,ai
uninstall:
	@./uninstall.py

base: install

darwin: export DOTFILE_GROUPS = base,darwin
darwin: install

mac: darwin

thinkpad: export DOTFILE_GROUPS = base,x11,thinkpad
thinkpad: install

archlinux: export DOTFILE_GROUPS = base,archlinux
archlinux: install

i3: export DOTFILE_GROUPS = i3
i3: install

ai: export DOTFILE_GROUPS = ai
ai: install
