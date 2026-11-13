<p align="center">
  <img src="assets/logo.svg" alt="" width="128">
</p>

<h1 align="center">dotfiles</h1>

<p align="center">
  Arch Linux (Hyprland) and macOS, managed with <a href="https://www.gnu.org/software/stow/">GNU Stow</a>.
</p>

## Install

Needs `stow` (`pacman -S stow` or `brew install stow`).

```sh
git clone https://git.lab.phillhood.ca/phillhood/dotfiles.git ~/Dev/phillhood/dotfiles
cd ~/Dev/phillhood/dotfiles
make install
```

Clone to exactly that path; `zsh/.zshrc` hardcodes it. `make install` only links config, it installs
no software. To provision a bare machine, see [`phillhood/bootstrap`](https://github.com/phillhood/bootstrap).

## Usage

```sh
make stow      # link every package for this OS
make unstow    # remove the links
make restow    # re-link after adding, renaming or removing files
make help      # list all targets
```

Each top-level directory is a package mirroring `$HOME`. When calling `stow` directly, always pass
`--no-folding`.

## Packages

| | |
| --- | --- |
| **Shared** | `zsh` `starship` `git` `tmux` `ssh` `claude` `pi` `nvim` `bat` `htop` `btop` `k9s` `helm` `ghostty` `cava` `fastfetch` `herdr` |
| **Linux** | `hypr` `waybar` `walker` `swaync` `herdr-app` `ghostty-linux` `ssh-linux` |
| **macOS** | `ghostty-darwin` |

## Docs

- [Stow layout](docs/stow.md): per-OS packages, `--no-folding`, ignores, migrating a machine
- [SSH](docs/ssh.md): why `~/.ssh/config` isn't stowed, and the Forgejo remote
- [Arch desktop](docs/arch/): Hyprland, waybar, swaync
