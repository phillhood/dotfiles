#!/bin/bash

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")

[[ $cmd == *git*commit* ]] || exit 0

CMD="$cmd" perl -e '
  sub blank { /\G(?:[ \t]|\\\n)*/gc }
  sub word {
    blank();
    /\G((?:"(?:\\.|[^"\\])*"|\x27[^\x27]*\x27|\\.|[^\s"\x27;&|()])+)/gcs ? $1 : undef;
  }
  sub ok {
    my ($s) = split /\n/, $_[0];
    $s //= "";
    return 1 if $s =~ /^(?:Merge |Revert "|fixup! |squash! |amend! )/;
    return 1 if $s =~ /^[A-Z][A-Z0-9]+-[0-9]+ /;
    return $s =~ /^(?:feat|fix|docs|chore|refactor|test|ci|build|perf|style|revert)(?:\([a-z0-9._\/-]+\))?!?: [^\sA-Z]/;
  }
  sub commit {
    my ($msg, $eval, $dd) = (undef, 1, 0);
    while (1) {
      blank();
      last if /\G(?=[;&|\n()]|\z)/;
      if (!$dd && !defined $msg && /\G(?:--message(?:=|(?:[ \t]|\\\n)+)|-[A-Za-z]*?m(?:[ \t]|\\\n)*)/gc) {
        if (/\G"?\$\(cat[ \t]*<<-?[ \t]*(["\x27]?)(\w+)\1[ \t]*\n([^\n]*)/gc) {
          my $d = $2;
          $msg = $3;
          /\G.*?\n[ \t]*\Q$d\E[ \t]*(?=\n|\)|\z)/gcs and /\G\s*\)"?/gc;
        } elsif (/\G"((?:\\.|[^"\\])*)"/gc) {
          $msg = $1;
          $eval = 0 if $msg =~ /^[\$`]/;
          $msg =~ s/\\([\\"\$`])/$1/g;
        } elsif (/\G\x27([^\x27]*)\x27/gc) {
          $msg = $1;
        } else {
          /\G([^\s"\x27;&|)]*)/gc;
          $msg = $1;
          $eval = 0 if $msg =~ /^[\$`]/;
        }
        next;
      }
      if (!$dd && /\G--(?=[ \t\n;&|()]|\z)/gc) { $dd = 1; next }
      defined word() or /\G./gcs;
    }
    $bad = 1 if defined $msg && $eval && !ok($msg);
  }
  sub git {
    my $w;
    while (defined($w = word())) {
      last unless $w =~ /^-/;
      word() if $w =~ /^(?:-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix)$/;
    }
    return unless defined $w && $w eq "commit";
    $found = 1;
    commit();
  }
  $_ = $ENV{CMD};
  $at = 1;
  while ((pos() // 0) < length) {
    next if /\G(?:[ \t]|\\\n)+/gc;
    if (/\G[;&|\n()]/gc) { $at = 1; next }
    my $w = word();
    if (!defined $w) { /\G./gcs; next }
    next unless $at;
    next if $w =~ /^[A-Za-z_][A-Za-z0-9_]*=/;
    next if $w =~ /^(?:sudo|env|command|exec|time|then|do|else|\{)$/;
    $at = 0;
    git() if $w eq "git";
  }
  exit 3 if $found && /co-authored-by:|generated with \[?claude/i;
  exit($bad ? 1 : 0);
'
rc=$?
if (( rc == 3 )); then
  echo "Commit messages must not carry a Co-Authored-By trailer or a Claude attribution." >&2
  exit 2
fi
(( rc == 0 )) && exit 0

echo "Commit subjects must be lowercase conventional commits: type: description, or type(scope): description, with an optional ! before the colon. Types: feat, fix, docs, chore, refactor, test, ci, build, perf, style, revert." >&2
exit 2
