# herdr-agents waybar element — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a concise, event-driven waybar element that shows live status of every herdr (Claude Code) agent and lets a click jump to the relevant agent, raising the ghostty/herdr window in hyprland.

**Architecture:** One self-contained Python script (`herdr-agents`, stowed to `~/.config/waybar/`) with `render`/`watch`/`menu`/`urgent` subcommands. `watch` subscribes to herdr's unix-socket event stream (no polling) and prints a waybar JSON line on every change. Pure formatting/selection logic is factored into unit-tested functions; socket/subprocess I/O is thin. Wired into waybar via `config.jsonc` + `style.css`.

**Tech Stack:** Python 3 stdlib only (`socket`, `subprocess`, `json`); herdr CLI + socket API; hyprland `hyprctl`; `walker` dmenu picker; waybar custom module.

## Global Constraints

- Python 3 **stdlib only** — no pip dependencies. Tests use `unittest` (stdlib).
- Runtime tools assumed present on PATH: `herdr` (fallback `~/.local/bin/herdr`), `hyprctl`, `walker`.
- Font: **MesloLGS Nerd Font**. Glyph codepoints (verified in the font cmap), written as Python escapes: blocked `\U000F009A`, idle `\U000F0134`, done `\U000F05E0`, working `\U000F06A9`, unknown `\U000F02D7`.
- Colors: **Catppuccin Macchiato** — blocked `#ed8796`, idle `#a6da95`, done `#8bd5ca`, working `#c6a0f6`, unknown `#6e738d`.
- `AgentStatus` values: `idle | working | blocked | done | unknown`; any other/missing value → `unknown`.
- Urgency order (most-urgent first): `blocked, idle, done, working, unknown`.
- Script file (stowed): `waybar/.config/waybar/herdr-agents`, executable (`chmod +x`).
- Tests (NOT stowed): `tests/waybar/test_herdr_agents.py`. Run from repo root `~/.dotfiles`.
- Commit style (per user CLAUDE.md): simple lowercase messages, **no** `Co-Authored-By` trailer, **no** "Generated with" annotation.
- Keep all personal choices in the top `CONFIG` block for clean future extraction.

---

### Task 1: Pure render logic + script scaffold

**Files:**
- Create: `waybar/.config/waybar/herdr-agents`
- Test: `tests/waybar/test_herdr_agents.py`

**Interfaces:**
- Consumes: nothing.
- Produces (used by later tasks):
  - `status_of(agent: dict) -> str`
  - `sort_by_urgency(agents: list) -> list`
  - `count_by_status(agents: list) -> dict`
  - `pango_escape(text: str) -> str`
  - `render_text(agents: list) -> str`
  - `render_tooltip(agents: list) -> str`
  - `top_status(agents: list) -> str`
  - `build_output(agents: list) -> dict` → keys `text`, `tooltip`, `class`
  - `picker_lines(agents: list) -> list[str]`
  - `emit(out: dict) -> None`
  - `fetch_agents() -> list`
  - `resolve_socket_path() -> str`
  - `HERDR_BIN: str`, `ICONS: dict`, `COLORS: dict`, `SEP: str`, `URGENCY: list`
  - `main(argv: list) -> int` (dispatch dict; `render` handler wired here)

- [ ] **Step 1: Write the failing tests**

Create `tests/waybar/test_herdr_agents.py`:

```python
import importlib.util
import pathlib
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[2]
_SCRIPT = _ROOT / "waybar" / ".config" / "waybar" / "herdr-agents"
_spec = importlib.util.spec_from_file_location("herdr_agents", _SCRIPT)
ha = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ha)


def agent(status, ws="w1", title="t", tid="term_x"):
    return {
        "agent": "claude",
        "agent_status": status,
        "workspace_id": ws,
        "terminal_title_stripped": title,
        "terminal_id": tid,
    }


class TestPure(unittest.TestCase):
    def test_status_of_fallback(self):
        self.assertEqual(ha.status_of({"agent_status": "weird"}), "unknown")
        self.assertEqual(ha.status_of({}), "unknown")
        self.assertEqual(ha.status_of({"agent_status": "working"}), "working")

    def test_count_by_status(self):
        ags = [agent("working"), agent("working"), agent("idle")]
        self.assertEqual(ha.count_by_status(ags), {"working": 2, "idle": 1})

    def test_sort_by_urgency(self):
        ags = [agent("working"), agent("blocked"), agent("done"), agent("idle")]
        got = [ha.status_of(a) for a in ha.sort_by_urgency(ags)]
        self.assertEqual(got, ["blocked", "idle", "done", "working"])

    def test_render_text_order_and_nonzero(self):
        ags = [agent("blocked"), agent("working"), agent("working")]
        expected = (
            "<span color='#ed8796'>%s</span> 1"
            "%s"
            "<span color='#c6a0f6'>%s</span> 2"
        ) % (ha.ICONS["blocked"], ha.SEP, ha.ICONS["working"])
        self.assertEqual(ha.render_text(ags), expected)

    def test_render_text_empty(self):
        self.assertEqual(ha.render_text([]), "")

    def test_build_output_empty(self):
        out = ha.build_output([])
        self.assertEqual(out["text"], "")
        self.assertIn("empty", out["class"])

    def test_build_output_class_is_top_status(self):
        out = ha.build_output([agent("working"), agent("blocked")])
        self.assertEqual(out["class"], ["herdr-agents", "blocked"])

    def test_tooltip_escapes_pango(self):
        tip = ha.render_tooltip([agent("idle", title="a & b <x>")])
        self.assertIn("a &amp; b &lt;x&gt;", tip)

    def test_picker_lines(self):
        lines = ha.picker_lines([agent("working", ws="w5", title="Do thing")])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith(ha.ICONS["working"]))
        self.assertIn("w5", lines[0])
        self.assertIn("Do thing", lines[0])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Create the feature branch, then run tests to verify they fail**

Run:
```bash
cd ~/.dotfiles && git checkout -b herdr-waybar-agents
python3 tests/waybar/test_herdr_agents.py -v
```
Expected: ERROR — `herdr-agents` script does not exist yet (import/exec fails).

- [ ] **Step 3: Create the script with CONFIG + pure functions + render**

Create `waybar/.config/waybar/herdr-agents`:

```python
#!/usr/bin/env python3
"""herdr-agents - waybar element for Claude Code / herdr agent status.

Subcommands:
  watch    stream agent status to waybar (continuous exec, event-driven)
  menu     walker picker of all agents -> focus the chosen one
  urgent   focus the single most-urgent agent
  render   print one waybar JSON line and exit (debug / building block)

Self-contained: all personal choices live in the CONFIG block below, so this
script can later move to a standalone repo unchanged.
"""
import json
import os
import shutil
import socket
import subprocess
import sys
import time

# ----------------------------- CONFIG -----------------------------
# Urgency order, most-urgent first. Drives bar text order, tooltip/picker
# sort, `urgent`, and the CSS status class.
URGENCY = ["blocked", "idle", "done", "working", "unknown"]

# Nerd-font glyphs (MesloLGS Nerd Font), by codepoint to avoid paste rot.
ICONS = {
    "blocked": "\U000F009A",  # md-bell
    "idle":    "\U000F0134",  # md-check-bold
    "done":    "\U000F05E0",  # md-check-circle
    "working": "\U000F06A9",  # md-robot
    "unknown": "\U000F02D7",  # md-help-circle
}

# Catppuccin Macchiato.
COLORS = {
    "blocked": "#ed8796",  # red
    "idle":    "#a6da95",  # green
    "done":    "#8bd5ca",  # teal
    "working": "#c6a0f6",  # mauve
    "unknown": "#6e738d",  # overlay0
}

SEP = "  "  # gap between status groups in the bar text

HERDR_BIN = (os.environ.get("HERDR_BIN")
             or shutil.which("herdr")
             or os.path.expanduser("~/.local/bin/herdr"))

DEFAULT_SOCKET = os.path.expanduser("~/.config/herdr/herdr.sock")

PICKER_CMD = ["walker", "-d", "-i"]  # dmenu mode, prints selected index

GHOSTTY_CLASS = "com.mitchellh.ghostty"
HERDR_WINDOW_TITLE = "herdr"
# ------------------------------------------------------------------


def status_of(agent):
    s = agent.get("agent_status") or "unknown"
    return s if s in URGENCY else "unknown"


def sort_by_urgency(agents):
    order = {s: i for i, s in enumerate(URGENCY)}
    return sorted(agents, key=lambda a: order.get(status_of(a), len(URGENCY)))


def count_by_status(agents):
    counts = {}
    for a in agents:
        s = status_of(a)
        counts[s] = counts.get(s, 0) + 1
    return counts


def pango_escape(text):
    return (text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;"))


def render_text(agents):
    counts = count_by_status(agents)
    parts = []
    for s in URGENCY:
        n = counts.get(s, 0)
        if n:
            parts.append("<span color='%s'>%s</span> %d"
                         % (COLORS[s], ICONS[s], n))
    return SEP.join(parts)


def render_tooltip(agents):
    lines = []
    for a in sort_by_urgency(agents):
        s = status_of(a)
        ws = a.get("workspace_id", "?")
        title = (a.get("terminal_title_stripped") or "").strip()
        lines.append("%s %-7s  %s  %s" % (ICONS[s], s, ws, pango_escape(title)))
    return "\n".join(lines)


def top_status(agents):
    for s in URGENCY:
        if any(status_of(a) == s for a in agents):
            return s
    return "empty"


def build_output(agents):
    if not agents:
        return {"text": "", "tooltip": "", "class": ["herdr-agents", "empty"]}
    return {
        "text": render_text(agents),
        "tooltip": render_tooltip(agents),
        "class": ["herdr-agents", top_status(agents)],
    }


def picker_lines(agents):
    lines = []
    for a in sort_by_urgency(agents):
        s = status_of(a)
        ws = a.get("workspace_id", "?")
        title = (a.get("terminal_title_stripped") or "").replace("\n", " ").strip()
        lines.append("%s %s · %s · %s" % (ICONS[s], s, ws, title))
    return lines


def emit(out):
    sys.stdout.write(json.dumps(out) + "\n")
    sys.stdout.flush()


def fetch_agents():
    try:
        p = subprocess.run([HERDR_BIN, "agent", "list"],
                           capture_output=True, text=True, timeout=3)
        data = json.loads(p.stdout)
        return data.get("result", {}).get("agents", []) or []
    except Exception:
        return []


def resolve_socket_path():
    return os.environ.get("HERDR_SOCKET_PATH") or DEFAULT_SOCKET


def cmd_render():
    emit(build_output(fetch_agents()))


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "watch"
    handlers = {
        "render": cmd_render,
    }
    fn = handlers.get(cmd)
    if fn is None:
        sys.stderr.write("usage: herdr-agents {watch|menu|urgent|render}\n")
        return 2
    fn()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Then make it executable:
```bash
chmod +x ~/.dotfiles/waybar/.config/waybar/herdr-agents
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd ~/.dotfiles && python3 tests/waybar/test_herdr_agents.py -v
```
Expected: `OK` — all tests pass.

- [ ] **Step 5: Smoke-test `render` against live herdr**

Run:
```bash
~/.dotfiles/waybar/.config/waybar/herdr-agents render
```
Expected: one line of valid JSON, e.g.
`{"text": "<span color='#c6a0f6'>...</span> 2", "tooltip": "...", "class": ["herdr-agents", "working"]}`
(If no agents are running: `{"text": "", "tooltip": "", "class": ["herdr-agents", "empty"]}`.)

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add waybar/.config/waybar/herdr-agents tests/waybar/test_herdr_agents.py
git commit -m "add herdr-agents waybar script with render logic"
```

---

### Task 2: Event-driven `watch` loop

**Files:**
- Modify: `waybar/.config/waybar/herdr-agents`

**Interfaces:**
- Consumes: `build_output`, `fetch_agents`, `resolve_socket_path`, `emit` (Task 1).
- Produces: `SUBSCRIBE: dict`, `cmd_watch()`; `watch` registered in `main` dispatch.

- [ ] **Step 1: Add the subscription payload and watch loop**

In `herdr-agents`, add after `cmd_render`:

```python
SUBSCRIBE = {
    "id": 1,
    "method": "events.subscribe",
    "params": {"subscriptions": [
        {"type": "pane.agent_status_changed"},
        {"type": "pane.agent_detected"},
        {"type": "pane.created"},
        {"type": "pane.closed"},
        {"type": "pane.exited"},
    ]},
}


def cmd_watch():
    backoff = 1.0
    while True:
        emit(build_output(fetch_agents()))  # show current state immediately
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(5)
                s.connect(resolve_socket_path())
                s.sendall((json.dumps(SUBSCRIBE) + "\n").encode())
                s.settimeout(None)
                stream = s.makefile("r")
                backoff = 1.0
                for line in stream:
                    if not line.strip():
                        continue
                    emit(build_output(fetch_agents()))
        except Exception:
            pass
        emit(build_output(fetch_agents()))  # connection lost -> refresh
        time.sleep(backoff)
        backoff = min(backoff * 2, 5.0)
```

- [ ] **Step 2: Register `watch` in the dispatch**

In `main`, change the `handlers` dict to include `watch`:

```python
    handlers = {
        "watch": cmd_watch,
        "render": cmd_render,
    }
```

- [ ] **Step 3: Verify existing unit tests still pass**

Run:
```bash
cd ~/.dotfiles && python3 tests/waybar/test_herdr_agents.py -v
```
Expected: `OK` (pure-function tests unaffected).

- [ ] **Step 4: Manually verify the event stream updates**

Run in a scratch terminal:
```bash
~/.dotfiles/waybar/.config/waybar/herdr-agents watch
```
Expected: prints an initial JSON line immediately, then stays running. In another herdr agent, trigger a status change (start a task / let it finish) and confirm a **new** JSON line appears within a moment reflecting the new counts. Then `herdr server stop` (or kill) — confirm the script keeps running, emits a line, and reconnects when herdr returns. Stop with Ctrl-C.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add waybar/.config/waybar/herdr-agents
git commit -m "add herdr-agents event-driven watch loop"
```

---

### Task 3: Window focus + `urgent` action

**Files:**
- Modify: `waybar/.config/waybar/herdr-agents`
- Modify: `tests/waybar/test_herdr_agents.py`

**Interfaces:**
- Consumes: `sort_by_urgency`, `fetch_agents`, `HERDR_BIN`, `GHOSTTY_CLASS`, `HERDR_WINDOW_TITLE` (Task 1).
- Produces:
  - `pick_herdr_window(clients: list) -> dict | None`
  - `raise_herdr_window() -> None`
  - `focus_agent(terminal_id: str) -> None`
  - `cmd_urgent()`; `urgent` registered in `main`.

- [ ] **Step 1: Write the failing test for window selection**

Add to `tests/waybar/test_herdr_agents.py` inside `TestPure` (or a new class):

```python
    def test_pick_herdr_window_prefers_title(self):
        clients = [
            {"title": "nvim", "class": "com.mitchellh.ghostty", "address": "0x1"},
            {"title": "herdr", "class": "com.mitchellh.ghostty", "address": "0x2"},
        ]
        self.assertEqual(ha.pick_herdr_window(clients)["address"], "0x2")

    def test_pick_herdr_window_falls_back_to_class(self):
        clients = [
            {"title": "nvim", "class": "com.mitchellh.ghostty", "address": "0x1"},
            {"title": "firefox", "class": "firefox", "address": "0x9"},
        ]
        self.assertEqual(ha.pick_herdr_window(clients)["address"], "0x1")

    def test_pick_herdr_window_none(self):
        self.assertIsNone(ha.pick_herdr_window([{"title": "x", "class": "y"}]))
```

- [ ] **Step 2: Run to verify failure**

Run:
```bash
cd ~/.dotfiles && python3 tests/waybar/test_herdr_agents.py -v
```
Expected: FAIL/ERROR — `pick_herdr_window` not defined.

- [ ] **Step 3: Implement focus + urgent**

In `herdr-agents`, add after `resolve_socket_path`:

```python
def pick_herdr_window(clients):
    for c in clients:
        if c.get("title") == HERDR_WINDOW_TITLE:
            return c
    for c in clients:
        if c.get("class") == GHOSTTY_CLASS:
            return c
    return None


def raise_herdr_window():
    try:
        p = subprocess.run(["hyprctl", "-j", "clients"],
                           capture_output=True, text=True, timeout=3)
        clients = json.loads(p.stdout)
    except Exception:
        return
    win = pick_herdr_window(clients)
    if win and win.get("address"):
        subprocess.run(["hyprctl", "dispatch", "focuswindow",
                        "address:%s" % win["address"]],
                       capture_output=True, text=True)


def focus_agent(terminal_id):
    if not terminal_id:
        return
    subprocess.run([HERDR_BIN, "agent", "focus", terminal_id],
                   capture_output=True, text=True)
    raise_herdr_window()


def cmd_urgent():
    agents = sort_by_urgency(fetch_agents())
    if agents:
        focus_agent(agents[0].get("terminal_id"))
```

Register `urgent` in `main` handlers:

```python
    handlers = {
        "watch": cmd_watch,
        "urgent": cmd_urgent,
        "render": cmd_render,
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd ~/.dotfiles && python3 tests/waybar/test_herdr_agents.py -v
```
Expected: `OK`.

- [ ] **Step 5: Manually verify `urgent` focuses an agent**

With at least one herdr agent running, from a different hyprland window run:
```bash
~/.dotfiles/waybar/.config/waybar/herdr-agents urgent
```
Expected: the ghostty/herdr window is raised and focused on the most-urgent agent's pane (blocked first, else idle/done/working).

- [ ] **Step 6: Commit**

```bash
cd ~/.dotfiles
git add waybar/.config/waybar/herdr-agents tests/waybar/test_herdr_agents.py
git commit -m "add herdr-agents focus and urgent-agent action"
```

---

### Task 4: Walker picker `menu`

**Files:**
- Modify: `waybar/.config/waybar/herdr-agents`

**Interfaces:**
- Consumes: `sort_by_urgency`, `fetch_agents`, `picker_lines`, `focus_agent`, `PICKER_CMD` (Tasks 1, 3).
- Produces: `cmd_menu()`; `menu` registered in `main`.

- [ ] **Step 1: Implement the picker menu**

In `herdr-agents`, add after `cmd_urgent`:

```python
def cmd_menu():
    agents = sort_by_urgency(fetch_agents())
    if not agents:
        return
    try:
        p = subprocess.run(PICKER_CMD, input="\n".join(picker_lines(agents)),
                           capture_output=True, text=True)
    except FileNotFoundError:
        return
    out = p.stdout.strip()
    if p.returncode != 0 or out == "":
        return
    try:
        idx = int(out)
    except ValueError:
        return
    if 0 <= idx < len(agents):
        focus_agent(agents[idx].get("terminal_id"))
```

Register `menu` in `main` handlers:

```python
    handlers = {
        "watch": cmd_watch,
        "menu": cmd_menu,
        "urgent": cmd_urgent,
        "render": cmd_render,
    }
```

- [ ] **Step 2: Verify unit tests still pass**

Run:
```bash
cd ~/.dotfiles && python3 tests/waybar/test_herdr_agents.py -v
```
Expected: `OK` (`picker_lines` already covered; menu I/O verified manually next).

- [ ] **Step 3: Manually verify the picker**

With agents running:
```bash
~/.dotfiles/waybar/.config/waybar/herdr-agents menu
```
Expected: `walker` opens listing every agent as `ICON status · workspace · title`, sorted blocked→idle→done→working. Selecting one raises the herdr window focused on that agent. Pressing Escape does nothing.

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add waybar/.config/waybar/herdr-agents
git commit -m "add herdr-agents walker picker menu"
```

---

### Task 5: Wire into waybar (`config.jsonc` + `style.css`)

**Files:**
- Modify: `waybar/.config/waybar/config.jsonc`
- Modify: `waybar/.config/waybar/style.css`

**Interfaces:**
- Consumes: the `herdr-agents` script (`watch`/`menu`/`urgent`).
- Produces: the visible bar element. No code interfaces.

- [ ] **Step 1: Add the module to `modules-right`**

In `config.jsonc`, replace the `modules-right` array (currently lines ~17-22):

```jsonc
  "modules-right": [
    "group/tray-box",
    "custom/herdragents",
    "group/system-box",
    "group/clock-box",
    "group/power-box"
  ],
```

(The bare `custom/herdragents` — not a group — so `hide-empty-text` collapses it entirely when no agents run.)

- [ ] **Step 2: Add the module definition**

In `config.jsonc` section (c), just before `// -- system: cpu / memory --` (near the `"cpu":` block), add:

```jsonc
  // -- herdr agents --
  "custom/herdragents": {
    "exec": "~/.config/waybar/herdr-agents watch",
    "return-type": "json",
    "format": "{}",
    "hide-empty-text": true,
    "tooltip": true,
    "on-click": "~/.config/waybar/herdr-agents menu",
    "on-click-right": "~/.config/waybar/herdr-agents urgent"
  },
```

- [ ] **Step 3: Add card chrome + padding in `style.css`**

In `style.css`, add `#custom-herdragents` to the shared "card" selector list (the block starting at `#launcher-box,` ~line 61):

```css
#launcher-box,
#workspaces-box,
#media-box,
#system-box,
#tray-box,
#clock-box,
#power-box,
#custom-herdragents,
#custom-cava {
```

Then append a new rule (e.g. after the `#tray-box ... #power-box` container block, ~line 168):

```css
/* Module: herdr agents */
#custom-herdragents {
  margin: 0px 4px 2px 2px;
  padding: 2px 11px;
  color: @fg;
  font-weight: 900;
  font-size: 14px;
}
```

- [ ] **Step 4: Reload waybar and verify**

Run:
```bash
pkill -SIGUSR2 waybar   # reload config+style; or restart waybar however you normally do
```
Expected:
- With agents running: a compact element appears on the right (before the system box) showing icon+count per status, colored, blocked first. Hovering shows the per-agent tooltip.
- Left-click opens the walker picker; selecting focuses that agent + raises the window.
- Right-click jumps to the most-urgent agent.
- With no agents: the element is fully hidden (no empty card).
- All five status glyphs render (no boxes).

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add waybar/.config/waybar/config.jsonc waybar/.config/waybar/style.css
git commit -m "wire herdr-agents into waybar config and styles"
```

---

## Self-Review

**Spec coverage:**
- Event-driven watch, no polling, reconnect → Task 2. ✓
- `herdr agent list` parsing / status counting → Task 1. ✓
- Counts-per-status display, urgency order, non-zero only, hidden when empty → Task 1 (`render_text`/`build_output`) + Task 5 (`hide-empty-text`). ✓
- Verified glyphs + Catppuccin colors → Task 1 CONFIG + Global Constraints. ✓
- Tooltip per-agent with pango escaping → Task 1. ✓
- Left-click walker picker + focus → Task 4. ✓
- Right-click most-urgent → Task 3. ✓
- `herdr agent focus` + `hyprctl` window raise (title→class fallback via clients JSON) → Task 3. ✓
- Placement right side before system-box → Task 5. ✓
- Self-contained Python, CONFIG block for extraction → Task 1. ✓
- Error handling (herdr down, bad JSON, walker cancelled) → Tasks 1-4 (`fetch_agents` try/except, watch reconnect, menu guards). ✓

**Placeholder scan:** none — every step has concrete code/commands.

**Type consistency:** `build_output`/`render_text`/`sort_by_urgency`/`focus_agent`/`picker_lines`/`pick_herdr_window` names and signatures are used identically across Tasks 1-5. `main` handlers dict is extended (not renamed) each task. ✓

**Note vs spec:** spec described a `group/agents-box`; plan uses a bare `custom/herdragents` module instead so `hide-empty-text` fully collapses it when idle — a refinement preserving the spec's intent (right side, hidden when empty).
