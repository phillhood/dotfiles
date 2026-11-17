# AGENTS.md

Personal dotfiles for Arch Linux, macOS, WSL and Windows, managed with GNU Stow (and `install.ps1` on
Windows).

## Model

- Packages are tool-named folders mirroring `$HOME`, grouped into layers: `platform/{shared,unix,
  desktop,darwin,windows}/<tool>` and `profile/{personal,work}/<tool>`. See `docs/stow.md`.
- `layers.conf` maps each OS to its platform layers; the machine's profile (saved in
  `~/.config/dotfiles/profile`) adds its profile layer. `Makefile` and `install.ps1` both read it;
  `make packages` prints this host's package folders.
- A profile package is linked when the machine links a platform package with the same name, or when no
  platform layer has that name at all.
- Personal identities, keys, hosts and homelab tooling go in `profile/personal`, never in a platform
  layer: work machines link every platform layer they match.
- Files deployed into `$HOME` are symlinks back to this repo; edit the repo copy.
- After adding, renaming, or removing package files, run `make restow`. Moving a file between packages
  leaves its old link dangling: unstow before the move, or delete the dangling links after.
- Windows has no make/stow: `install.ps1` links the `windows` layers. See `docs/windows.md`.
- Shell changes made in `platform/unix/zsh/` usually need the matching change in
  `platform/windows/pwsh/`.
- Do not track secrets, private keys, credentials, caches, sessions, or runtime state.

## Commands

```sh
make install                # stow all packages into $HOME
make install PROFILE=work   # first run on a work machine; later runs remember it
make restow                 # re-link after file layout changes
make unstow                 # remove managed symlinks
make packages               # list the package folders this host links
make adopt                  # one-time migration of existing real files; review diff after
```

```powershell
.\install.ps1 -Profile work  # Windows: first run on a work machine
.\install.ps1                # link packages into $HOME
.\install.ps1 -Unlink        # remove managed links
.\install.ps1 -List          # print the package folders it would link
```

## Important packages

- `platform/unix/zsh/` — shell config and `~/.config/utils/*` helpers.
- `platform/windows/pwsh/` — the PowerShell 7 port of `zsh/` and its utils.
- `platform/shared/git/` — git config and global ignore; identity comes from `profile/*/git/`.
- `profile/personal/ssh/` — only public SSH config; never keys.
- `platform/shared/claude/` — stable Claude files only; no runtime settings/state.
- `platform/shared/pi/` — Pi global extensions under `~/.pi/agent/extensions/`; no auth/sessions/settings.
- `tools/` — repo-only utilities and canonical reference files; not stowed.

## Guidelines for agents

- Keep changes small and directly relevant.
- Prefer editing package files in this repo, not their `$HOME` symlink targets.
- A new package is a new folder in the layer it belongs to; nothing else lists packages.
  `tests/test_packages.py` checks the layers. OS-specific lines go in the OS layer's package of the same
  name, not in a suffixed package.
- Shell config must degrade on a host missing a tool: guard `eval "$(tool init)"` with `command -v`,
  and put OS-specific setup in `~/.config/utils/distro/<os>` rather than branching inline.
- Writing a file in the WSL checkout from Windows (`\\wsl.localhost\...`) drops its executable bit.
  Check `git diff --summary` for `mode change` and `chmod +x` the hooks and scripts back.
- Hook changes under `platform/shared/claude/.claude/hooks/` need a test in `tests/claude/`; run them
  from that directory with `uv run python -m unittest`.
- Update `README.md` only when user-facing layout or usage changes.
- Use `git status` before finishing and mention unrelated pre-existing changes.
