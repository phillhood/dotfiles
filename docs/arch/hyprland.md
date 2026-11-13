# Hyprland config

`hypr/.config/hypr/hyprland.lua`, Hyprland 0.56's Lua config (`hl` API, stubs at
`/usr/share/hypr/stubs/hl.meta.lua`). This file holds the *why* behind the
non-obvious lines there; the config itself stays comment-free.

## Autostart

### Waybar supervisor

Waybar is launched by a bash supervisor loop, not a bare `exec_cmd`. Waybar
SIGSEGVs when it races Hyprland at boot, so the loop respawns it with a 1→8s
backoff that resets after a healthy ≥10s run. The leading `pkill -x waybar`
guarantees a single instance.

The supervisor passes `-c ~/.config/waybar/bars.jsonc`. That file is a multi-bar
array — one object per output — and exists only so the cava widget can differ
per monitor; see [`waybar.md`](waybar.md).

- Reload config/style: `killall -SIGUSR2 waybar`
- Full restart: `killall waybar` (the supervisor respawns it)
- Never launch waybar by hand — it bypasses the supervisor, and you end up with
  two bars.

### Wallpaper watchdog

The `awww` line waits for the daemon's socket, sets both monitors, then polls
every 2s and re-applies whenever `awww query` reports a monitor fell back to a
solid `color:` — which happens on DPMS/VRR wakeups.

### xembedsniproxy

`sleep 2 && xembedsniproxy` — it's an X11 client, so it must start after
Xwayland is up. Too early and Wine/Battle.net tray icons are orphaned.

## Environment

`ELECTRON_OZONE_PLATFORM_HINT=auto` is only a *hint*. Electron apps ignore even
an explicit `wayland` unless `XDG_SESSION_TYPE=wayland` is also in the app's
environment, so anything spawning GUI apps must inherit the full session env.

## Window rules

### `hide-wine-tray-bar`

xembedsniproxy's XEmbed container is a real 32x32 X11 window with a solid black
background, one per proxied Wine tray icon. On click, xembedsniproxy *moves* it
under the cursor on purpose so the synthetic click lands on Wine's icon — so it
has to stay mapped and clickable. Hidden with `opacity = 0.0` rather than
unmapped, and `no_blur` stops the blur layer from re-revealing it.

Matched on `class = "^xembedsniproxy$"`, which requires **xembedsniproxy ≥
6.7.2** — earlier versions set no WM_CLASS on the container and the rule
silently stops matching. The previous matcher (empty class + empty title) also
caught native X11 override-redirect popups such as Electron's `Menu.popup()`
and dismissed them instantly; an exact class match cannot.

### WoW and Battle.net

Both run under Wine/Proton with class `steam_app_default` — only the title
tells them apart, so every rule and window lookup must match on title too.

- `wow-fullscreen` forces real fullscreen on `^World of Warcraft$` so it gets
  the whole monitor rather than the tiled usable area (shrunk by waybar's
  exclusive zone and gaps). Without it, windowed-fullscreen fights the tiler
  and the window snaps endlessly.
- Battle.net is **deliberately unruled** and opens on whatever workspace is
  active. It used to carry `workspace = "name:WoW"`; because that assignment is
  not silent, every time the launcher mapped a window it dragged the view to
  the WoW workspace mid-task.
- `SUPER+V` (float) and `SUPER+F` (fullscreen) both no-op on WoW: it manages
  its own windowed-fullscreen, and toggling the compositor's makes it fight the
  tiler and snap or break.
- `SUPER+grave` focuses WoW if running, else the Battle.net window (by object,
  so any workspace works), else focuses the WoW workspace and launches the
  Lutris game — the launcher lands there as the active workspace, not by rule.

## Layer rules

`waybar-blur` puts frosted-glass blur behind waybar's semi-transparent module
cards so text stays readable over busy windows. `ignore_alpha = 0.4` keeps the
blur off the fully-transparent gaps between modules, so only the cards blur and
text/icons render sharp on top.

`swaync-blur` and `swaync-popup-blur` do the same for the notification control
center and popup windows, matching the waybar treatment.

## Notifications

The daemon is swaync (started from Autostart). Its own config is the `swaync`
stow package -- see [`swaync.md`](swaync.md), which covers the click-to-focus workaround
for apps that register no default action, and the geometry couplings in the
stylesheet. The waybar bell is `custom/swaync`: left-click opens the control
center, right-click toggles DND.

### Fullscreen-aware popup output

`sync_noti_monitor` moves popups off the main monitor whenever its active
workspace has a fullscreen window, so a game never eats a notification. It reads
the fullscreen state from `hl.get_monitor(main_mon).active_workspace` and calls
`swaync-client --change-noti-monitor`, hooked to `window.fullscreen`,
`window.close` and `workspace.active`.

The baseline lives in swaync's own `notification-window-preferred-output`
(`DP-1`), which is also what `--change-noti-monitor` reverts to on a swaync
config reload -- the next hook event re-corrects it.

Two known gaps: there is no sync at Hyprland start, so a fullscreen window
already up when swaync starts gets popups on `DP-1` until the next event; and
`window.move_to_workspace` is not hooked, so dragging a fullscreen window
between workspaces does not re-evaluate.

## Bindings

`F24` (Nuphy Air75 V3) toggles mute on the PipeWire *source*, because Discord
cannot grab global hotkeys under Wayland. It chirps on toggle since Discord's
own UI gives no feedback for an external mute.

Volume-up passes `-l 1.0` to cap at 100% and avoid software over-amplification.

Media binds are `locked = true` so they work on the lock screen; volume binds
are also `repeating = true` for key-repeat.

### Mic mute (`scripts/mic-mute.sh`)

`XF86AudioMicMute` and `F24` (Nuphy Air75 V3) both run this script rather than
calling `wpctl set-mute` inline. It toggles the default source, then verifies:

1. **The toggle took effect.** Reads mute state before and after; if unchanged,
   it fires a critical notification instead of a chime.
2. **The active port is a real mic.** If the port is an `iec958`/`spdif`
   digital input, the source is capturing silence regardless of mute state, so
   it warns instead of pretending success.

Otherwise it plays `device-removed.oga` on mute, `device-added.oga` on unmute.

The second check exists because of a failure seen on 2026-08-20: the QuadCast S
card had drifted onto the `input:iec958-stereo` profile. Its ALSA descriptor
advertises an S/PDIF capture port that nothing feeds, so the mic recorded pure
silence while `wpctl` reported the source healthy and unmuted. Mute toggling
worked fine on that profile — nothing surfaced the problem. Compounding it, the
`analog-input-mic` route had `"mute":true` persisted, so switching back to the
right profile still came up muted.

Recovery, if it happens again:

```
pactl set-card-profile alsa_card.usb-Kingston_HyperX_QuadCast_S_4100-00 input:analog-stereo
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
```

#### Why the profile is not pinned

`~/.config/wireplumber/wireplumber.conf.d/52-quadcast-profile.conf` sets
`device.profile.priority.rules` for the card, but this is only a *floor*, not a
pin. WirePlumber 0.5's `select-profile` hooks run in the order
`find-stored-profile` -> `find-preferred-profile` -> `find-best-profile`, and
the first to set a profile wins. A value saved in
`~/.local/state/wireplumber/default-profile` therefore beats the rule — verified
by poisoning that file and restarting the service, which came back on iec958.

The rule still covers the case where no stored value exists (wiped state, fresh
machine, or the stored profile being unavailable at probe time).

Pinning it properly would mean `device.restore-profile = false` globally plus
explicit priority rules for every card, which would break the four cards
deliberately parked on `off` and stop pavucontrol changes persisting for
transient BT headsets. Not worth it — the script's port check turns a silent
failure into a loud one, which was the actual problem.

## Workspaces

Handled by the `split-monitor-workspaces` plugin (vendored clone under
`hypr/.config/hypr/plugins/`, gitignored, rebuilt by hyprpm). 10 workspaces,
capped at 3 on the portrait side monitor.

## Outstanding

`hyprland-gui.lua` is HyprMod-managed settings, required at the bottom of the
config. The intent is to fold those settings into `hyprland.lua` and drop
hyprmod.
