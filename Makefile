# Stow-based dotfiles: each top-level dir is a package mirroring $HOME.
# --no-folding forces real dirs + per-file symlinks (never a whole-dir symlink), so
# stowing ssh-linux/ or claude/ onto a host lacking ~/.ssh or ~/.claude can't point that
# dir at this repo and leak a later-written key/credential into it.
# ~/.ssh/config itself is deliberately not a package — see tools/canonical/.ssh/config.
IS_WSL := $(shell grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && echo 1)

ifeq ($(shell uname -s),Darwin)
OS ?= darwin
else ifeq ($(IS_WSL),1)
OS ?= wsl
else
OS ?= linux
endif

PROFILE_FILE := $(HOME)/.config/dotfiles/profile
ifneq ($(origin PROFILE),command line)
PROFILE := $(or $(shell cat $(PROFILE_FILE) 2>/dev/null),personal)
endif
ifeq ($(filter $(PROFILE),personal work),)
$(error PROFILE must be personal or work, got '$(PROFILE)')
endif

PACKAGES := $(shell awk -v os=$(OS) -v profile=$(PROFILE) '/^[a-z]/ { \
	o = 0; tagged = 0; hit = 0; \
	for (i = 2; i <= NF; i++) { \
		if ($$i == os) o = 1; \
		if ($$i == "personal" || $$i == "work") { tagged = 1; if ($$i == profile) hit = 1 } \
	} \
	if (o && (!tagged || hit)) print $$1 }' packages.conf)

STOW := stow --no-folding --verbose --target=$(HOME)

.PHONY: help install stow unstow restow adopt ssh-config packages

packages: ## List the packages this host links (override with OS=... PROFILE=personal|work)
	@printf '%s\n' $(PACKAGES)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

install: ssh-config stow ## Symlink all packages into $HOME (does NOT install software)

ssh-config: ## Install ~/.ssh/config from tools/canonical (never overwrites a real file)
	@mkdir -p $(HOME)/.ssh && chmod 700 $(HOME)/.ssh
	@if [ -L $(HOME)/.ssh/config ] && [ ! -e $(HOME)/.ssh/config ]; then \
		rm -f $(HOME)/.ssh/config; \
		install -m 600 tools/canonical/.ssh/config $(HOME)/.ssh/config; \
		echo "ssh-config: replaced dangling symlink with the skeleton"; \
	elif [ -L $(HOME)/.ssh/config ]; then \
		echo "ssh-config: ~/.ssh/config is still a symlink into the repo; remove it and re-run"; \
	elif [ -e $(HOME)/.ssh/config ]; then \
		echo "ssh-config: ~/.ssh/config already a real file, left untouched"; \
	else \
		install -m 600 tools/canonical/.ssh/config $(HOME)/.ssh/config; \
		echo "ssh-config: installed the skeleton"; \
	fi
	@grep -qF 'Include ~/.ssh/config.d/*.conf' $(HOME)/.ssh/config 2>/dev/null || \
		echo "ssh-config: WARNING no 'Include ~/.ssh/config.d/*.conf' line, tracked hosts will not load"

stow: ## Stow (symlink) all packages
	@mkdir -p $(dir $(PROFILE_FILE)) && echo $(PROFILE) > $(PROFILE_FILE)
	$(STOW) --restow $(PACKAGES)

unstow: ## Remove all symlinks
	$(STOW) --delete $(PACKAGES)

restow: stow ## Re-link all packages (after adding/renaming files)

adopt: ## One-time takeover of pre-existing real files as symlinks
	$(STOW) --adopt $(PACKAGES)
