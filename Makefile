# Stow-based dotfiles: each top-level dir is a package mirroring $HOME.
# --no-folding forces real dirs + per-file symlinks (never a whole-dir symlink), so
# stowing ssh-linux/ or claude/ onto a host lacking ~/.ssh or ~/.claude can't point that
# dir at this repo and leak a later-written key/credential into it.
# ~/.ssh/config itself is deliberately not a package — see tools/canonical/.ssh/config.
COMMON_PACKAGES := zsh starship git tmux claude pi bat htop k9s helm ghostty btop cava fastfetch herdr herdr-watchr
LINUX_PACKAGES := hypr waybar walker ghostty-linux ssh-linux
DARWIN_PACKAGES := ghostty-darwin

ifeq ($(shell uname -s),Darwin)
PACKAGES := $(COMMON_PACKAGES) $(DARWIN_PACKAGES)
else
PACKAGES := $(COMMON_PACKAGES) $(LINUX_PACKAGES)
endif

STOW := stow --no-folding --verbose --target=$(HOME)

.PHONY: help install stow unstow restow adopt

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

install: stow ## Symlink all packages into $HOME (does NOT install software)

stow: ## Stow (symlink) all packages
	$(STOW) --restow $(PACKAGES)

unstow: ## Remove all symlinks
	$(STOW) --delete $(PACKAGES)

restow: ## Re-link all packages (after adding/renaming files)
	$(STOW) --restow $(PACKAGES)

adopt: ## One-time takeover of pre-existing real files as symlinks
	$(STOW) --adopt $(PACKAGES)
