#!/usr/bin/env bash
flag="$XDG_RUNTIME_DIR/hypr-profile-attention"
levels=(100 97 90 80 68 55 43 33 26 22 22 26 33 43 55 68 80 90 97)
i=0
shown=1

while :; do
	if [[ -e $flag ]]; then
		printf "<span color='#f5a97f' alpha='%s%%'>●</span>\n" "${levels[i]}"
		i=$(( (i + 1) % ${#levels[@]} ))
		shown=1
		sleep 0.06
	else
		if (( shown )); then
			echo
			shown=0
			i=0
		fi
		sleep 0.25
	fi
done
