-- Hyprland config

-- Theme: Catppuccin Mocha
local colors = require("themes.catppuccin-mocha")

--------------------
---- MONITORS   ----
--------------------

local main_mon = "DP-1" -- main monitor (landscape)
local side_mon = "DP-2" -- side monitor (portrait)

hl.monitor({ output = main_mon, mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = side_mon, mode = "preferred", position = "-1440x-520", scale = 1, transform = 3, vrr = 0 })
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Dedicated workspace for World of Warcraft, pinned to the main monitor.
hl.workspace_rule({ workspace = "name:WoW", monitor = main_mon })

--------------------
---- ENV VARS   ----
--------------------

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- Electron reads this only as a HINT: even the explicit value "wayland" is ignored
-- unless XDG_SESSION_TYPE=wayland is also in the app's environment. So anything that
-- launches GUI apps must inherit the full session env, not just this var.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

--------------------
---- AUTOSTART  ----
--------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	-- Waybar supervisor: one self-healing instance. pkill guarantees a single bar;
	-- the loop respawns on crash (waybar SIGSEGVs racing Hyprland at boot), 1->8s
	-- backoff resetting after a healthy >=10s run. Reload: `killall -SIGUSR2 waybar`,
	-- restart: `killall waybar`. Never launch waybar by hand (bypasses the supervisor).
	hl.exec_cmd("bash -c 'pkill -x waybar 2>/dev/null; d=1; while true; do t=$SECONDS; waybar; if [ $((SECONDS-t)) -ge 10 ]; then d=1; else d=$(( d<8 ? d*2 : 8 )); fi; sleep $d; done'")
	hl.exec_cmd("swaync")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("bash -c 'M=" .. main_mon .. "; S=" .. side_mon .. "; until awww query >/dev/null 2>&1; do sleep 0.2; done; L=~/Pictures/Wallpapers/deep-space-cosmic-5120x2880-21267.jpg; P=~/Pictures/Wallpapers/cyberpunk_portrait.jpg; awww img -o $M $L; awww img -o $S $P; while sleep 2; do awww query 2>/dev/null | grep $M | grep -q color: && awww img -o $M $L; awww query 2>/dev/null | grep $S | grep -q color: && awww img -o $S $P; done'")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("nm-applet --indicator")
	-- XEmbed->SNI bridge for Wine/Battle.net tray icons. sleep 2 avoids racing
	-- Xwayland startup (it's an X11 client) -- too early and the icon is orphaned.
	hl.exec_cmd("sleep 2 && xembedsniproxy")
	hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland")
	hl.exec_cmd("sleep 1 && /usr/lib/xdg-desktop-portal --replace")
	hl.exec_cmd("elephant")
	hl.exec_cmd("sleep 2 && walker --gapplication-service")
end)

--------------------
---- CONFIG     ----
--------------------

hl.config({
	input = {
		kb_layout = "us",
		follow_mouse = 1,
		numlock_by_default = true,

		sensitivity = 0,
		accel_profile = "flat",

		natural_scroll = false,
		scroll_factor = 1.0,
		left_handed = false,

		touchpad = {
			natural_scroll = false,
		},
	},

	general = {
		gaps_in = 4,
		gaps_out = 4,
		border_size = 1,
		layout = "dwindle",
		col = {
			active_border = { colors = { "rgb(cba6f7)" } },
			inactive_border = colors.surface0,
		},
	},

	decoration = {
		rounding = 4,
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
		},
	},

	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
	},

	misc = {
		vrr = 1,
		disable_hyprland_logo = true,
		focus_on_activate = true,
	},
	cursor = {
		no_warps = true,
	},
})

------------------------
---- WINDOW RULES   ----
------------------------

-- Hide xembedsniproxy's XEmbed container: a real 32x32 X11 window with a solid black
-- background, one per proxied Wine/Battle.net tray icon. On click xembedsniproxy MOVES
-- it under the cursor on purpose, so the synthetic click lands on Wine's icon -- it has
-- to stay mapped and clickable, so hide it with opacity rather than unmapping it.
-- Dynamic opacity/no_blur re-hide it each time (a static rule fires only once).
-- Match on class, NOT empty class+title: xembedsniproxy >=6.7.2 sets WM_CLASS on the
-- container. The old empty-matcher also caught native X11 popup menus (Electron's
-- Menu.popup() is override-redirect with no class/title) and dismissed them instantly;
-- an exact class match cannot. Keep >=6.7.2 -- on 6.5.5 the container has no WM_CLASS
-- and this rule silently stops matching.
hl.window_rule({
	name = "hide-wine-tray-bar",
	match = {
		class = "^xembedsniproxy$",
	},
	opacity = 0.0,
	no_blur = true,
	no_focus = true,
})

-- WoW (Wine/Proton, steam_app_default): force real fullscreen so it gets the FULL
-- monitor, not the tiled usable area (shrunk by waybar's exclusive zone + gaps).
-- Otherwise windowed-fullscreen fights the tiler and the window snaps endlessly.
hl.window_rule({
	name = "wow-fullscreen",
	match = {
		class = "steam_app_default",
		title = "^World of Warcraft$",
	},
	workspace = "name:WoW",
	fullscreen = true,
})

-- Snip editor (Super+Shift+S) floats instead of tiling.
hl.window_rule({
	name = "swappy-float",
	match = {
		class = "^swappy$",
	},
	float = true,
})

-- Transparency overrides
hl.window_rule({
	match = { class = "brave-browser" },
	opacity = "1.0 override",
})

hl.window_rule({
	match = { class = "Spotify" },
	opacity = "1.0 override",
})

hl.window_rule({
	match = { class = "discord" },
	opacity = "1.0 override",
})

hl.window_rule({
	match = { class = "^net-runelite-client-RuneLite$" },
	opacity = "1.0 override",
})

hl.window_rule({
	match = { class = "com.stremio.Stremio" },
	opacity = "1.0 override",
})

hl.window_rule({
	match = {
		class = "^rustdesk$",
		title = ".*Remote Desktop - RustDesk",
	},
	opacity = "1.0 override",
})

------------------------
----  LAYER RULES   ----
------------------------

-- Frosted-glass blur behind waybar's semi-transparent module cards so text
-- stays readable over busy windows/wallpaper. ignore_alpha keeps the blur off
-- the fully-transparent gaps between modules (only the ~0.4+ alpha cards blur;
-- the module text/icons render on top and stay sharp).
hl.layer_rule({
	name = "waybar-blur",
	match = "waybar",
	blur = true,
	ignore_alpha = 0.4,
})

--------------------
----  PROGRAMS  ----
--------------------
local terminal = "ghostty"
local fileManager = "nemo"
local browser = "brave"
local music = "flatpak run com.spotify.Client"
local notes = "obsidian"
local launcher = "walker"

--------------------
---- BINDINGS   ----
--------------------

local mod = "SUPER"
local mod2 = "SUPER + SHIFT"
local mod3 = "ALT"
local mod4 = "ALT + SHIFT"
local mod5 = "SUPER + ALT"

hl.bind(mod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + M", hl.dsp.exec_cmd(music))
hl.bind(mod .. " + N", hl.dsp.exec_cmd(notes))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(launcher))

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod2 .. " + Q", hl.dsp.exit())

-- Toggle floating, EXCEPT World of Warcraft (see fullscreen bind below).
hl.bind(mod .. " + V", function()
	local w = hl.get_active_window()
	if w and w.title and w.title:match("World of Warcraft") then
		return
	end
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end)

-- Toggle fullscreen on the focused window, EXCEPT World of Warcraft. WoW manages
-- its own windowed-fullscreen; toggling the compositor's fullscreen makes it
-- fight the tiler and snap/break (see the wow-fullscreen window rule above).
hl.bind(mod .. " + F", function()
	local w = hl.get_active_window()
	if w and w.title and w.title:match("World of Warcraft") then
		return
	end
	hl.dispatch(hl.dsp.window.fullscreen())
end)

-- Media keys ----------------------------------------------------------------
-- locked = also fire while the screen is locked; repeating = key-repeat held.
-- Volume (-l 1.0 caps at 100% to avoid software over-amplification).
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
-- F24 (Nuphy Air75 V3) -> mic mute at the PipeWire source: Discord can't grab
-- global hotkeys under Wayland. A chirp signals state (Discord's own UI won't).
hl.bind("F24", hl.dsp.exec_cmd(
	"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && "
	.. "if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; "
	.. "then paplay /usr/share/sounds/freedesktop/stereo/device-removed.oga; "
	.. "else paplay /usr/share/sounds/freedesktop/stereo/device-added.oga; fi"
), { locked = true })
-- Playback (works with any MPRIS player: Spotify, browsers, mpv, etc.)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + P", hl.dsp.layout("togglesplit"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mod2 .. " + S", hl.dsp.exec_cmd("/home/phill/.config/hypr/scripts/snip.sh")) -- Windows-style snip

-- Mouse window management
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus switching ---------------------------------------------------------
-- Vim keys
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Alt+Tab
hl.bind(mod3 .. " + Tab", hl.dsp.window.cycle_next())

-- Workspaces ----------------------------------------------------------------
package.path = package.path .. ";./?.lua;./?/init.lua"
local smw = require("plugins.split-monitor-workspaces")

smw.setup({
    workspace_count = 10,
	monitor_priority = { main_mon, side_mon },
	max_workspaces = { [side_mon] = 3 },
	keep_focused = true,
	enable_wrapping = true,
	link_monitors = false,
	enable_persistent_workspaces = false,
})

for i = 1, smw.get_amount_of_workspaces() do
    local n = tostring(i)
    if n == "10" then n = "0" end -- ws 10 -> SUPER+0
    -- SUPER+N focus workspace N; SUPER+SHIFT+N move it there silently (focused monitor).
    hl.bind(mod .. " +" .. n, smw.workspace(n))
    hl.bind(mod2 .. " +" .. n, smw.move_to_workspace_silent(n))
end

--- Cycle workspaces on the current monitor.
hl.bind(mod .. " + mouse_down", smw.cycle_workspaces("prev"))
hl.bind(mod .. " + mouse_up", smw.cycle_workspaces("next"))

--- Move orphaned windows (not assigned to any mapped workspace) to the current workspace.
hl.bind(mod2 .. " + G", smw.grab_rogue_windows())

-- TODO: move these settings here and remove hyprmod
-- HyprMod managed settings
require("hyprland-gui")