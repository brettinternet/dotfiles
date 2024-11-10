# ISSUES:
# - https://github.com/anishathalye/dotbot/issues/282

.PHONY: update_dotbot setup install uninstall base thinkpad vmguest darwin lint

install:
	@./install $(ARGS)

update_dotbot:
	@git submodule update --remote dotbot

uninstall: export DOTFILE_GROUPS = archlinux,base,thinkpad,darwin,vmguest,x11
uninstall:
	@./uninstall.py

base: install

thinkpad: export DOTFILE_GROUPS = base,x11,thinkpad,archlinux
thinkpad: install

server: export DOTFILE_GROUPS = base,archlinux
server: install

vmguest: export DOTFILE_GROUPS = base,vmguest
vmguest: install

vmguest-arch: export DOTFILE_GROUPS = base,x11,vmguest,archlinux
vmguest-arch: install

darwin: export DOTFILE_GROUPS = base,darwin
darwin: install

mac: darwin

i3: export DOTFILE_GROUPS = i3
i3: install

# https://github.com/koalaman/shellcheck/wiki/Recursiveness
lint:
	@yamllint .
	@find . -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.ksh' -o -name '*.bashrc' -o -name '*.bash_profile' -o -name '*.bash_login' -o -name '*.bash_logout' \) -not -path "./dotbot/*" | xargs shellcheck
