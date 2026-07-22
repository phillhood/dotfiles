# herdr-agents waybar element — design

**Date:** 2026-07-22
**Status:** approved design, pending implementation plan

## Goal

A concise waybar element that shows the live status of every Claude Code
(herdr) agent across all workspaces/spaces, and lets a click jump to the
relevant agent — both switching herdr's internal pane *and* raising the
ghostty window that hosts herdr, from anywhere in hyprland.

Built inside the `waybar` stow package now, but written self-contained so it
can later be lifted into a standalone `~/dev/phillhood/herdr-waybar` repo with
minimal effort (see "Extraction-friendliness").

## Context discovered

herdr (`~/.local/bin/herdr`, v0.7.4) is a terminal workspace manager for AI
coding agents with a unix-socket JSON-RPC API. Relevant capabilities:

- **`herdr agent list`** → JSON `{"result":{"agents":[...]}}`; each agent has
  `agent` (e.g. `"claude"`), `agent_status`, `focused`, `workspace_id` (e.g.
  `w5`), `tab_id`, `pane_id`, `terminal_id`, `terminal_title_stripped`, `cwd`.
  Already filtered to real agents (plain shells are excluded).
- **`AgentStatus` enum:** `idle | working | blocked | done | unknown`.
- **`herdr agent focus <target>`** — targets accept terminal ids, agent names,
  labels, and pane ids. Switches herdr's active pane/tab/workspace.
- **Event subscription** over the socket: JSON-RPC method **`events.subscribe`**
  with `params.subscriptions[].type`. Confirmed subscribable types include
  `pane.agent_status_changed`, `pane.agent_detected`, `pane.created`,
  `pane.closed`, `pane.exited`. The server keeps the connection open and pushes
  event envelopes — no polling needed.
- **Socket path:** `$HERDR_SOCKET_PATH` when set, else
  `~/.config/herdr/herdr.sock` (from `herdr status`).
- herdr's Claude integration hook only *links* a pane to a session id; the
  `working`/`idle`/`blocked` state is derived server-side from the PTY. So the
  event subscription — not Claude hooks — is the correct push channel.

Host window: herdr runs in a single ghostty window, hyprland
`class = com.mitchellh.ghostty`, `title = herdr`. Picker: `walker` 2.16.2
supports `-d/--dmenu` and `-i/--index`. Fonts (ghostty + waybar):
`MesloLGS Nerd Font`.

## Architecture

One self-contained Python script, `herdr-agents`, stowed to
`~/.config/waybar/herdr-agents`, with three subcommands:

| subcommand | invoked by | purpose |
|---|---|---|
| `watch` | waybar `exec` (continuous) | subscribe to events, print a waybar JSON line on every change |
| `menu` | `on-click` | walker picker of all agents → focus the chosen one |
| `urgent` | `on-click-right` | focus the single most-urgent agent |

Python (not bash) because the socket subscription + JSON handling is far
cleaner, and python3 is already a herdr dependency. A `CONFIG` block at the top
of the file isolates all personal choices (icons, colors, picker command,
window-focus command, socket path) so the logic below it stays generic.

### `watch` — event-driven, zero polling

1. Resolve socket path (`$HERDR_SOCKET_PATH` or `~/.config/herdr/herdr.sock`).
2. Print the initial state immediately (render from `herdr agent list`).
3. Connect to the socket, send
   `{"id":1,"method":"events.subscribe","params":{"subscriptions":[
   {"type":"pane.agent_status_changed"},{"type":"pane.agent_detected"},
   {"type":"pane.created"},{"type":"pane.closed"},{"type":"pane.exited"}]}}`.
4. Block reading newline-delimited event envelopes. On each event, re-read
   `herdr agent list`, re-render, print one waybar JSON line, and **flush**
   stdout (waybar continuous mode reads line-by-line).
5. On socket EOF/error (e.g. herdr server restart), print the hidden state
   (empty text — bar stays clean when herdr isn't running) and reconnect with
   capped backoff (e.g. 1s→5s).

Re-reading `agent list` on each event (rather than mutating in-memory state
from event payloads) keeps rendering simple and always correct; events are
infrequent so the extra socket round-trip is negligible.

### Render (shared by all subcommands)

Parse `.result.agents[]`, count by `agent_status`. Emit waybar JSON
`{"text":..,"tooltip":..,"class":[..]}` with `return-type:"json"`:

- **text** — for each status present (count > 0), in urgency order
  `blocked, idle, done, working, unknown`:
  `<span color='COLOR'>ICON</span> N`, space-joined (Pango markup, matching the
  existing modules). Empty string when no agents (module hides).
- **tooltip** — one line per agent:
  `ICON status  workspace_id  terminal_title_stripped`.
- **class** — `["herdr-agents", <most-urgent-status-present>]` for CSS hooks.

### Status → icon + color

Nerd-font codepoints verified present in `MesloLGSNerdFont-Regular.ttf` cmap.
Colors are Catppuccin Macchiato, matching the rest of the bar.

| status | meaning | glyph | codepoint | color |
|---|---|---|---|---|
| `blocked` | waiting on **you** (permission/question) | 󰂚 bell | `U+F009A` | `#ed8796` |
| `idle` | your turn — finished responding | 󰄴 check | `U+F0134` | `#a6da95` |
| `done` | task complete | 󰗠 check-circle | `U+F05E0` | `#8bd5ca` |
| `working` | running | 󰚩 robot | `U+F06A9` | `#c6a0f6` |
| `unknown` | state undetermined | 󰋗 help-circle | `U+F02D7` | `#6e738d` |

Urgency order (most-urgent first), used for text ordering, tooltip sort,
picker sort, and `urgent`: `blocked > idle > done > working > unknown`.

### `menu` — walker picker

1. `herdr agent list` → sort agents by urgency order.
2. Build one line per agent: `ICON status · workspace_id · title`.
3. Pipe lines to `walker -d -i` (dmenu, prints selected **index**).
4. Map the returned index back to that agent's `terminal_id`.
5. `herdr agent focus <terminal_id>`, then raise the herdr window (below).
6. No selection / picker cancelled → do nothing.

### `urgent` — direct focus

Pick the first agent in urgency order, `herdr agent focus` it, raise the
window. If no agents, no-op.

### Raising the herdr window in hyprland

After focusing an agent, both click paths run:

```
hyprctl dispatch focuswindow "title:^herdr$"   # primary
```

falling back to `class:com.mitchellh.ghostty` if the title match fails. This
brings ghostty forward and switches to its hyprland workspace, so a click from
a browser lands you in the right agent.

## Waybar wiring (`config.jsonc`)

Add module `custom/herdragents` and place it in a new `group/agents-box` on the
**right**, immediately before `group/system-box`:

```jsonc
"custom/herdragents": {
  "exec": "~/.config/waybar/herdr-agents watch",
  "return-type": "json",
  "format": "{}",
  "hide-empty-text": true,
  "tooltip": true,
  "on-click": "~/.config/waybar/herdr-agents menu",
  "on-click-right": "~/.config/waybar/herdr-agents urgent"
}
```

No `interval` (continuous `exec` / event-driven). No `signal`. Scroll: none
(per decision — left-click picker + right-click most-urgent only).

## Styling (`style.css`)

Add rules for `.herdr-agents` and the per-status classes
(`.herdr-agents.blocked`, `.idle`, `.done`, `.working`, `.unknown`) consistent
with existing module spacing/padding. Colors live inline in the Pango markup
(as elsewhere in this config); CSS handles padding and any
attention emphasis (e.g. subtle emphasis when `blocked`).

## Error handling

- **herdr not running / socket missing:** `watch` emits the hidden state
  (empty text) and retries connecting with backoff; `menu`/`urgent` no-op
  quietly.
- **`herdr agent list` fails / bad JSON:** treat as zero agents (hidden), log
  nothing to stdout beyond the waybar line.
- **walker missing/cancelled:** no-op.
- **stdout must be line-buffered/flushed** each render for waybar.

## Files

All within the `waybar` stow package:

- **new** `waybar/.config/waybar/herdr-agents` — Python, executable
- **edit** `waybar/.config/waybar/config.jsonc` — `custom/herdragents` module +
  `group/agents-box` before `group/system-box`
- **edit** `waybar/.config/waybar/style.css` — status classes

## Extraction-friendliness (future `~/dev/phillhood/herdr-waybar`)

To make a later lift clean:

- Single self-contained script, no hardcoded absolute paths (resolve socket and
  `herdr`/`hyprctl`/`walker` from PATH or a `CONFIG` block).
- All personal choices (icons, colors, picker command, window-focus command)
  isolated in the top `CONFIG` block with sensible neutral defaults.
- The window-raise command is a single configurable string, so a non-hyprland
  user can swap it.

When extracted: the script installs to `~/.local/bin/herdr-waybar`; dotfiles
keeps only the module config + CSS, which then call `herdr-waybar` from PATH
(mirroring how herdr itself is a PATH binary + personal config). AUR packaging
deferred until the tool is proven.

## Testing

- `herdr-agents watch` prints an initial JSON line, then a new line within a
  moment of an agent changing status / starting / exiting (verify by toggling a
  real agent).
- Output is valid waybar JSON; empty text when no agents.
- `herdr-agents menu` lists all agents, and selecting one focuses that agent's
  pane and raises the ghostty window.
- `herdr-agents urgent` focuses the most-urgent agent.
- With herdr stopped: `watch` stays alive and reconnects; `menu`/`urgent`
  no-op.
- All five status glyphs render in `MesloLGS Nerd Font`.

## Decisions (settled)

- Interaction: walker picker (left-click) + most-urgent (right-click); no scroll.
- Display: counts per status, non-zero only, urgency-ordered; hidden when empty.
- Refresh: event subscription, no polling; reconnect on drop.
- Placement: right side, before `group/system-box`.
- Language: Python (single self-contained script).
- Structure: in dotfiles now, designed for later extraction.
