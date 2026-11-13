# Waybar

`waybar/.config/waybar/`. Stowed into `~/.config/waybar/`.

## Why there are two config files

`config.jsonc` is the whole bar: settings, layout, every module definition.

`bars.jsonc` is a thin multi-bar array — one object per output, each `include`ing
`config.jsonc`. Waybar resolves duplicate keys with *the including file wins*, so
each entry inherits everything from `config.jsonc` and overrides only what must
differ per monitor. The supervisor in `hyprland.lua` launches waybar with
`-c ~/.config/waybar/bars.jsonc`; launching bare waybar loads `config.jsonc`
directly and gives one identical bar on every output.

Adding or renaming a monitor means adding an entry here. The output names are
already hardcoded in `hyprland.lua`, so this is the second place they live.

## Cava width

Waybar gives custom modules no way to know which output they are running on, so
`bars.jsonc` passes the output name to `cava.sh` as an argument. The script reads
that monitor's effective logical width from `hyprctl monitors -j` — swapping
width and height on an odd `transform`, dividing by `scale` — and derives the bar
count from `CAVA_BARS_PER_1000PX` (default 86, i.e. 8.6 bars per 100px), clamped
to 8–64.

At the current layout that is 22 bars on the landscape DP-1 (2560px) and 12 on
the portrait DP-2 (1440px), so the widget occupies the same share of each bar.
Turn the whole widget up or down by changing the one constant; the split between
monitors follows automatically.

Each instance writes its own generated cava config to
`/tmp/waybar_cava_config_<output>` — a shared path would have the two instances
clobbering each other's bar count.
