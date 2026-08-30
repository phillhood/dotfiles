#!/usr/bin/env bash
set -u
class="${1:?usage: focus-app.sh <class-lua-pattern>}"

hyprctl dispatch "hl.dsp.focus({ window = (function()
  for _, w in ipairs(hl.get_windows()) do
    if w.class and w.class:match('$class') then return w end
  end
end)() })" >/dev/null 2>&1
