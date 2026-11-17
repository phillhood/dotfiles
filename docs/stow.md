# Stow layout

Each top-level directory is a stow package that mirrors `$HOME`. The deployed files are symlinks back
into this repo, so editing a file here changes the live config immediately.

## Per-OS packages

`packages.conf` is the one list of packages: each line names a package and the OSes that link it,
`linux`, `wsl`, `darwin` or `windows`. `Makefile` picks the OS on `uname -s` plus a WSL check
(`microsoft` in `/proc/sys/kernel/osrelease`) and stows the matching lines; `install.ps1` links the
`windows` lines. `linux` means Linux with a desktop: the Wayland rice and GUI apps are tagged `linux`
but not `wsl`, since WSL has no compositor and the terminal runs on the Windows side.

`make packages` prints the current host's set, and `make packages OS=darwin` any other. A new
top-level package needs a line there; `tests/test_packages.py` fails on a package directory that isn't
listed, an unknown OS tag, or `make`/`install.ps1` disagreeing with the file
(`uv run python -m unittest tests/test_packages.py`).

Where one config file needs a few different lines per OS, the shared file stays in the common package
and the divergent keys go in a per-OS overlay package, loaded through the tool's own optional include.
`ghostty` is the worked example: the shared `config` ends with `config-file = ?os.conf`, and
`ghostty-darwin`/`ghostty-linux` each supply an `os.conf`. The `?` makes a missing overlay a no-op.

Two packages rather than both overlays shipped side by side, because Ghostty parses the full key schema
on every platform: a macOS-only key like `macos-option-as-alt` is accepted, and inert, on Linux. With
both files stowed, a key added to one overlay and forgotten in the other would apply on both OSes.

Tools that load a single file use their own per-OS switch instead. `fastfetch` has no include, so its
modules carry `"condition": { "system": ... }`.

The shell follows the same split: `zsh/.zshrc` sources `zsh/.config/utils/distro/<os>`, keyed on
`/etc/os-release`'s `$ID` where it exists and lowercased `uname -s` otherwise. It runs before the
`starship`/`fnm`/`fzf`/`atuin` init evals so Homebrew's `shellenv` is on `PATH` in time, and each eval is
guarded by `command -v` so a host missing a tool still gets a working shell. Ubuntu/WSL gets `distro/ubuntu`,
which starts an `ssh-agent` on a fixed socket (Ubuntu's user unit only runs under X) and moves WSL's
Windows `PATH` entries into `$winpath`, searched only from `command_not_found_handler`.

## --no-folding

Always pass `--no-folding` when calling `stow` directly; `make` already does. Without it, stowing
`ssh-linux/` or `claude/` onto a host lacking `~/.ssh` or `~/.claude` symlinks that whole directory to
this repo, so a key or credential written there later lands inside it.

## Gitignore does not stop stow

`.gitignore` keeps build output, backups and runtime state out of git, but stow still links anything
sitting in a package directory. Stow's built-in ignore list doesn't cover `*.bak`, so a stray backup
inside a package is symlinked by `make stow`.

`herdr/.stow-local-ignore` is the exception. It blocks the `config.toml.bak-keybind-v2-<epoch>` files
`herdr config reset-keys` leaves behind, plus herdr's runtime state. Its patterns are anchored at both
ends and matched per path segment, so `.*\.bak.*` is required; `\.bak.*$` matches nothing. A
`.stow-local-ignore` also replaces stow's default ignore list for that package.

herdr needs it because `HERDR_CONFIG_PATH` (exported in `zsh/.zshrc`) points herdr straight at the repo
copy of its config. herdr writes `release-notes.json`, `session.json`, `.plugins.lock`, logs and sockets
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
