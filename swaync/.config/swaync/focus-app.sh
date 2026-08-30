#!/usr/bin/env bash
# Focus an app from a swaync script entry (run-on: action). Apps that register no
# default action -- RuneLite among them -- leave the click doing nothing, so
# swaync invokes this instead.
#
# hl.dsp.focus accepts direction/monitor/window/urgent_or_last/last and has NO
# class selector, so the window is looked up first. hyprctl here takes only Lua.
set -u
class="${1:?usage: focus-app.sh <class-lua-pattern>}"

hyprctl dispatch "hl.dsp.focus({ window = (function()
  for _, w in ipairs(hl.get_windows()) do
    if w.class and w.class:match('$class') then return w end
  end
end)() })" >/dev/null 2>&1
