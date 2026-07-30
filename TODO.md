# Dotfiles TODO

Open follow-ups for the stow-based dotfiles.

## Neovim
- [ ] Decide nvim config: Arch runs a stock LazyVim (`~/.config/nvim` is still a real dir — untouched
      starter, empty `extras`, unmodified `example.lua`); old EndeavourOS ran NvChad.
- [ ] Once decided, add an `nvim/` stow package (`nvim/.config/nvim/…`); track `lazy-lock.json` and
      `lua/plugins/` — that's config, not plugin code. lazy.nvim installs plugins to
      `~/.local/share/nvim/lazy`, outside the package, so there is nothing to ignore.

## Hyprland desktop rice
- [x] Track the core rice as stow packages — hypr, waybar, walker, ghostty, cava, fastfetch, btop are
      all packages and in `Makefile` `PACKAGES` (`575be02`).
- [ ] Decide whether to track the last two: `~/.config/nwg-look/config` (282 B, GTK theme) and
      `~/.config/wireplumber/wireplumber.conf.d/` (drop-ins). Both still real dirs.
- [ ] Machine-specific lines ship as-is in `hypr/.config/hypr/hyprland.lua`: monitors hardcoded to
      `DP-3`/`DP-2` (lines 10-11) and an Nvidia env block (lines 24-26). Stowing on another machine
      misconfigures it; a generic fallback sits commented out at line 15.

## SSH
- [x] `~/.ssh/config` untracked and dropped from `PACKAGES` — colima and the AWS Toolkit for VSCode
      both write host blocks into it, so a stow symlink would send those writes into the repo. Tracked
      hosts moved to `ssh-linux/.ssh/config.d/homelab.conf`, pulled in by a leading
      `Include ~/.ssh/config.d/*.conf`; skeleton in `tools/canonical/.ssh/config`.
- [ ] **Arch, one-time:** `~/.ssh/config` there is still a symlink to the deleted `ssh/.ssh/config`, so
      it dangles after this is pulled. Replace it with a real file from `tools/canonical/.ssh/config`
      before `make stow`, or every ssh host on that box stops resolving.
- [ ] Bootstrap: copy `tools/canonical/.ssh/config` to `~/.ssh/config` (mode 600) when absent, never
      overwriting an existing one. Keep the `Include` first — ssh is first-match-wins.
- [ ] `~/.gitconfig` `includeIf` blocks point at `~/.ssh/id_shy` and `~/.ssh/id_ctrl`; neither key is on
      the mac, so a commit under those identities fails there. Decide whether to install them or scope
      the includes per-OS.

## Claude Code (~/.claude)
- [x] `settings.json` untracked from the `claude` package (Claude Code rewrites it live) — canonical
      copy kept in `tools/canonical/.claude/settings.json` (`afa7977`, relocated in `9d0a014`).
- [x] Curate the canonical copy down to real prefs (`9d0a014`, 203 → 51 lines).
- [ ] Bootstrap: apply `tools/canonical/.claude/settings.json` on a fresh machine by **merging** into
      `~/.claude/settings.json` (`jq -s '.[0] * .[1]'`), never overwriting — Claude Code owns that file
      at runtime. Keep the canonical copy free of `//` comments so `jq` can parse it. The `statusLine`
      now points at `~/.claude/statusline.sh`, which the `claude` package stows — nothing extra to
      install, but it needs `bash` 5+ and `jq` on `PATH`.
