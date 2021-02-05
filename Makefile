.PHONY: setup base install desktop laptop vmguest

base/.env:
	@cp base/example.env base/.env
	@printf "\x1B[01;93m✔ .env file created\n\x1B[0m"

setup: base/.env
	@printf "\x1B[01;93m✔ Setup complete\n\x1B[0m"

base: setup
	@./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

install: base

desktop: setup
	@DOTFILE_GROUPS=desktop,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

laptop: setup
	@DOTFILE_GROUPS=laptop,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

vmguest: setup
	@DOTFILE_GROUPS=vmguest,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"
