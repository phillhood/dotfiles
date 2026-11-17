# AGENTS.md

Personal dotfiles for Arch Linux, macOS, WSL and Windows, managed with GNU Stow (and `install.ps1` on
Windows).

## Model

- Each top-level directory is a stow package mirroring `$HOME`.
- `packages.conf` lists every package and the OSes that link it: `linux` (desktop Linux), `wsl`,
  `darwin`, `windows`, plus an optional profile, `personal` or `work`. `Makefile` and `install.ps1`
  both read it; `make packages` prints this host's set. See `docs/stow.md#profiles`.
- Personal identities, keys, hosts and homelab tooling go in a `personal` package, never in a shared
  one: work machines link the shared packages.
- Files deployed into `$HOME` are symlinks back to this repo; edit the repo copy.
- After adding, renaming, or removing package files, run `make restow`.
- Windows has no make/stow: `install.ps1` links the `windows` packages from `packages.conf`. See
  `docs/windows.md`.
- Shell changes made in `zsh/` usually need the matching change in `pwsh-windows/`.
- Do not track secrets, private keys, credentials, caches, sessions, or runtime state.

## Commands

```sh
make install   # stow all packages into $HOME
make restow    # re-link after file layout changes
make unstow    # remove managed symlinks
make adopt     # one-time migration of existing real files; review diff after
```

```powershell
.\install.ps1          # Windows: link packages into $HOME
.\install.ps1 -Unlink  # remove managed links
.\install.ps1 -List    # print the packages it would link
```

## Important packages

- `zsh/` — shell config and `~/.config/utils/*` helpers.
- `pwsh-windows/` — the PowerShell 7 port of `zsh/` and its utils.
- `git/` — git config and global ignore.
- `ssh/` — only public SSH config; never keys.
- `claude/` — stable Claude files only; no runtime settings/state.
- `pi/` — Pi global extensions under `~/.pi/agent/extensions/`; no auth/sessions/settings.
- `tools/` — repo-only utilities and canonical reference files; not stowed.

## Guidelines for agents

- Keep changes small and directly relevant.
- Prefer editing package files in this repo, not their `$HOME` symlink targets.
- Add or remove a top-level package's line in `packages.conf` with it; `tests/test_packages.py` fails
  on a package directory that isn't listed. OS-specific config goes in a `<tool>-<os>` package.
- Shell config must degrade on a host missing a tool: guard `eval "$(tool init)"` with `command -v`,
  and put OS-specific setup in `zsh/.config/utils/distro/<os>` rather than branching inline.
- Writing a file in the WSL checkout from Windows (`\\wsl.localhost\...`) drops its executable bit.
  Check `git diff --summary` for `mode change` and `chmod +x` the hooks and scripts back.
- Hook changes under `claude/.claude/hooks/` need a test in `tests/claude/`; run them from that
  directory with `uv run python -m unittest`.
- Update `README.md` only when user-facing layout or usage changes.
- Use `git status` before finishing and mention unrelated pre-existing changes.
