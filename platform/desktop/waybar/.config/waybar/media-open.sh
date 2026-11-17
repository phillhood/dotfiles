#!/bin/sh
# Focuses (or launches) the app whose media is currently shown in the waybar
# mpris box. The active player follows playerctld, matching the mpris display.
player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null)

# Map the active player to its Hyprland window class and a launch fallback.
case "$player" in
	spotify*)  class="spotify";        launch="spotify-launcher" ;;
	brave*)    class="brave-browser";  launch="brave" ;;
	firefox*)  class="firefox";        launch="firefox" ;;
	chrom*)    class="chromium";       launch="chromium" ;;
	*)         exit 0 ;;
esac

# Focus the existing window if it's open, otherwise launch the app.
# Hyprland runs in Lua config mode, so use the hl.dsp.focus dispatcher.
if hyprctl clients -j | grep -q "\"class\": \"$class\""; then
	hyprctl dispatch "hl.dsp.focus({ window = \"class:$class\" })"
else
	exec $launch
fi
