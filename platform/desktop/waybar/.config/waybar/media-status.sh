#!/bin/sh
# Emits a play or pause icon for the waybar media drawer, updating instantly
# on playback status changes via playerctl --follow.

emit() {
	case "$1" in
	Playing) printf '󰏤\n' ;; # show pause icon while playing
	*)       printf '󰐊\n' ;; # show play icon when paused/stopped
	esac
}

# Print current state immediately so the button isn't blank on start.
emit "$(playerctl status 2>/dev/null)"

# Then stream subsequent status changes.
playerctl --follow status 2>/dev/null | while IFS= read -r line; do
	emit "$line"
done
