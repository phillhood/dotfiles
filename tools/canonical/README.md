# canonical/

Reference copies of configs that are **not** stowed (not symlinked into `$HOME`) but are kept
in the repo for reproducibility / bootstrapping.

Use this for files a tool or plugin **rewrites at runtime** — symlinking those just creates churn
and breaks the link. The live copy stays a real file the tool owns; the canonical copy here is a
curated snapshot that `bootstrap` applies on a fresh machine, then leaves alone.

Layout mirrors `$HOME`:

    tools/canonical/.claude/settings.json  →  ~/.claude/settings.json

**Not a stow package** — it's absent from the `Makefile`'s `PACKAGES`, so `make install` never
touches it.

## Notes per file

- **`.claude/settings.json`** — Claude Code rewrites this live, so it's untracked from the `claude`
  package and kept here instead. Keep this copy free of `//` comments: it's JSON, not JSONC, so that a
  `jq`-based bootstrap merge can parse it.
- **`AppData/.../Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json`** — Windows
  Terminal rewrites this from its settings UI. Copied whole on a new Windows machine, not merged; see
  `docs/windows.md`.
