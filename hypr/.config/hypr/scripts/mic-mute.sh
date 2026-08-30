#!/usr/bin/env bash
set -uo pipefail

src="@DEFAULT_AUDIO_SOURCE@"
sounds=/usr/share/sounds/freedesktop/stereo

warn() {
	notify-send -u critical -a mic "$1" "$2"
	paplay "$sounds/dialog-error.oga" &
}

state() {
	local out
	out="$(wpctl get-volume "$src" 2>/dev/null)" || return 2
	[ -z "$out" ] && return 2
	case "$out" in
	*MUTED*) return 1 ;;
	*) return 0 ;;
	esac
}

state
before=$?

if [ "$before" -eq 2 ]; then
	warn "No microphone" "Default audio source is unavailable."
	exit 1
fi

wpctl set-mute "$src" toggle 2>/dev/null

state
after=$?

if [ "$after" -eq "$before" ]; then
	warn "Mic mute did nothing" "The capture device ignored the toggle."
	exit 1
fi

node="$(pactl get-default-source 2>/dev/null)"
port="$(pactl list sources 2>/dev/null | awk -v RS='' -v n="Name: $node" 'index($0, n)' | grep -oP 'Active Port: \K.*')"

case "$port" in
*iec958* | *spdif* | *digital*)
	warn "Microphone is not live" "Capturing from '$port', not a mic input. Fix the card profile."
	exit 1
	;;
esac

if [ "$after" -eq 1 ]; then
	paplay "$sounds/device-removed.oga" &
else
	paplay "$sounds/device-added.oga" &
fi
