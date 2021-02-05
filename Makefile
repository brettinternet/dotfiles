.PHONY: setup install base desktop laptop vmguest vmguest-arch

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

vmguest: export DOTFILE_GROUPS = vmguest
vmguest: install

vmguest-arch: export DOTFILE_GROUPS = x11,vmguest,archlinux
vmguest-arch: install
