#!/usr/bin/env bash
# Claude Code statusline:  model │ context │ 5h usage │ week usage
#
# Claude Code pipes its statusline JSON payload on stdin; whatever this prints
# to stdout becomes the line. Every value comes from that payload — no network
# call, no credential read, no cache file, no transcript parsing.
#
# Wired up via ~/.claude/settings.json -> statusLine.command
#
# Other fields the payload carries, for adding sections later (Claude Code 2.1.219+).
# To see the current shape live, point statusLine.command at a script that tees
# stdin to a file before exec'ing this one.
#
#   .model.display_name .model.id
#   .context_window.{used_percentage,remaining_percentage,total_input_tokens,
#                    total_output_tokens,context_window_size,current_usage}
#   .rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}
#   .cost.{total_cost_usd,total_duration_ms,total_api_duration_ms,
#          total_lines_added,total_lines_removed}
#   .effort.level  .thinking.enabled  .fast_mode  .exceeds_200k_tokens
#   .session_id .session_name .prompt_id .version .output_style.name
#   .cwd .workspace.{current_dir,project_dir,added_dirs}
#   .vim.mode  .agent.name  .remote.session_id  .worktree.{name,path,branch}
#   .pr.{number,url,review_state,kind}
#
# Adding a section is one seg() call plus two config entries. seg() takes
# <icon_color> <icon> <label> <pct> <detail>; any of label/pct/detail may be ''.

set -uo pipefail

# ── config ───────────────────────────────────────────────────────────────────
ICON_MODEL=''     ; COLOR_MODEL=31     # red
ICON_CONTEXT=''   ; COLOR_CONTEXT=32   # green
ICON_5H='󰪞'    ; COLOR_5H=34        # blue
ICON_WEEK='󰃭'  ; COLOR_WEEK=35      # magenta

COLOR_TEXT=30            # everything that isn't a percentage
COLOR_SEP=37             # the │ separators
COLOR_WARN=33            # percentage at/above WARN_AT
COLOR_CRIT=31            # percentage at/above CRIT_AT

WARN_AT=60
CRIT_AT=85

SEPARATOR=' │ '
# ─────────────────────────────────────────────────────────────────────────────

E=$'\e['
R=$'\e[0m'

# Read stdin with a builtin so jq stays the only external process. It must read
# fd 0 *directly*: `$(</dev/stdin)` re-opens /proc/self/fd/0, which works for
# files and pipes but fails with ENXIO on a socket — and Node (hence Claude Code)
# hands children their stdio over socketpairs. That failure is silent: an empty
# payload and exit 0, i.e. no statusline at all.
# `read -d ''` returns nonzero at EOF but still assigns what it consumed.
IFS= read -r -d '' payload

# Recover just the model name without jq — used when jq is missing or the
# payload won't parse. Never leak raw JSON or a parser error into the prompt.
bail() {
  if [[ $payload =~ \"display_name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
  exit 0
}

[[ -n $payload ]] || exit 0
command -v jq >/dev/null 2>&1 || bail

# The "-" sentinel matters: $(…) strips trailing newlines, so empty trailing
# fields would shrink the mapfile array and `set -u` would abort on ${F[6]}
# exactly when rate_limits is absent. jq's // only treats null/false as absent,
# so a legitimate 0% still comes through as 0.
# Percentages arrive as floats (7.000000000000001, 2.5), so round them here —
# jq is already running and bash has no float arithmetic. `round` is half-away-
# from-zero; null stays "-" so the segment is omitted rather than shown as 0%.
fields=$(jq -r '
  def pct: if type == "number" then round else "-" end;
  [ (.model.display_name                    // "?"),
    ((.context_window.used_percentage       // 0) | round),
    ((.context_window.total_input_tokens    // 0) | round),
    (.rate_limits.five_hour.used_percentage  | pct),
    (.rate_limits.five_hour.resets_at       // "-"),
    (.rate_limits.seven_day.used_percentage  | pct),
    (.rate_limits.seven_day.resets_at       // "-") ]
  | .[] | tostring
' <<<"$payload" 2>/dev/null) || bail

[[ -n $fields ]] || bail

mapfile -t F <<<"$fields"
model=${F[0]:-?}   ctx_pct=${F[1]:-0}   ctx_tok=${F[2]:-0}
h5_pct=${F[3]:--}  h5_reset=${F[4]:--}
wk_pct=${F[5]:--}  wk_reset=${F[6]:--}

# 812 -> 812 | 69783 -> 69.8k | 1234567 -> 1.2M   (half-up on the tenth)
fmt_tokens() {
  local n=${1%%.*} t
  if   (( n >= 999950 )); then t=$(( (n + 50000) / 100000 )); printf '%d.%dM' $(( t / 10 )) $(( t % 10 ))
  elif (( n >= 1000   )); then t=$(( (n + 50)    / 100    )); printf '%d.%dk' $(( t / 10 )) $(( t % 10 ))
  else                         printf '%d' "$n"
  fi
}

# unix epoch or ISO 8601 -> 4h20m | 5d2h ; a reset already past clamps to 0h0m
fmt_eta() {
  local t=$1 now=${STATUSLINE_NOW:-$EPOCHSECONDS} d
  [[ $t == - ]] && return 1
  if [[ ! $t =~ ^[0-9]+$ ]]; then
    t=$(date -d "$t" +%s 2>/dev/null) || return 1
    [[ -n $t ]] || return 1
  fi
  d=$(( t - now )); (( d < 0 )) && d=0
  if (( d >= 86400 )); then printf '%dd%dh' $(( d / 86400 )) $(( d % 86400 / 3600 ))
  else                      printf '%dh%dm' $(( d / 3600 ))  $(( d % 3600 / 60 ))
  fi
}

# percentage -> the ansi code its number should be printed in
pct_color() {
  local p=${1%%.*}
  if   (( p >= CRIT_AT )); then printf '%d' "$COLOR_CRIT"
  elif (( p >= WARN_AT )); then printf '%d' "$COLOR_WARN"
  else                          printf '%d' "$COLOR_TEXT"
  fi
}

SEGMENTS=()

# seg <icon_color> <icon> <label> <pct> <detail>
# label, pct and detail may each be empty. pct gets a "%" suffix and threshold
# coloring; detail is prefixed with "· ".
seg() {
  local ic=$1 icon=$2 label=$3 pct=$4 detail=$5 out
  out="${E}${ic}m${icon}${R} "
  if [[ -n $label ]]; then
    out+="${E}${COLOR_TEXT}m${label}"
    [[ -n $pct ]] && out+=' '
    out+="${R}"
  fi
  [[ -n $pct    ]] && out+="${E}$(pct_color "$pct")m${pct}%${R}"
  [[ -n $detail ]] && out+=" ${E}${COLOR_TEXT}m· ${detail}${R}"
  SEGMENTS+=("$out")
}

seg "$COLOR_MODEL"   "$ICON_MODEL"   "$model" '' ''
seg "$COLOR_CONTEXT" "$ICON_CONTEXT" ''       "$ctx_pct" "$(fmt_tokens "$ctx_tok")"

# Omitted rather than faked when Claude Code hasn't fetched limits (API-key
# auth, or the first render of a session).
if [[ $h5_pct != - ]]; then
  eta=$(fmt_eta "$h5_reset") || eta=''
  seg "$COLOR_5H" "$ICON_5H" '' "$h5_pct" "$eta"
fi

if [[ $wk_pct != - ]]; then
  eta=$(fmt_eta "$wk_reset") || eta=''
  seg "$COLOR_WEEK" "$ICON_WEEK" '' "$wk_pct" "$eta"
fi

sep="${E}${COLOR_SEP}m${SEPARATOR}${R}"
line=''
for s in "${SEGMENTS[@]}"; do
  [[ -n $line ]] && line+="$sep"
  line+="$s"
done
printf '%s\n' "$line"
