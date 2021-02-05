.PHONY: setup desktop laptop vmguest

base/.env:
	@cp base/example.env base/.env
	@printf "\x1B[01;93m✔ .env file created\n\x1B[0m"

setup: base/.env
	@printf "\x1B[01;93m✔ Setup complete\n\x1B[0m"

desktop:
	@DOTFILE_GROUPS=desktop,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

laptop:
	@DOTFILE_GROUPS=laptop,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"

vmguest:
	@DOTFILE_GROUPS=vmguest,x11,archlinux; ./install
	@printf "\x1B[01;93m✔ Install complete\n\x1B[0m"
