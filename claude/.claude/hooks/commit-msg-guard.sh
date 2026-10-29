#!/bin/bash

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

[[ $cmd =~ git([[:space:]]+-[A-Za-z][^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit ]] || exit 0

if CMD="$cmd" perl -e 'exit !($ENV{CMD} =~ /co-authored-by:|generated with \[?claude/i)'; then
  echo "Commit messages must not carry a Co-Authored-By trailer or a Claude attribution." >&2
  exit 2
fi

subject=$(CMD="$cmd" perl -e '
  $_ = $ENV{CMD};
  /(?:^|\s)(?:-[a-zA-Z]*m|--message)(?:=|\s+)(.*)/s or exit;
  $m = $1;
  $m =~ s/^"?\$\(cat\s*<<-?\s*["\x27]?\w+["\x27]?\s*\n//;
  $m =~ s/^["\x27]//;
  ($s) = split /\n/, $m;
  $s =~ s/["\x27]\s*\)?\s*$//;
  print $s;
')

prefix='^[A-Za-z][A-Za-z0-9_-]*(\([^)]*\))?!?:[[:space:]]'
[[ $subject =~ $prefix ]] || exit 0

if [ -n "$cwd" ] && git -C "$cwd" log -20 --format=%s 2>/dev/null | PREFIX="$prefix" perl -ne 'BEGIN{$p=$ENV{PREFIX}; $p=~s/\[\[:space:\]\]/\\s/g} $f=1 if /$p/; END{exit !$f}'; then
  exit 0
fi

echo "This repo's history uses no commit prefixes. Drop the '${subject%%:*}:' prefix and say what changed." >&2
exit 2
