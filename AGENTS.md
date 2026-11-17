# AGENTS.md

Personal dotfiles for Arch Linux, macOS, WSL and Windows, managed with GNU Stow (and `install.ps1` on
Windows).

## Model

- Each top-level directory is a stow package mirroring `$HOME`.
- `Makefile` selects packages per-OS on `uname -s` plus a WSL check: `COMMON_PACKAGES` everywhere,
  `LINUX_PACKAGES` on Linux including WSL, `DESKTOP_PACKAGES` (the Hyprland rice and GUI apps) on
  non-WSL Linux only, `DARWIN_PACKAGES` on macOS.
- Files deployed into `$HOME` are symlinks back to this repo; edit the repo copy.
- After adding, renaming, or removing package files, run `make restow`.
- Windows has no make/stow: `install.ps1` links its own package list (`*-windows` packages plus the
  portable shared ones). Add a package there too when it should reach Windows. See `docs/windows.md`.
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
- Put a new top-level package in the `Makefile` list it belongs to, and keep anything Linux-only out of
  `COMMON_PACKAGES`.
- Shell config must degrade on a host missing a tool: guard `eval "$(tool init)"` with `command -v`,
  and put OS-specific setup in `zsh/.config/utils/distro/<os>` rather than branching inline.
- Writing a file in the WSL checkout from Windows (`\\wsl.localhost\...`) drops its executable bit.
  Check `git diff --summary` for `mode change` and `chmod +x` the hooks and scripts back.
- Hook changes under `claude/.claude/hooks/` need a test in `tests/claude/`; run them from that
  directory with `uv run python -m unittest`.
- Update `README.md` only when user-facing layout or usage changes.
- Use `git status` before finishing and mention unrelated pre-existing changes.
