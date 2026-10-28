-- Hyprland config

local colors = require("themes.catppuccin-mocha")

--------------------
---- MONITORS   ----
--------------------

local main_mon = "DP-1" -- landscape
local side_mon = "DP-2" -- portrait

hl.monitor({ output = main_mon, mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = side_mon, mode = "preferred", position = "-1440x-520", scale = 1, transform = 3, vrr = 0 })
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

--------------------
---- ENV VARS   ----
--------------------

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

--------------------
---- AUTOSTART  ----
--------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
	-- Waybar supervisor -- never launch waybar by hand, it bypasses this.
	hl.exec_cmd("bash -c 'pkill -x waybar 2>/dev/null; d=1; while true; do t=$SECONDS; waybar -c ~/.config/waybar/bars.jsonc -s $XDG_RUNTIME_DIR/waybar-style.css; if [ $((SECONDS-t)) -ge 10 ]; then d=1; else d=$(( d<8 ? d*2 : 8 )); fi; sleep $d; done'")
	hl.exec_cmd("swaync")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("bash -c 'w() { awww img -o $1 \"$(cat $XDG_RUNTIME_DIR/hypr-wallpaper-$1)\"; }; until awww query >/dev/null 2>&1; do sleep 0.2; done; for o in " .. main_mon .. " " .. side_mon .. "; do w $o; done; while sleep 2; do for o in " .. main_mon .. " " .. side_mon .. "; do awww query 2>/dev/null | grep $o | grep -q color: && w $o; done; done'")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("nm-applet --indicator")
	-- X11 client must start after Xwayland
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
		focus_on_activate = false,
	},
	cursor = {
		no_warps = true,
	},
})

------------------------
---- WINDOW RULES   ----
------------------------

-- Needs xembedsniproxy >=6.7.2, which sets WM_CLASS on the container.
hl.window_rule({
	name = "hide-wine-tray-bar",
	match = {
		class = "^xembedsniproxy$",
	},
	opacity = 0.0,
	no_blur = true,
	no_focus = true,
})

hl.window_rule({
	name = "wow-fullscreen",
	match = {
		class = "steam_app_default",
		title = "^World of Warcraft$",
	},
	workspace = "10",
	fullscreen = true,
})

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

-- ignore_alpha keeps the blur off the transparent gaps between modules.
hl.layer_rule({
	name = "waybar-blur",
	match = "waybar",
	blur = true,
	ignore_alpha = 0.4,
})

hl.layer_rule({
	name = "swaync-blur",
	match = "swaync-control-center",
	blur = true,
	ignore_alpha = 0.4,
})

hl.layer_rule({
	name = "swaync-popup-blur",
	match = "swaync-notification-window",
	blur = true,
	ignore_alpha = 0.4,
})

--------------------------
----  NOTIFICATIONS  ----
--------------------------

local function sync_noti_monitor()
	local mon = hl.get_monitor(main_mon)
	local ws = mon and mon.active_workspace
	local target = (ws and ws.has_fullscreen) and side_mon or main_mon
	hl.exec_cmd("swaync-client --change-noti-monitor " .. target)
end

hl.on("window.fullscreen", sync_noti_monitor)
hl.on("window.close", sync_noti_monitor)
hl.on("workspace.active", sync_noti_monitor)

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

hl.bind(mod .. " + V", function()
	local w = hl.get_active_window()
	if w and w.title and w.title:match("World of Warcraft") then
		return
	end
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end)

hl.bind(mod .. " + F", function()
	local w = hl.get_active_window()
	if w and w.title and w.title:match("World of Warcraft") then
		return
	end
	hl.dispatch(hl.dsp.window.fullscreen())
end)

-- Media keys ----------------------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("/home/phill/.config/hypr/scripts/mic-mute.sh"), { locked = true })
-- F24 (Nuphy Air75 V3) -> mic mute
hl.bind("F24", hl.dsp.exec_cmd("/home/phill/.config/hypr/scripts/mic-mute.sh"), { locked = true })
-- Playback (any MPRIS player)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + P", hl.dsp.layout("togglesplit"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mod2 .. " + S", hl.dsp.exec_cmd("/home/phill/.config/hypr/scripts/snip.sh"))

-- Mouse window management
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus switching ---------------------------------------------------------
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
	max_workspaces = { [side_mon] = 5 },
	keep_focused = true,
	enable_wrapping = true,
	link_monitors = false,
	enable_persistent_workspaces = false,
})

for i = 1, smw.get_amount_of_workspaces() do
    local n = tostring(i)
    if n == "10" then n = "0" end
    hl.bind(mod .. " +" .. n, smw.workspace(n))
    hl.bind(mod2 .. " +" .. n, smw.move_to_workspace_silent(n))
end

hl.bind(mod .. " + mouse_down", smw.cycle_workspaces("prev"))
hl.bind(mod .. " + mouse_up", smw.cycle_workspaces("next"))

-- Profiles ------------------------------------------------------------------
local smw_helpers = require("plugins.split-monitor-workspaces.lua.helpers")
local smw_globals = require("plugins.split-monitor-workspaces.lua.globals")

local wallpaper_dir = os.getenv("HOME") .. "/Pictures/Wallpapers/"

local profiles = {
	home = {
		offset = 0,
		border = "rgb(cba6f7)",
		wallpapers = {
			[main_mon] = "deep-space-cosmic-5120x2880-21267.jpg",
			[side_mon] = "cyberpunk_portrait.jpg",
		},
	},
	work = {
		offset = 100,
		border = "rgb(89b4fa)",
		wallpapers = {
			[main_mon] = "City_Landscape.jpg",
			[side_mon] = "City_Landscape.jpg",
		},
	},
}

local profile_slide_ms = 350
local profile_curve = { 0.4, 0, 0.15, 1 }

hl.curve("profileSlide", { type = "bezier", points = { { profile_curve[1], profile_curve[2] }, { profile_curve[3], profile_curve[4] } } })

local function workspace_animation(style, speed, curve)
	hl.animation({ leaf = "workspaces", enabled = true, speed = speed, bezier = curve, style = style })
end

local function default_workspace_animation()
	workspace_animation("slide", 4, "default")
end

default_workspace_animation()

local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
local profile_file = runtime_dir .. "/hypr-profile"
local profile_css_file = runtime_dir .. "/waybar-style.css"
local attention_file = runtime_dir .. "/hypr-profile-attention"

local function read_profile()
	local f = io.open(profile_file, "r")
	if not f then return "home" end
	local name = f:read("l")
	f:close()
	return profiles[name] and name or "home"
end

local current_profile = read_profile()
local last_ws = { home = {}, work = {} }
local attention = { home = false, work = false }

local function other_profile()
	return current_profile == "home" and "work" or "home"
end

local function profile_of(ws_name)
	local n = tonumber(ws_name)
	if not n then return nil end
	return n > 100 and "work" or "home"
end

local function write_file(path, contents)
	local f = assert(io.open(path .. ".tmp", "w"))
	f:write(contents)
	f:close()
	assert(os.rename(path .. ".tmp", path))
end

local wallpaper_cache = (os.getenv("XDG_CACHE_HOME") or os.getenv("HOME") .. "/.cache") .. "/hypr-profiles/"
local wallpaper_lead_ms = 16

local function monitor_size(monitor)
	if monitor.transform % 2 == 1 then return monitor.height, monitor.width end
	return monitor.width, monitor.height
end

local function cached_wallpaper(profile, monitor)
	local image = profiles[profile].wallpapers[monitor.name]
	if not image then return nil, nil end
	local w, h = monitor_size(monitor)
	return wallpaper_dir .. image,
		string.format("%s%s-%s-%dx%d-%s.ppm", wallpaper_cache, profile, monitor.name, w, h, image:gsub("%.[^.]+$", ""))
end

local function wallpaper_path(profile, monitor)
	local src, cached = cached_wallpaper(profile, monitor)
	if not cached then return nil end
	local f = io.open(cached, "r")
	if f then
		f:close()
		return cached
	end
	return src
end

local function cache_wallpapers()
	for _, m in ipairs(hl.get_monitors()) do
		local w, h = monitor_size(m)
		for name in pairs(profiles) do
			local src, dst = cached_wallpaper(name, m)
			if src then
				local cmd = string.format(
					"mkdir -p '%s' && fresh=0 && { [ '%s' -nt '%s' ] || { magick '%s' -resize %dx%d^ -gravity center -extent %dx%d 'ppm:%s.tmp' && mv '%s.tmp' '%s' && fresh=1; }; }",
					wallpaper_cache, dst, src, src, w, h, w, h, dst, dst, dst)
				if name == current_profile then
					cmd = cmd .. string.format(
						" && [ \"$(cat '%s')\" = '%s' ] && echo '%s' > '%s/hypr-wallpaper-%s' && shown=$(awww query 2>/dev/null | sed -n 's|^: %s: .*image: ||p') && [ -n \"$shown\" ] && { [ $fresh = 1 ] || [ \"$shown\" != '%s' ]; } && awww img -o %s --transition-type fade --transition-duration 0.4 '%s'",
						profile_file, name, dst, runtime_dir, m.name, m.name, dst, m.name, dst)
				end
				hl.exec_cmd(cmd)
			end
		end
	end
end

local function write_profile_state()
	local other = other_profile()
	write_file(profile_file, current_profile .. "\n")

	local hidden = {}
	for _, sel in ipairs({
		"#workspaces.%s",
		"#workspaces.%s button",
		"#workspaces.%s button.active",
		"#workspaces.%s button.empty",
		"#workspaces.%s button.empty.active",
		"#workspaces.%s button:last-child",
		"#workspaces.%s label",
		"#custom-profile-%s",
		"#custom-profile-%s label",
	}) do
		table.insert(hidden, sel:format(other))
	end
	write_file(profile_css_file, string.format([[
@import url("%s/.config/waybar/style.css");

%s {
  padding: 0; margin: 0; min-width: 0; min-height: 0; border: none;
  font-size: 0; opacity: 0; background: transparent; box-shadow: none;
}
]], os.getenv("HOME"), table.concat(hidden, ",\n")))

	if attention[other] then
		write_file(attention_file, other .. "\n")
	else
		os.remove(attention_file)
	end

	for _, m in ipairs(hl.get_monitors()) do
		local path = wallpaper_path(current_profile, m)
		if path then write_file(runtime_dir .. "/hypr-wallpaper-" .. m.name, path .. "\n") end
	end
end

local function apply_profile_look(transition)
	hl.config({ general = { col = { active_border = { colors = { profiles[current_profile].border } } } } })
	if not transition then return end
	local cmds = {}
	for _, m in ipairs(hl.get_monitors()) do
		local path = wallpaper_path(current_profile, m)
		if path then
			table.insert(cmds, string.format(
				"awww img -o %s --transition-type %s --transition-duration %.2f --transition-fps %d --transition-bezier %s '%s' &",
				m.name, transition, profile_slide_ms / 1000, math.ceil(m.refresh_rate), table.concat(profile_curve, ","), path))
		end
	end
	if #cmds > 0 then hl.exec_cmd(table.concat(cmds, " ") .. " wait") end
end

write_profile_state()
cache_wallpapers()
apply_profile_look(nil)

hl.on("hyprland.start", function()
	write_profile_state()
	cache_wallpapers()
end)

local base_index = smw_helpers.calc_base_index
smw_helpers.calc_base_index = function(monitor_name)
	return base_index(monitor_name) + profiles[current_profile].offset
end

for _, p in pairs(profiles) do
	for i = 1, 10 do
		hl.workspace_rule({ workspace = tostring(p.offset + i), monitor = main_mon })
	end
	for i = 11, 15 do
		hl.workspace_rule({ workspace = tostring(p.offset + i), monitor = side_mon })
	end
end

local function restore_target(monitor)
	local ws_list = smw_globals.monitor_workspace_map[monitor.id]
	if not ws_list or #ws_list == 0 then return nil end
	local saved = last_ws[current_profile][monitor.name]
	for _, name in ipairs(ws_list) do
		if name == saved then return saved end
	end
	return ws_list[1]
end

local pending_focus
local restore_animation

function set_profile(name, after)
	if not profiles[name] then return end
	if name == current_profile and not pending_focus then
		if after then after() end
		return
	end

	local focused = hl.get_active_monitor()
	if pending_focus then
		pending_focus:set_enabled(false)
		pending_focus = nil
	else
		for _, m in ipairs(hl.get_monitors()) do
			local ws = hl.get_active_workspace(m)
			if ws then last_ws[current_profile][m.name] = ws.name end
		end
	end

	current_profile = name
	attention[name] = false
	write_profile_state()
	for _, m in ipairs(hl.get_monitors()) do
		local base = smw_helpers.calc_base_index(m.name)
		local ws_list = {}
		for i = base + 1, base + smw_helpers.get_monitor_max_ws(m.name) do
			table.insert(ws_list, tostring(i))
		end
		smw_globals.monitor_workspace_map[m.id] = ws_list
	end

	local targets, focused_target = {}, nil
	for _, m in ipairs(hl.get_monitors()) do
		local target = restore_target(m)
		if focused and m.id == focused.id then
			focused_target = target
		elseif target then
			table.insert(targets, target)
		end
	end
	if focused_target then table.insert(targets, focused_target) end

	workspace_animation("slide", profile_slide_ms / 100, "profileSlide")
	apply_profile_look(name == "work" and "right" or "left")

	pending_focus = hl.timer(function()
		pending_focus = nil
		for _, target in ipairs(targets) do
			hl.dispatch(hl.dsp.focus({ workspace = target }))
		end
		if after then after() end
	end, { timeout = wallpaper_lead_ms, type = "oneshot" })

	if restore_animation then restore_animation:set_enabled(false) end
	restore_animation = hl.timer(default_workspace_animation,
		{ timeout = wallpaper_lead_ms + profile_slide_ms + 50, type = "oneshot" })
end

function toggle_profile()
	set_profile(other_profile())
end

local function move_to_other_profile()
	local w = hl.get_active_window()
	local n = w and w.workspace and tonumber(w.workspace.name)
	if not n then return end
	local target = n > 100 and n - 100 or n + 100
	hl.dispatch(hl.dsp.window.move({ workspace = tostring(target), follow = false }))
end

hl.on("window.urgent", function(w)
	if not w or not w.workspace then return end
	local p = profile_of(w.workspace.name)
	if p == nil or p == current_profile then
		if not w.xwayland then hl.dispatch(hl.dsp.focus({ window = w })) end
	elseif not attention[p] then
		attention[p] = true
		write_profile_state()
	end
end)

hl.bind(mod .. " + grave", toggle_profile)
hl.bind(mod2 .. " + grave", move_to_other_profile)

local function grab_rogue_windows()
	local monitor = hl.get_active_monitor()
	local ws = monitor and hl.get_active_workspace(monitor)
	if not ws then return end
	for _, w in ipairs(hl.get_windows()) do
		if w.mapped and w.workspace and not w.workspace.special then
			local n = tonumber(w.workspace.name)
			local i = n and (n > 100 and n - 100 or n)
			if not (i and i >= 1 and i <= 15) then
				hl.dispatch(hl.dsp.window.move({ workspace = ws.name, window = w, follow = false }))
			end
		end
	end
end

hl.bind(mod2 .. " + G", grab_rogue_windows)

local function jump_to_game()
	local battlenet
	for _, w in ipairs(hl.get_windows()) do
		if w.class == "steam_app_default" then
			if w.title == "World of Warcraft" then
				hl.dispatch(hl.dsp.focus({ window = w }))
				return
			elseif w.title == "Battle.net" then
				battlenet = w
			end
		end
	end
	if battlenet then
		hl.dispatch(hl.dsp.focus({ window = battlenet }))
	end
end

-- Jump to the game: WoW, else the Battle.net launcher.
hl.bind(mod .. " + F1", function()
	set_profile("home", jump_to_game)
end)

-- TODO: fold these in and drop hyprmod
require("hyprland-gui")