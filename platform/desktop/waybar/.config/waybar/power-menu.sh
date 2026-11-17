#!/usr/bin/env bash
menu() {
  local prompt=$1
  shift
  printf '%s\n' "$@" | walker --dmenu -t power -n -H -p "$prompt"
}

run() {
  "$@" || notify-send -u critical "Power menu" "$1 failed"
}

confirm() {
  [[ "$(menu "$1?" "  No" "  Yes")" == *Yes ]]
}

chosen=$(menu "Power" \
  "  Lock" \
  "  Logout" \
  "  Suspend" \
  "  Reboot" \
  "  Shutdown")

case "$chosen" in
  *Lock)     run hyprlock ;;
  *Logout)   run hyprctl dispatch 'hl.dsp.exit()' ;;
  *Suspend)  run systemctl suspend ;;
  *Reboot)   confirm "Reboot" && run systemctl reboot ;;
  *Shutdown) confirm "Shutdown" && run systemctl poweroff ;;
  "") ;;
  *) notify-send -u critical "Power menu" "unrecognised selection: $chosen" ;;
esac
