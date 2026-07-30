# dotfiles

Personal dotfiles for Arch Linux (Hyprland/Wayland) and macOS, managed with
[GNU Stow](https://www.gnu.org/software/stow/). The desktop packages are Linux-only; the shell and
CLI packages are shared — see [Per-OS packages](#per-os-packages).

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
| `ssh`       | `~/.ssh/config.d/forge.conf`                                    |
| `ssh-linux` | `~/.ssh/config.d/homelab.conf`                                  |
| `claude`    | `~/.claude/CLAUDE.md`, `~/.claude/hooks/uv-python.sh`           |
| `pi`        | `~/.pi/agent/extensions/{status-line,context-command,title}.ts` |
| `bat`       | `~/.config/bat/config`                                          |
| `htop`      | `~/.config/htop/htoprc`                                         |
| `k9s`       | `~/.config/k9s/*`                                               |
| `helm`      | `~/.config/helm/repositories.yaml`                              |
| `hypr`      | `~/.config/hypr/{hyprland.lua,hyprland-gui.lua,themes,scripts}` |
| `waybar`    | `~/.config/waybar/{config.jsonc,style.css,*.sh}`                |
| `walker`    | `~/.config/walker/*`                                            |
| `ghostty`   | `~/.config/ghostty/config`                                      |
| `ghostty-darwin` / `ghostty-linux` | `~/.config/ghostty/os.conf` (per-OS overlay)    |
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
`tools/canonical/` (reference configs a tool rewrites live — `.claude/settings.json` and
`.ssh/config` — applied by `bootstrap`, not stow).

### ~/.ssh/config is deliberately not stowed

`~/.ssh/config` stays a real per-machine file. Colima and the AWS Toolkit for VSCode both write host
blocks into it, and if it were a stow symlink those writes would land in this repo. The tracked host
definitions live in `ssh-linux/.ssh/config.d/homelab.conf` instead, pulled in by

```
Include ~/.ssh/config.d/*.conf
```

which must stay the **first** line: ssh takes the first value it finds for each keyword, so anything
above the `Include` silently wins over the tracked fragments. A glob that matches nothing is not an
error, so the same skeleton works on a machine with no fragments stowed.

`make ssh-config` (also run by `make install`) installs that skeleton from
`tools/canonical/.ssh/config` at mode 600 when `~/.ssh/config` is absent or a dangling symlink, leaves
an existing real file alone, and warns if the `Include` line is missing.

The homelab hosts are Linux-only because they pin `~/.ssh/id_ed25519_homelab` with
`IdentitiesOnly yes`, and that key is not on the mac.

## Usage

Prerequisite: `stow` installed (`sudo pacman -S stow`, or `brew install stow` on macOS).

```sh
git clone https://git.lab.shychedelic.com/phillhood/dotfiles.git ~/Dev/phillhood/dotfiles
cd ~/Dev/phillhood/dotfiles
make install          # symlink every package for this OS into $HOME
```

Clone to that exact path on every host — `HERDR_CONFIG_PATH` in `zsh/.zshrc` hardcodes it.

### Forgejo remote

The initial clone uses HTTPS because it needs no local setup: Forgejo's SSH is the built-in server on
**192.168.1.103 port 2222**, not port 22 (that is the host's own sshd, which rejects `git@`), and the
`git.lab.shychedelic.com` reverse proxy only forwards HTTP. The `Host` block that hides the port lives
in `ssh/.ssh/config.d/forge.conf` — inside this repo, so it isn't available until after the first
`make stow`. Once stowed, `forge.home` and `git.lab.shychedelic.com` both route to :2222 and

```sh
git remote set-url origin git@git.lab.shychedelic.com:phillhood/dotfiles.git
```

works. Port 2222 is LAN-only and not proxied to the WAN, so off-LAN needs the Tailscale path or HTTPS.
`IdentityFile` is `~/.ssh/id_phill`, which resolves on both machines — a real key on Arch, a symlink to
`id_ed25519` on the mac.

### Per-OS packages

`Makefile` splits packages into `COMMON_PACKAGES`, `LINUX_PACKAGES` and `DARWIN_PACKAGES`, selected on
`uname -s`. `hypr`, `waybar`, `walker`, `ghostty-linux` and `ssh-linux` are Linux-only;
`ghostty-darwin` is macOS-only; everything else is stowed on both. Adding a top-level package means adding it to whichever
of the three lists it belongs in.

Where a single config file needs a few different lines per OS, keep the shared file in the common
package and put the divergent keys in a per-OS overlay package, using the tool's own optional-include
so only the overlay for the running OS is ever stowed. `ghostty` is the worked example: the shared
`config` ends with `config-file = ?os.conf`, and `ghostty-darwin`/`ghostty-linux` each supply their own
`os.conf`. The `?` makes a missing overlay a no-op rather than an error.

Splitting into two packages rather than shipping both overlays and letting load order settle it is
deliberate: Ghostty parses the full key schema on every platform, so a macOS-only key like
`macos-option-as-alt` is accepted (and inert) on Linux. With both files stowed, a key added to one
overlay and forgotten in the other would silently apply on both OSes.

macOS also gets `zsh/.config/utils/distro/darwin` instead of `distro/arch`. That dispatch keys off
`/etc/os-release`'s `$ID` where the file exists and falls back to lowercased `uname -s`, and it runs
before the `starship`/`fnm`/`fzf`/`atuin` init evals so Homebrew's `shellenv` is on `PATH` in time.
Each of those evals is guarded by `command -v`, so a host missing one of the tools still gets a
working shell rather than a wall of errors.

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
> Always pass `--no-folding` when calling `stow` directly (`make` already does — see the `STOW` variable).
> Without it, stowing `ssh-linux/` or `claude/` onto a host lacking `~/.ssh`/`~/.claude` points that
> whole directory at this repo, so a later-written key lands inside it.

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
