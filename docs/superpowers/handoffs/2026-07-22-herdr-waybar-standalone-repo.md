# Handoff: extract herdr-agents into a standalone repo

**Date written:** 2026-07-22
**For:** a future session with zero context.
**Goal:** turn the waybar "herdr agent status" element (currently living inside
this dotfiles repo) into a standalone, installable, shareable repo at
**`~/dev/phillhood/herdr-waybar`**.

---

## 0. Read these first (in order)

1. This document.
2. Memory notes (loaded automatically; if not, read
   `~/.claude/projects/-home-phill--dotfiles/memory/`):
   - `hyprland-lua-config.md` — this machine's Hyprland uses a **Lua config**;
     `hyprctl dispatch`/`keyword` and blur behave non-standard.
   - `herdr-agent-workspace-manager.md` — herdr CLI + socket-API facts.
3. The current implementation (source of truth — the tool works, on `main`
   @ `5375a2b`):
   - `waybar/.config/waybar/herdr-agents` (the script)
   - `waybar/.config/waybar/config.jsonc` (module/group defs)
   - `waybar/.config/waybar/style.css` (`#herdr-agents` rules)
   - `tests/waybar/test_herdr_agents.py` (11 stdlib-unittest tests)
4. The original design/plan docs — **STALE, read for history only** (they
   describe the first design that was superseded; see §3):
   - `docs/superpowers/specs/2026-07-22-herdr-waybar-agents-design.md`
   - `docs/superpowers/plans/2026-07-22-herdr-waybar-agents.md`

**Then confirm the open decisions in §7 with the user before building.** Use
superpowers:brainstorming for that, then writing-plans, then implement.

---

## 1. What the tool does (current shipped behavior)

A centered waybar element showing live status of every Claude Code (herdr)
agent. It is **one waybar module per status** (`blocked/idle/done/working/
unknown`), grouped into one card:
- Each status module shows `icon + count`, colored (Catppuccin), and **hides
  when its count is 0** (`hide-empty-text`). The whole card collapses when
  herdr has no agents.
- **Hover** a status → tooltip listing that status's agents (`workspace · task`).
- **Left-click** a status → focus one of its agents (the first, stable-sorted
  by `pane_id`) via `herdr agent focus`, then raise the herdr (ghostty) window.
- A hidden `notify` watcher **polls** `herdr agent list` every 1.5s and raises
  waybar signal `RTMIN+8` only when the agent state changes, so the status
  modules re-render (no busy timer on the modules themselves).

Script subcommands: `status <name>`, `focus-status <name>`, `notify`.

## 2. Files that make it up (in dotfiles today)

| file | role |
|---|---|
| `waybar/.config/waybar/herdr-agents` | the Python script (stdlib only, ~200 lines) |
| `waybar/.config/waybar/config.jsonc` | `group/herdr-agents` in `modules-center` + 6 module defs (`custom/herdr-agents-notify` + `custom/herdr-{blocked,idle,done,working,unknown}`) |
| `waybar/.config/waybar/style.css` | `#herdr-agents` in the shared card list + its own rule (`alpha(@base,0.95)`, padding on child modules so the card collapses when empty) |
| `tests/waybar/test_herdr_agents.py` | 11 tests: `status_of`, `stable_sort`, `agent_line`, `status_output`, `state_signature`, `pick_herdr_window` |

Not part of the tool: a Hyprland **blur layerrule** for waybar lives in
`hypr/.config/hypr/hyprland.lua` (frosted glass behind the bar). That is
compositor config, out of scope for the standalone repo — but the README
should mention blur is an optional per-compositor extra.

## 3. What changed from the original spec/plan (they are stale)

- Single "counts" module + `walker` picker + right-click most-urgent → **one
  module per status**, click focuses a matching agent, **no walker**.
- "Event-driven `events.subscribe`" → **1.5s poll**. herdr's
  `pane.agent_status_changed` events are **per-pane** (require a `pane_id`);
  there is no global "any agent changed" subscription, so the original `watch`
  was silently reconnect-polling. Polling `agent list` is the honest approach.
- Placement right-of-tray → **centered** (`modules-center`).
- Window focus: stock `hyprctl dispatch focuswindow address:<addr>` **does not
  work on this box** (Lua config) — it uses `hl.dsp.focus({window="address:
  <addr>"})`. **A stock-Hyprland user needs the stock form.** (See §6.)

## 4. Reusable core vs. personal bits (parameterize these for portability)

**Reusable as-is** (the whole point of extracting): `status_of`, `stable_sort`,
`status_output`, `state_signature`, `agent_line`, `pango_escape`,
`fetch_agents`, `pick_herdr_window`, `raise_herdr_window`, `focus_agent`,
`nudge`, `cmd_status/focus_status/notify`, `main` dispatch.

**Personal — move to a clear config surface** (CONFIG block + env and/or a
config file; decide in §7):
| thing | current value | why personal |
|---|---|---|
| `ICONS` | nerd-font MD glyphs (`\U000F009A` etc.) | font/taste — ship neutral defaults, document swapping |
| `COLORS` | Catppuccin Macchiato hexes | theme |
| `SIGNAL` | `8` | must not collide with other waybar modules |
| `POLL_SECONDS` | `1.5` | preference |
| `GHOSTTY_CLASS`/`HERDR_WINDOW_TITLE` | `com.mitchellh.ghostty` / `herdr` | which terminal hosts herdr |
| window-focus command | Hyprland **Lua** `hl.dsp.focus({window="address:%s"})` | compositor-specific — **default to stock hyprland**, make the Lua form and other compositors configurable |

## 5. Proposed standalone repo layout

```
~/dev/phillhood/herdr-waybar/
  herdr-waybar              # the generalized script (keep subcommands)
  README.md                # what/why, screenshot/gif, install, config, waybar snippet, blur note
  install.sh               # symlink (or copy) herdr-waybar -> ~/.local/bin/
  examples/
    config.jsonc           # copy-paste waybar group + module defs
    style.css              # copy-paste CSS (neutral palette)
  tests/
    test_herdr_waybar.py   # ported tests
  LICENSE                  # ask user (MIT?)
  # later, once proven: PKGBUILD for AUR (`paru -S herdr-waybar`)
```

## 6. Generalization tasks (once decisions in §7 are settled)

1. Copy the script; optionally rename `herdr-agents` → `herdr-waybar` (keep
   subcommands `status`/`focus-status`/`notify`).
2. Consolidate personal values into a documented CONFIG block; add override via
   env vars and/or `~/.config/herdr-waybar/config.json` (mechanism = §7).
3. **Window focus:** default to stock `["hyprctl","dispatch","focuswindow",
   "address:"+addr]`; expose a configurable command/template so Lua-config
   Hyprland (`hl.dsp.focus({window="address:"+addr})`) and non-Hyprland
   compositors work. Document both.
4. Neutral default icons/colors; README section on swapping to a theme.
5. Port tests (update the import path / module name).
6. `install.sh`: symlink `herdr-waybar` into `~/.local/bin` (matches how
   `herdr` itself is installed). Print the waybar config/CSS to paste.
7. README: install, config, the waybar `group` + per-status module snippet, the
   `signal`/poll model, and the optional compositor blur layerrule.
8. (Defer) PKGBUILD for AUR until the tool has been used a while.

## 6b. Migrate the dotfiles to consume it (second pass, after the repo exists)

- Install `herdr-waybar` to `~/.local/bin`.
- In dotfiles `config.jsonc`, change the module `exec`/`on-click` paths from
  `~/.config/waybar/herdr-agents` to `herdr-waybar` (PATH) — mirrors how herdr
  itself is a PATH binary + personal config.
- Keep personal CSS/colors/icons in dotfiles via the config override.
- Decide: remove the vendored `waybar/.config/waybar/herdr-agents` +
  `tests/waybar/test_herdr_agents.py` from dotfiles (now upstream), or keep a
  thin local override. Commit the migration separately.

## 7. Open decisions — confirm with the user BEFORE building

1. Repo name/location: `~/dev/phillhood/herdr-waybar`?
2. Config mechanism: CONFIG block only, env vars, or a config file?
3. Install: `install.sh` only now, or also an AUR PKGBUILD?
4. Window-focus generalization scope: hyprland (stock + lua) only, or also
   sway/river/generic command template?
5. License (MIT?).
6. Keep only the per-status display, or also ship the per-agent-icons variant
   (discussed but not chosen) as an optional mode?
7. Multi-agent status click: keep "focus the first agent", or add
   cycle-through-on-repeat-click?
8. After extraction, remove the vendored copy from dotfiles and point config at
   the PATH binary (recommended), or keep vendoring?

## 8. Environment gotchas (do NOT rediscover these)

- **This Claude session runs inside herdr.** Do NOT run `focus-status`,
  `herdr agent focus <other>`, or `hl.dsp.focus` against a *different* agent
  during dev — it yanks the user's window/pane. Test focus against the current
  session's own `terminal_id` (a no-op, safe), and ask the user to confirm
  visuals. `pgrep`/process checks can false-match your own command line — match
  by full path or `ps --ppid <waybar>`.
- **Hyprland Lua config:** `hyprctl dispatch <x>` → `hl.dispatch(<x>)`;
  `hyprctl keyword` is disabled (edit file + `hyprctl reload`); blur strength is
  global-only. Layer rules: `hl.layer_rule{match="waybar", blur=true,
  ignore_alpha=…}`; a new layer rule needs waybar to **re-map** (`pkill -x
  waybar`; a respawn loop restarts it), not just SIGUSR2. See the memory note.
- **herdr socket API:** request `id` must be a **string**; status events are
  per-pane (poll, don't subscribe). See the memory note.
- **Deploy in dotfiles:** the script symlinks into `~/.config/waybar/` via GNU
  stow (`cd ~/.dotfiles && stow -R --no-folding waybar`). Waybar reload:
  `pkill -SIGUSR2 waybar`.
- **Fonts:** MesloLGS Nerd Font (waybar + ghostty). Glyph codepoints were
  verified against the font cmap; keep them as `\U000F….` escapes.

## 9. Suggested next-session workflow

brainstorming (confirm §7) → writing-plans → implement in
`~/dev/phillhood/herdr-waybar` (own git repo; consider a worktree) → verify
tests → then the §6b dotfiles migration as a separate change. The current
dotfiles implementation is the reference — copy from it, don't reinvent.
