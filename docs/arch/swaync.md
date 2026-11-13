# swaync

Notification daemon, started from Hyprland's autostart. Its own stow package:
`swaync/.config/swaync/{config.json,style.css,notify-profile.py}`. Themed to the same
Catppuccin Macchiato palette as waybar. See [`hyprland.md`](hyprland.md) for the layer
rules and the fullscreen-aware popup monitor switching.

Reload: `swaync-client -R` for config, `-rs` for CSS. Layer-shell settings need a
full restart (`pkill swaync; swaync &`).

## Click-to-focus and the home/work tag

Two halves, both in `notify-profile.py`, which lives in the swaync stow package
and is started from Hyprland's autostart next to swaync.

**Tagging (daemon mode).** swaync has no per-notification styling hook -- the only
CSS classes it adds are `low`/`normal`/`critical` -- so the tag is written into the
notification itself. The daemon is a D-Bus *monitor* (`BecomeMonitor`): it sees
each `Notify` call and its reply, resolves the sender's PID with
`GetConnectionUnixProcessID`, walks parent PIDs until one owns a Hyprland window,
and reads the profile from that window's workspace (>100 is work). It then
re-sends the notification with `replaces_id` set to the original ID, a coloured
`● home`/`● work` prefix on the body (profile border colours), and two hints:
`x-hypr-profile` and `x-hypr-window` (the window address).

Keeping the ID is what makes this safe: `ActionInvoked` is a broadcast signal
filtered by ID, so the app's own default action and buttons still work.

If no window is found by PID it falls back to matching the app name or
`desktop-entry` against window classes. If the candidates span both profiles
(one Ghostty process owns windows on both) the notification is left untagged.

**herdr notifications** arrive from Ghostty (`[ui.toast] delivery = "terminal"`),
with an empty app name, summary `Ghostty`, and body
`<agent> <status>: <workspace label> · <workspace number>`. One Ghostty process owns
windows on both profiles, so PID resolution can't place them. Instead the daemon
looks the label and number up in each running herdr session (`herdr session list`,
`workspace list`): the `work` session is the work profile, anything else home. It
picks the agent in that workspace whose status matches (`finished` → `done`, else
`blocked`) and adds `x-herdr-session`/`-workspace`/`-pane` hints. The window is the
Ghostty window on that profile whose title ends in the session's focused
workspace label. A click runs `herdr --session <s> workspace focus` and
`agent focus` before raising the window.

**Focus (`notify-profile.py focus`).** A single swaync `scripts` entry with
`run-on: "action"` and `app-name: ".*"`. It focuses the `x-hypr-window` address,
else re-resolves from the `sender-pid` hint or app name, picking the most
recently focused match. It runs
`hyprctl eval "set_profile('<p>', function() hl.dispatch(hl.dsp.focus(...)) end)"`,
so a notification from the other profile switches profiles first; `set_profile`
runs the callback immediately when already on that profile.

`run-on: "action"` scripts fire on a body click **even when the notification
declares no actions** (RuneLite sends `array [ ]`; check with
`dbus-monitor "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"`).

### Where this breaks

- **The tag is a replace, so it can flash.** The original renders first, then is
  replaced a few ms later. If the app closes the notification inside that window,
  the replace re-creates it.
- **Untagged means unresolved**, not broken: script senders (`notify-send` from a
  keybind) have no window ancestor.
- **The window address hint goes stale** if the window closes; focus then falls
  back to PID/name resolution, and does nothing if that finds nothing.
- **Only the first matching script runs** per `run-on` type, so any new
  `run-on: action` entry must go above `focus-sender` and replaces it for those
  apps.
- **It fires in the control center too**, where `hide-on-action: true` also
  closes the panel.
- **A failing script announces itself as a notification** (`script-fail-notify`
  default). The focus mode exits 0 when it finds nothing so this stays quiet.
- **The monitor's message filter must pass through outgoing messages and replies
  addressed to itself.** Returning `None` for those drops the `BecomeMonitor`
  call itself and the daemon sits idle forever. `BecomeMonitor` must also be
  async: a `call_sync` holds the GIL while Gio's worker thread needs it to run
  the filter, which deadlocks.
- **If the daemon dies, notifications just go untagged.** Click-to-focus still
  works through the fallbacks.

## Other couplings worth knowing

- **Popup geometry is two coupled numbers.** `notification-window-width` (480) and
  the popup left margin (62px) must sum with the 416px card and 2px right margin,
  or the card drifts off the window edge it is aligned to. The extra width exists
  only to give the drop shadow room to render instead of being clipped at the
  surface edge.
- **Popup alignment targets a tiled window's edge**: `reserved [0, 38, 0, 0]` plus
  `gaps_out = 2` puts that at y 40 / x 2558 on DP-1. The layer surface already
  respects the exclusive zone, so the margins are just the 2px gap.
- **`:last-child` does not mean "the bottom notification".** Each popup row is
  wrapped in its own container, so `:last-child` matches every row. A bottom
  margin set there spaces the whole stack apart.
- **Chrome belongs on `.notification`, never `.notification-background`** -- the
  latter is the row's padding wrapper. Styling it draws a second box around the
  card and strands the close button outside it. The same applies to
  `.notification-row:focus` and `.notification-group:focus`, whose stock fills
  render as square blocks behind the rounded cards.
- **Stock selectors are long, so short overrides silently lose.** Several rules
  here use the full stock path purely to win on specificity.
- **`control-center-height: -1` needs `vexpand: false`** on the notifications
  widget. With `vexpand: true` the scroller claims all space and reports a small
  minimum, so "fit to content" resolved to a stubby panel that scrolled. The
  popup window template sets `propagate-natural-height`; the control center's
  does not.
- **The scrollbar is hidden entirely** (`opacity: 0`, `min-width: 0`). It forced
  an asymmetric right gutter. Wheel scrolling still works.
- **Sender timeouts win.** `timeout: 8` only applies when the sender passes `-1`.
  RuneLite sends `expire_timeout: 10000`, so its notifications last 10s.
- **The group header icon comes from `app_icon`, the card image from the
  `image-path` hint.** RuneLite sends an empty `app_icon`, so the group header
  falls back to a generic glyph while the cards show the real logo. Not fixable
  in CSS.
- **Only one group expands at a time.** swaync tracks a single `expanded-group`
  property in `notificationGroup/expandableGroup`; there is no config for it.
  Turning `notification-grouping` off is the only way to see everything at once.
