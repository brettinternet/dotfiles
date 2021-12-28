.PHONY: update_dotbot setup install base desktop laptop vmguest vmguest-arch mac lint

# ISSUES:
# - https://github.com/anishathalye/dotbot/issues/282
update_dotbot:
	@git submodule update --remote dotbot
	@printf "\x1B[01;93m✔ submodules updated\n\x1B[0m"

base/.env:
	@cp base/example.env base/.env
	@printf "\x1B[01;93m✔ .env file created\n\x1B[0m"

setup: base/.env
	@printf "\x1B[01;93m✔ Setup complete\n\x1B[0m"

install: setup
	@./install $(ARGS)
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

base: install

desktop: export DOTFILE_GROUPS = x11,desktop,archlinux
desktop: install

laptop: export DOTFILE_GROUPS = x11,laptop,archlinux
laptop: install

server: export DOTFILE_GROUPS = archlinux
server: install

vmguest: export DOTFILE_GROUPS = vmguest
vmguest: install

vmguest-arch: export DOTFILE_GROUPS = x11,vmguest,archlinux
vmguest-arch: install

mac: export DOTFILE_GROUPS = mac
mac: install

# https://github.com/koalaman/shellcheck/wiki/Recursiveness
lint:
	@yamllint .
	@find -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.ksh' -o -name '*.bashrc' -o -name '*.bash_profile' -o -name '*.bash_login' -o -name '*.bash_logout' \) -not -path "./dotbot/*" | xargs shellcheck
