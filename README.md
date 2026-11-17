<p align="center">
  <img src="assets/logo.svg" alt="" width="128">
</p>

<h1 align="center">dotfiles</h1>

<p align="center">
  Arch Linux (Hyprland), macOS and Windows, managed with <a href="https://www.gnu.org/software/stow/">GNU Stow</a>.
</p>

## Install

Needs `stow` (`pacman -S stow`, `apt install stow` or `brew install stow`).

```sh
git clone https://git.lab.phillhood.ca/phillhood/dotfiles.git ~/Dev/phillhood/dotfiles
cd ~/Dev/phillhood/dotfiles
make install
```

Clone to exactly that path; `.zshrc` hardcodes it. On a work machine, `make install PROFILE=work`. `make install` only links config, it installs
no software. To provision a bare machine, see [`phillhood/bootstrap`](https://github.com/phillhood/bootstrap).

## Usage

```sh
make stow      # link every package for this machine
make unstow    # remove the links
make restow    # re-link after adding, renaming or removing files
make packages  # list the package folders this machine links
make help      # list all targets
```

When calling `stow` directly, always pass `--no-folding`.

## Layout

Packages are tool-named folders that mirror `$HOME`, grouped into layers. A machine links its platform
layers (from `layers.conf`) plus its profile layer.

| Layer | Goes to | Packages |
| --- | --- | --- |
| `platform/shared` | every machine | `bat` `claude` `git` `helm` `k9s` `nvim` `pi` `starship` |
| `platform/unix` | Linux, WSL, macOS | `btop` `cava` `fastfetch` `ghostty` `herdr` `htop` `tmux` `zsh` |
| `platform/desktop` | Linux with a compositor | `ghostty` `herdr-app` `hypr` `swaync` `walker` `waybar` |
| `platform/darwin` | macOS | `ghostty` |
| `platform/windows` | Windows, via `install.ps1` | `pwsh` |
| `profile/personal` | personal machines | `claude` `git` `pwsh` `ssh` `zsh` |
| `profile/work` | work machines | `git` |

Each machine is `personal` (the default) or `work`: `make install PROFILE=work` picks it once and
later runs remember it. See [Stow layout](docs/stow.md).

## Docs

- [Stow layout](docs/stow.md): layers, profiles, `--no-folding`, ignores, migrating a machine
- [Windows](docs/windows.md): `install.ps1`, the PowerShell port of the shell, what's skipped
- [SSH](docs/ssh.md): why `~/.ssh/config` isn't stowed, and the Forgejo remote
- [Arch desktop](docs/arch/): Hyprland, waybar, swaync
