#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

PROFILE_COLORS = {"home": "#cba6f7", "work": "#89b4fa"}
HINT_PROFILE = "x-hypr-profile"
HINT_WINDOW = "x-hypr-window"
HINT_HERDR_SESSION = "x-herdr-session"
HINT_HERDR_WORKSPACE = "x-herdr-workspace"
HINT_HERDR_PANE = "x-herdr-pane"


def clients():
    try:
        out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        return json.loads(out)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []


def profile_of(window):
    try:
        n = int(window["workspace"]["name"])
    except (KeyError, TypeError, ValueError):
        return None
    return "work" if n > 100 else "home"


def parent_pid(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except (OSError, IndexError, ValueError):
        return 0


def norm(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())


def candidates(windows, pid, app_name, desktop_entry):
    seen = set()
    while pid > 1 and pid not in seen:
        seen.add(pid)
        found = [w for w in windows if w.get("pid") == pid]
        if found:
            return found
        pid = parent_pid(pid)
    names = [n for n in (norm(desktop_entry), norm(app_name)) if len(n) >= 3]
    return [w for w in windows if any(n in norm(w.get("class")) for n in names)]


def most_recent(windows):
    return min(windows, key=lambda w: w.get("focusHistoryID", 1 << 30))


def hint_str(name):
    return os.environ.get("SWAYNC_HINT_" + name.upper().replace("-", "_"), "").strip("'\"")


def herdr(session, *args):
    try:
        out = subprocess.run(["herdr", "--session", session, *args], capture_output=True, text=True, timeout=2).stdout
        return json.loads(out).get("result", {})
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, AttributeError):
        return {}


def herdr_sessions():
    try:
        out = subprocess.run(["herdr", "session", "list"], capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    return [line.split()[0] for line in out.splitlines()[1:] if line.split()[1:2] == ["running"]]


def herdr_target(body):
    m = re.match(r"^(\S+) (.+?): (.+) · (\d+)$", body or "")
    if not m:
        return None
    _agent, status, label, number = m.groups()
    for session in herdr_sessions():
        workspaces = herdr(session, "workspace", "list").get("workspaces", [])
        ws = next((w for w in workspaces if w.get("label") == label and str(w.get("number")) == number), None)
        if ws is None:
            continue
        agents = [a for a in herdr(session, "agent", "list").get("agents", []) if a.get("workspace_id") == ws["workspace_id"]]
        wanted = {"done"} if status == "finished" else {"blocked"}
        matching = [a for a in agents if a.get("agent_status") in wanted] or (agents if len(agents) == 1 else [])
        focused = next((w["label"] for w in workspaces if w.get("focused")), None)
        return {
            "session": session,
            "profile": "work" if session == "work" else "home",
            "workspace": ws["workspace_id"],
            "pane": matching[0]["pane_id"] if len(matching) == 1 else "",
            "title": focused,
        }
    return None


def herdr_window(windows, target):
    ghostty = [w for w in windows if w.get("class") == "com.mitchellh.ghostty" and profile_of(w) == target["profile"]]
    titled = [w for w in ghostty if target["title"] and w.get("title", "").endswith(": " + target["title"])]
    return most_recent(titled or ghostty) if ghostty else None


def focus():
    session = hint_str(HINT_HERDR_SESSION)
    if session:
        herdr(session, "workspace", "focus", hint_str(HINT_HERDR_WORKSPACE))
        if hint_str(HINT_HERDR_PANE):
            herdr(session, "agent", "focus", hint_str(HINT_HERDR_PANE))

    windows = clients()
    address = hint_str(HINT_WINDOW)
    target = next((w for w in windows if w.get("address") == address), None)
    if target is None:
        try:
            pid = int(hint_str("sender-pid") or 0)
        except ValueError:
            pid = 0
        found = candidates(windows, pid, os.environ.get("SWAYNC_APP_NAME"), os.environ.get("SWAYNC_DESKTOP_ENTRY"))
        if len({profile_of(w) for w in found}) != 1:
            return
        target = most_recent(found)

    dispatch = f"hl.dispatch(hl.dsp.focus({{ window = 'address:{target['address']}' }}))"
    profile = profile_of(target)
    if profile:
        code = f"set_profile('{profile}', function() {dispatch} end)"
    else:
        code = dispatch
    subprocess.run(["hyprctl", "eval", code], capture_output=True)


class Tagger:
    def __init__(self, loop):
        self.loop = loop
        self.out = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.pending = {}
        address = Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION, None)
        self.monitor = Gio.DBusConnection.new_for_address_sync(
            address,
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None,
            None,
        )
        self.monitor.add_filter(self.on_message)
        self.monitor.call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus.Monitoring",
            "BecomeMonitor",
            GLib.Variant(
                "(asu)",
                (
                    [
                        "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
                        "type='method_return'",
                    ],
                    0,
                ),
            ),
            None,
            Gio.DBusCallFlags.NONE,
            -1,
            None,
            self.on_monitoring,
        )

    def on_monitoring(self, conn, result):
        try:
            conn.call_finish(result)
        except GLib.Error as e:
            print(f"BecomeMonitor failed: {e.message}", file=sys.stderr)
            self.loop.quit()

    def on_message(self, conn, msg, incoming):
        if not incoming or msg.get_destination() == conn.get_unique_name():
            return msg
        kind = msg.get_message_type()
        if kind == Gio.DBusMessageType.METHOD_CALL:
            if msg.get_sender() != self.out.get_unique_name() and msg.get_signature() == "susssasa{sv}i":
                self.pending[(msg.get_sender(), msg.get_serial())] = msg.get_body()
        elif kind == Gio.DBusMessageType.METHOD_RETURN:
            args = self.pending.pop((msg.get_destination(), msg.get_reply_serial()), None)
            if args is not None and msg.get_signature() == "u":
                sender = msg.get_destination()
                nid = msg.get_body().unpack()[0]
                GLib.idle_add(self.tag, sender, nid, args)
        return None

    def sender_pid(self, sender):
        try:
            return self.out.call_sync(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "GetConnectionUnixProcessID",
                GLib.Variant("(s)", (sender,)),
                GLib.VariantType("(u)"),
                Gio.DBusCallFlags.NONE,
                -1,
                None,
            ).unpack()[0]
        except GLib.Error:
            return 0

    def tag(self, sender, nid, args):
        app_name = args.get_child_value(0).get_string()
        app_icon = args.get_child_value(2).get_string()
        summary = args.get_child_value(3).get_string()
        body = args.get_child_value(4).get_string()
        actions = args.get_child_value(5)
        hints = args.get_child_value(6)
        timeout = args.get_child_value(7).get_int32()

        hint_map = {hints.get_child_value(i).get_child_value(0).get_string(): hints.get_child_value(i).get_child_value(1)
                    for i in range(hints.n_children())}
        if HINT_PROFILE in hint_map:
            return False

        desktop_entry = hint_map.get("desktop-entry")
        desktop_entry = desktop_entry.get_variant().get_string() if desktop_entry else None
        windows = clients()
        extra = {}
        herdr_hit = herdr_target(body) if desktop_entry == "com.mitchellh.ghostty" else None
        if herdr_hit:
            profile = herdr_hit["profile"]
            window = herdr_window(windows, herdr_hit)
            extra = {
                HINT_HERDR_SESSION: herdr_hit["session"],
                HINT_HERDR_WORKSPACE: herdr_hit["workspace"],
                HINT_HERDR_PANE: herdr_hit["pane"],
            }
        else:
            found = candidates(windows, self.sender_pid(sender), app_name, desktop_entry)
            profiles = {profile_of(w) for w in found}
            if len(profiles) != 1 or None in profiles:
                return False
            profile = profiles.pop()
            window = most_recent(found)
        if window:
            extra[HINT_WINDOW] = window["address"]
        extra[HINT_PROFILE] = profile

        builder = GLib.VariantBuilder.new(GLib.VariantType("a{sv}"))
        for i in range(hints.n_children()):
            builder.add_value(hints.get_child_value(i))
        for key, value in extra.items():
            builder.add_value(GLib.Variant("{sv}", (key, GLib.Variant("s", value))))

        label = f"<b><span foreground='{PROFILE_COLORS[profile]}'>● {profile}</span></b>"
        params = GLib.Variant.new_tuple(
            GLib.Variant("s", app_name),
            GLib.Variant("u", nid),
            GLib.Variant("s", app_icon),
            GLib.Variant("s", summary),
            GLib.Variant("s", f"{label}  {body}" if body else label),
            actions,
            builder.end(),
            GLib.Variant("i", timeout),
        )
        self.out.call(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "Notify",
            params,
            None,
            Gio.DBusCallFlags.NONE,
            -1,
            None,
            None,
        )
        return False


def main():
    if sys.argv[1:] == ["focus"]:
        focus()
        return
    loop = GLib.MainLoop()
    tagger = Tagger(loop)
    tagger.monitor.connect("closed", lambda *_: loop.quit())
    loop.run()


if __name__ == "__main__":
    main()
