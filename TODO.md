# Dotfiles TODO

Open follow-ups for the stow-based dotfiles.

## Hyprland desktop rice
- [x] Track the core rice as stow packages — hypr, waybar, walker, ghostty, cava, fastfetch, btop are
      all packages and in `Makefile` `PACKAGES` (`575be02`).
- [ ] Decide whether to track the last two: `~/.config/nwg-look/config` (282 B, GTK theme) and
      `~/.config/wireplumber/wireplumber.conf.d/` (drop-ins). Both still real dirs.
- [ ] Machine-specific lines ship as-is in `hypr/.config/hypr/hyprland.lua`: monitors hardcoded to
      `DP-1`/`DP-2` (lines 10-11) and an Nvidia env block (lines 24-26). Stowing on another machine
      misconfigures it; a generic fallback sits commented out at line 15.

## SSH
- [x] `~/.ssh/config` untracked and dropped from `PACKAGES` — colima and the AWS Toolkit for VSCode
      both write host blocks into it, so a stow symlink would send those writes into the repo. Tracked
      hosts moved to `ssh-linux/.ssh/config.d/homelab.conf`, pulled in by a leading
      `Include ~/.ssh/config.d/*.conf`; skeleton in `tools/canonical/.ssh/config`.
- [x] `make ssh-config` installs the skeleton at mode 600 when `~/.ssh/config` is absent or a dangling
      symlink, leaves a real file untouched, and warns when the `Include` line is missing. Wired into
      `make install`, so bootstrap needs no extra step.
- [ ] **Arch, one-time:** `~/.ssh/config` there is still a symlink to the deleted `ssh/.ssh/config`, so
      it dangles once this is pulled. Run `make ssh-config` (or `make install`) on that box — it detects
      the dangling link and swaps in the skeleton. Until then every ssh host there stops resolving.
- [ ] `~/.gitconfig` `includeIf` blocks pull in `~/.gitconfig-shy` (`~/.ssh/id_shy`) and
      `~/.gitconfig-aethon` (`~/.ssh/id_rsa_aethon`). Check which keys the mac has; a push under a
      missing identity fails there. Decide whether to install them or scope the includes per-OS.

## Claude Code (~/.claude)
- [x] `settings.json` untracked from the `claude` package (Claude Code rewrites it live) — canonical
      copy kept in `tools/canonical/.claude/settings.json` (`afa7977`, relocated in `9d0a014`).
- [x] Curate the canonical copy down to real prefs (`9d0a014`, 203 → 51 lines).
- [ ] Bootstrap: apply `tools/canonical/.claude/settings.json` on a fresh machine by **merging** into
      `~/.claude/settings.json` (`jq -s '.[0] * .[1]'`), never overwriting — Claude Code owns that file
      at runtime. Keep the canonical copy free of `//` comments so `jq` can parse it. The `statusLine`
      now points at `~/.claude/statusline.sh`, which the `claude` package stows — nothing extra to
      install, but it needs `bash` 5+ and `jq` on `PATH`.
- [x] `statusline.sh` parses an ISO 8601 `resets_at` on both platforms — GNU `date -d` first, then a
      BSD `date -j -f` fallback. Previously every usage ETA silently vanished on macOS.

## Cross-platform (macOS ⇄ Arch)
- [x] Per-OS overlay pattern established on `ghostty`: shared `config` ends with `config-file = ?os.conf`
      and `ghostty-darwin`/`ghostty-linux` each supply an `os.conf`. Only the running OS's overlay is
      stowed, so a key added to one cannot leak to the other.
- [x] `fastfetch` stays a single shared package — it loads exactly one config file (`-c` twice fails with
      `only one config file can be loaded`, and the jsonc has no include), so the ghostty overlay pattern
      would mean duplicating all 122 lines. Made OS-agnostic instead: dropped `logo.source = arch` so
      `type: auto` picks the running OS logo, swapped the Arch glyph on the OS row for a neutral one, and
      made the `OS Age` command try GNU `stat -c %W` then BSD `stat -f %B`. It previously printed 20664
      days on macOS — `stat -c` errored, `birthd` came out empty, and the arithmetic measured the epoch.
- [x] `logo.color` carries a 6-stop Catppuccin Mocha ramp. Slot count is fixed by the builtin logo and
      keys past it are ignored: `macos` exposes 6 bands top-to-bottom, every Arch builtin (`arch`,
      `arch2`, `arch3`, `arch_small`, `arch_old`) exposes only 2. One config file serves both, so slots
      1-2 colour the whole Arch logo *and* the Apple's top two bands — they stay sky/mauve to keep the
      Arch look, and 3-6 continue the sweep on the mac only.
- [x] Hardcoded `/home/phill/…` paths in packages stowed on every host. herdr runs `[[keys.command]]`
      through `/bin/sh -c`, so `herdr/.config/herdr/config.toml` now uses `$HOME/.local/bin/…`. k9s's
      `screenDumpDir` was dropped from `k9s/.config/k9s/config.yaml`: unset, it falls back to
      `$XDG_STATE_HOME/k9s/screen-dumps`, the same path. The desktop-only packages (hypr, waybar,
      swaync) still hardcode `/home/phill`.

## Windows
- [ ] Check the Windows Terminal canonical settings at the desk: PowerShell 7 is the default profile,
      there's no duplicate "PowerShell" entry, and `ctrl+w` closes a pane.
- [ ] SSH keys aren't on the Windows machine yet: `id_phill`, plus `id_shy` and `id_rsa_aethon` if
      those identities are used there. `ssh-add` each one to the Windows agent once it's there.
- [x] git over SSH uses Windows OpenSSH, so the `ssh-agent` service holds each identity's passphrase:
      `core.sshCommand` runs `${DOTFILES_SSH:-ssh}`, set by `install.ps1` (`fff955d`). Re-run
      `install.ps1` on the work machine to set `DOTFILES_SSH`.
- [ ] Optional: `pwsh-windows` startup is ~1.55s against a 0.36s baseline, mostly the starship, atuin
      and zoxide init evals. Caching their generated scripts as the uv completion already is
      (regenerated when the exe is newer) would save about 200ms.
