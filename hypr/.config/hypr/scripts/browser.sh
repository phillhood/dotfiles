#!/usr/bin/env bash
[[ $(cat "$XDG_RUNTIME_DIR/hypr-profile" 2>/dev/null) == work ]] || exec brave "$@"

root="$HOME/.config/mozilla/firefox"
db=$(compgen -G "$root/Profile Groups/*.sqlite" | head -n1)

if [[ -n $db ]]; then
	dir=$(sqlite3 -readonly "$db" "SELECT path FROM Profiles WHERE lower(name) = 'work' LIMIT 1" 2>/dev/null)
	if [[ -n $dir && -d $root/$dir ]]; then
		exec firefox --profile "$root/$dir" "$@"
	fi
fi

notify-send -a Firefox "No Firefox profile named \"work\"" "Opening the default profile instead."
exec firefox "$@"
