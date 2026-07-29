# AGENTS.md

Personal dotfiles for Arch Linux and macOS, managed with GNU Stow.

## Model

- Each top-level directory is a stow package mirroring `$HOME`.
- `Makefile` selects packages per-OS on `uname -s`: `LINUX_PACKAGES` (`hypr`, `waybar`, `walker`)
  are skipped on macOS, `COMMON_PACKAGES` are stowed on both.
- Files deployed into `$HOME` are symlinks back to this repo; edit the repo copy.
- After adding, renaming, or removing package files, run `make restow`.
- Do not track secrets, private keys, credentials, caches, sessions, or runtime state.

## Commands

```sh
make install   # stow all packages into $HOME
make restow    # re-link after file layout changes
make unstow    # remove managed symlinks
make adopt     # one-time migration of existing real files; review diff after
```

## Important packages

- `zsh/` — shell config and `~/.config/utils/*` helpers.
- `git/` — git config and global ignore.
- `ssh/` — only public SSH config; never keys.
- `claude/` — stable Claude files only; no runtime settings/state.
- `pi/` — Pi global extensions under `~/.pi/agent/extensions/`; no auth/sessions/settings.
- `tools/` — repo-only utilities and canonical reference files; not stowed.

## Guidelines for agents

- Keep changes small and directly relevant.
- Prefer editing package files in this repo, not their `$HOME` symlink targets.
- Update `Makefile` `COMMON_PACKAGES` or `LINUX_PACKAGES` when adding/removing a top-level stow
  package, and keep anything Linux-only out of the common list.
- Shell config must degrade on a host missing a tool: guard `eval "$(tool init)"` with `command -v`,
  and put OS-specific setup in `zsh/.config/utils/distro/<os>` rather than branching inline.
- Update `README.md` only when user-facing layout or usage changes.
- Use `git status` before finishing and mention unrelated pre-existing changes.
