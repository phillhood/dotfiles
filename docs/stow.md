# Stow layout

Packages live in layers. A package is a directory named after its tool that mirrors `$HOME`; the
deployed files are symlinks back into this repo, so editing a file here changes the live config
immediately.

```
platform/
  shared/    every machine, Windows included
  unix/      Linux, WSL and macOS
  desktop/   Linux with a compositor (not WSL)
  darwin/    macOS
  windows/   Windows (linked by install.ps1)
profile/
  personal/  personal machines
  work/      work machines
```

A machine links its platform layers plus its profile layer. The same tool can have a package in
several layers, each adding its own files: `platform/shared/git` holds the shared git settings,
`profile/personal/git` and `profile/work/git` the identity.

## Platform layers

`layers.conf` maps each OS to its platform layers, and both `Makefile` and `install.ps1` read it:

```
linux    shared unix desktop
wsl      shared unix
darwin   shared unix darwin
windows  shared windows
```

`Makefile` picks the OS on `uname -s` plus a WSL check (`microsoft` in `/proc/sys/kernel/osrelease`).
`desktop` holds the Wayland rice and GUI apps, which WSL skips: it has no compositor, and the terminal
runs on the Windows side.

`make packages` prints the current host's package folders, and `make packages OS=darwin PROFILE=work`
any other. A new package is a new folder in the right layer; nothing else lists it.
`tests/test_packages.py` fails when `layers.conf` and the folders disagree, when two packages linked on
the same machine ship the same file, or when `make` and `install.ps1` pick differently
(`uv run python -m unittest tests/test_packages.py`).

## Profiles

Each machine is `personal` or `work`. Work machines get the same shell, editor and tools, without
personal identities, hosts and keys:

| | personal | work |
| --- | --- | --- |
| git identity | `git`: phillhood by default, shychedelic and Aethon by directory | `git`: Aethon by default, phillhood name and email under `~/Dev/phillhood/` with no key |
| SSH hosts | `ssh`: forge and homelab | none |
| homelab helpers | `zsh`, `pwsh`: `kdeploy` | none |

A profile package is linked when the machine also links a platform package with the same name, or when
no platform layer has a package by that name at all. So `profile/personal/zsh` extends `zsh` and is
skipped on Windows, `profile/personal/pwsh` is the reverse, and `profile/personal/ssh`, with no
platform counterpart, goes to every personal machine. Personal machines without the homelab key (the
mac) still get the homelab hosts; `ssh` to them fails authentication, as it would with no entry.

`platform/shared/git/.gitconfig` carries the shared settings and includes `~/.gitconfig-profile`, which
each profile's `git` supplies. `.gitconfig-aethon` stays in `platform/shared/git`, since both profiles
use it. `tests/test_git_ssh.py` checks the identity and key per directory for both profiles.

The profile is saved in `~/.config/dotfiles/profile`; unset means `personal`. `make install
PROFILE=work` (or `.\install.ps1 -Profile work`) sets it, and later runs reuse it. Switching an
existing machine:

```sh
make unstow                  # with the old profile, so its packages' links go
make install PROFILE=work
```

Moving a file between packages leaves its old link dangling, and stow won't clean it up. Unstow before
pulling such a change, or list the dangling links afterwards and delete them before restowing:

```sh
find ~ -xtype l -lname '*phillhood/dotfiles*' -not -path "$HOME/Dev/*"
```

## Per-OS overlays

Where one config file needs a few different lines per OS, the shared file stays in the common layer
and the divergent keys go in the OS layer's package of the same name, loaded through the tool's own
optional include. `ghostty` is the worked example: `platform/unix/ghostty/.config/ghostty/config` ends
with `config-file = ?os.conf`, and `platform/desktop/ghostty` and `platform/darwin/ghostty` each supply
an `os.conf`. The `?` makes a missing overlay a no-op.

Two layers rather than both overlays shipped side by side, because Ghostty parses the full key schema
on every platform: a macOS-only key like `macos-option-as-alt` is accepted, and inert, on Linux. With
both files stowed, a key added to one overlay and forgotten in the other would apply on both OSes.

Tools that load a single file use their own per-OS switch instead. `fastfetch` has no include, so its
modules carry `"condition": { "system": ... }`.

The shell picks per OS at runtime instead: `.zshrc` sources `~/.config/utils/distro/<os>`, keyed on
`/etc/os-release`'s `$ID` where it exists and lowercased `uname -s` otherwise. It runs before the
`starship`/`fnm`/`fzf`/`atuin` init evals so Homebrew's `shellenv` is on `PATH` in time, and each eval is
guarded by `command -v` so a host missing a tool still gets a working shell. Ubuntu/WSL gets `distro/ubuntu`,
which starts an `ssh-agent` on a fixed socket (Ubuntu's user unit only runs under X) and moves WSL's
Windows `PATH` entries into `$winpath`, searched only from `command_not_found_handler`.

## --no-folding

Always pass `--no-folding` when calling `stow` directly; `make` already does. Without it, stowing
`ssh/` or `claude/` onto a host lacking `~/.ssh` or `~/.claude` symlinks that whole directory to
this repo, so a key or credential written there later lands inside it.

## Gitignore does not stop stow

`.gitignore` keeps build output, backups and runtime state out of git, but stow still links anything
sitting in a package directory. Stow's built-in ignore list doesn't cover `*.bak`, so a stray backup
inside a package is symlinked by `make stow`.

`platform/unix/herdr/.stow-local-ignore` is the exception. It blocks the `config.toml.bak-keybind-v2-<epoch>` files
`herdr config reset-keys` leaves behind, plus herdr's runtime state. Its patterns are anchored at both
ends and matched per path segment, so `.*\.bak.*` is required; `\.bak.*$` matches nothing. A
`.stow-local-ignore` also replaces stow's default ignore list for that package.

herdr needs it because `HERDR_CONFIG_PATH` (exported in `.zshrc`) points herdr straight at the repo
copy of its config, `platform/unix/herdr/.config/herdr/config.toml`. A running herdr keeps the path it
started with, so restart it after that path changes. herdr writes `release-notes.json`, `session.json`, `.plugins.lock`, logs and sockets
beside its config, so they reappear in the package on every run. Stow would then try to link each over
the real file already in `~/.config/herdr`, and because stow plans every package before applying any,
that one conflict prints `All operations aborted` and leaves every package unlinked. The env var is also
why the repo must be cloned to `~/Dev/phillhood/dotfiles` on every host.

## Repo-only files

`tools/` is not stowed. `tools/terminals/` holds terminal colour-scheme tooling, and `tools/canonical/`
holds reference configs that a tool rewrites live (`.claude/settings.json`, `.ssh/config`). Those are
applied by `bootstrap` or `make ssh-config`, not stow. Merge the Claude settings into
`~/.claude/settings.json` (`jq -s '.[0] * .[1]'`) rather than overwriting it.

## Migrating an existing machine

`make adopt` takes over files that already exist as real files at the target. For each one it moves the
local file into the repo, overwriting the tracked copy, then symlinks it back. Run it once, from a clean
tree, and review the result:

```sh
git status     # start clean
make adopt
git diff       # every adopted change shows up here
git restore .  # discard unwanted drift, or commit what you want to keep
```

Re-running it later can silently replace committed config with stale local files.
