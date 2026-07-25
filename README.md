# dotfiles

Personal dotfiles for Arch Linux (Hyprland/Wayland), managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory is a **stow package** that mirrors the layout under `$HOME`.
`stow <package>` symlinks its contents into place. Editing a file here changes the live
config immediately — the deployed files are symlinks back into this repo.

## Layout

| Package     | Symlinks into                                                   |
| ----------- | --------------------------------------------------------------- |
| `zsh`       | `~/.zshrc`, `~/.hushlogin`, `~/.config/utils/*`                 |
| `starship`  | `~/.config/starship.toml`                                       |
| `git`       | `~/.gitconfig`, `~/.gitconfig-shy`, `~/.gitignore_global`       |
| `tmux`      | `~/.tmux.conf`                                                  |
| `ssh`       | `~/.ssh/config`                                                 |
| `claude`    | `~/.claude/CLAUDE.md`, `~/.claude/hooks/uv-python.sh`           |
| `pi`        | `~/.pi/agent/extensions/{status-line,context-command,title}.ts` |
| `bat`       | `~/.config/bat/config`                                          |
| `htop`      | `~/.config/htop/htoprc`                                         |
| `k9s`       | `~/.config/k9s/*`                                               |
| `helm`      | `~/.config/helm/repositories.yaml`                              |
| `hypr`      | `~/.config/hypr/{hyprland.lua,hyprland-gui.lua,themes,scripts}` |
| `waybar`    | `~/.config/waybar/{config.jsonc,style.css,*.sh}`                |
| `walker`    | `~/.config/walker/*`                                            |
| `ghostty`   | `~/.config/ghostty/*`                                           |
| `btop`      | `~/.config/btop/*`                                              |
| `cava`      | `~/.config/cava/*`                                              |
| `fastfetch` | `~/.config/fastfetch/*`                                         |
| `herdr`     | `~/.config/herdr/config.toml`, `~/.local/bin/herdr-confirm-close-pane` |

`hypr/.config/hypr/plugins/`, `waybar/.config/waybar/backup/`, herdr's sockets/logs/session state, and
`*.bak` are gitignored, so they never enter the repo. That's git-level, not stow-level — gitignore
does not stop stow, and stow's
built-in ignore list doesn't cover `*.bak`, so a stray `.bak` left inside a package dir is still
symlinked by `make stow`. The one exception is `herdr/.stow-local-ignore`, which blocks the
`config.toml.bak-keybind-v2-<epoch>` files `herdr config reset-keys` leaves behind. Note its patterns
are anchored at both ends and matched per path segment, so `.*\.bak.*` is required — `\.bak.*$` matches
nothing. A `.stow-local-ignore` also *replaces* stow's default ignore list for that package.

The `herdr` package is additionally reached via `HERDR_CONFIG_PATH` (exported in `zsh/.zshrc`), which
points herdr straight at the repo copy. The stowed symlink stays as a fallback for any herdr started
without that variable; both routes resolve to the same file, so they cannot diverge.

Repo-only (not stowed): `tools/` — terminal colour-scheme tooling in `tools/terminals/`, plus
`tools/canonical/` (reference configs a tool rewrites live — e.g. `.claude/settings.json` — applied by
`bootstrap`, not stow).

## Usage

Prerequisite: `stow` installed (`sudo pacman -S stow`).

```sh
git clone https://github.com/phillhood/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install          # symlink every package into $HOME
```

Common operations:

```sh
make help                     # list targets
make stow                     # symlink all packages (idempotent)
make unstow                   # remove all symlinks
make restow                   # re-link after adding/renaming files
stow --no-folding git tmux    # stow individual packages
stow --no-folding -D k9s      # unstow a single package
stow --no-folding -n zsh      # dry-run (show what would happen)
```

> [!IMPORTANT]
> Always pass `--no-folding` when calling `stow` directly (`make` already does — see `Makefile:2-4`).
> Without it, stowing `ssh/` or `claude/` onto a host lacking `~/.ssh`/`~/.claude` points that whole
> directory at this public repo, so a later-written key lands inside it.

`make install` only creates symlinks — it does **not** install software.

## Fresh machine

This repo assumes the required packages are already installed. To provision a bare
machine (install packages, then clone + stow these dotfiles), see
[`phillhood/bootstrap`](https://github.com/phillhood/bootstrap).

## Migrating an existing machine

If the target files already exist as real files (e.g. migrating off another dotfile
manager), take them over once with `make adopt`.

> [!CAUTION]
> `make adopt` is a **one-time migration** step. For any package file that already exists as a
> real file at the target, it moves that local file *into* the repo — overwriting the tracked
> copy — then symlinks it back. Run it from a clean tree and **review `git diff` afterward**:
> every adopted change shows up there. Commit what you want to keep, and discard local drift with
> `git restore .`. Re-running it later can silently clobber committed config with stale local files.

```sh
git status            # start from a clean tree
make adopt            # stow --adopt: pull existing real files into the repo, then symlink
git diff              # review every adopted change — this is your safety check
git restore .         # discard unwanted drift (or commit to keep it)
```
