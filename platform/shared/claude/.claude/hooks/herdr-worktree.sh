#!/bin/bash

input=$(cat)

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -z "$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)" ] || exit 0

cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

git_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null)
common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

if [ -n "$git_dir" ] && [ "$git_dir" != "$common_dir" ]; then
  name=$(basename "$(git -C "$cwd" rev-parse --show-toplevel)")
  herdr pane report-metadata "$HERDR_PANE_ID" --source dotfiles:worktree --token "worktree=$name" >/dev/null 2>&1
else
  herdr pane report-metadata "$HERDR_PANE_ID" --source dotfiles:worktree --clear-token worktree >/dev/null 2>&1
fi

exit 0
