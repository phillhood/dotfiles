#!/usr/bin/env bash

set -u

SIGNAL=9

json_escape() {
  printf '%s' "$1" |
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/$/\\n/' |
    tr -d '\n' |
    sed 's/\\n$//'
}

refresh_waybar() {
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
}

backend_state() {
  if [ -n "${WAYBAR_TAILSCALE_STATE:-}" ]; then
    printf '%s\n' "$WAYBAR_TAILSCALE_STATE" | tr '[:upper:]' '[:lower:]'
    return
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    printf 'missing\n'
    return
  fi

  if command -v systemctl >/dev/null 2>&1 &&
    ! systemctl is-active --quiet tailscaled.service 2>/dev/null; then
    printf 'daemon-off\n'
    return
  fi

  local status state
  if status="$(tailscale status --json 2>/dev/null)"; then
    state="$(
      printf '%s\n' "$status" |
        sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
        head -n 1 |
        tr '[:upper:]' '[:lower:]'
    )"
    printf '%s\n' "${state:-unknown}"
    return
  fi

  if systemctl is-active --quiet tailscaled.service 2>/dev/null; then
    printf 'stopped\n'
  else
    printf 'daemon-off\n'
  fi
}

connected_tooltip() {
  tailscale status --json 2>/dev/null | jq -r '
    [
      "Tailscale: \(.CurrentTailnet.Name // "connected")",
      "\(.Self.DNSName // .Self.HostName | split(".")[0])  \(.TailscaleIPs[0] // "")",
      ([.Peer[]? | select(.ExitNode)][0] | select(.) | "Exit node: \(.DNSName | split(".")[0])"),
      "\([.Peer[]? | select(.Online)] | length)/\([.Peer[]?] | length) peers online",
      (.Health[]? | "⚠ \(.)")
    ] | join("\n") | @html
  ' 2>/dev/null
}

emit_json() {
  local text="$1"
  local tooltip="$2"
  local class="$3"

  printf '{"text":"%s","tooltip":"%s","class":["tailscale","%s"]}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "$class")"
}

emit_empty() {
  printf '{"text":"","tooltip":"","class":["tailscale","hidden"]}\n'
}

emit_icon() {
  local state="$1"

  case "$state" in
    running)
      local tooltip
      tooltip="$(connected_tooltip)"
      emit_json "<span color='#8bd5ca'>󰕥</span>" "${tooltip:-Tailscale: connected}" "connected"
      ;;
    missing)
      emit_json "<span color='#6e738d'>󰕥</span>" "Tailscale command not found" "disconnected"
      ;;
    daemon-off)
      emit_json "<span color='#6e738d'>󰕥</span>" "Tailscale daemon is stopped" "disconnected"
      ;;
    needslogin)
      emit_json "<span color='#eed49f'>󰕥</span>" "Tailscale needs login" "warning"
      ;;
    *)
      emit_json "<span color='#6e738d'>󰕥</span>" "Tailscale: $state" "disconnected"
      ;;
  esac
}

emit_drawer_icon() {
  local state="$1"

  if [ "$state" = "running" ]; then
    emit_empty
    return
  fi

  emit_icon "$state"
}

emit_active_icon() {
  local state="$1"

  if [ "$state" != "running" ]; then
    emit_empty
    return
  fi

  emit_icon "$state"
}

toggle_tailscale() {
  if [ "$(backend_state)" = "running" ]; then
    tailscale down >/dev/null 2>&1 || true
  else
    if command -v systemctl >/dev/null 2>&1 &&
      ! systemctl is-active --quiet tailscaled.service 2>/dev/null; then
      systemctl start tailscaled.service >/dev/null 2>&1 || true
    fi
    tailscale up >/dev/null 2>&1 || true
  fi

  # Nudge waybar to re-run the tailscale modules immediately (they carry
  # "signal": 9); the RTMIN+9 signal is the intended refresh path, not a hack.
  refresh_waybar
}

case "${1:-icon}" in
  icon)
    emit_icon "$(backend_state)"
    ;;
  drawer-icon)
    emit_drawer_icon "$(backend_state)"
    ;;
  active-icon)
    emit_active_icon "$(backend_state)"
    ;;
  toggle)
    toggle_tailscale
    ;;
  *)
    printf 'usage: %s {icon|drawer-icon|active-icon|toggle}\n' "$0" >&2
    exit 2
    ;;
esac
