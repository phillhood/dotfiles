# Git commits
- Do not add a `Co-Authored-By` trailer or any "Generated with Claude Code" annotation to commits.
- Write simple, lowercase commit messages (e.g. `fix login redirect`, not `Fix: Login Redirect`).
- No prefix or tag — not `docs:`, not conventional-commits `feat:`/`fix:`, no scope parens like `ansible(proxmox_host):`. Just say what changed: `setup ansible`, `point host resolver at pi-hole`. Comma-separated clauses are fine.
- Model the message on the most recent handful of commits in that repo. Where a repo's history uses ticket IDs (`CORE-155 ...`), match the history.

# Project docs
- **A committed `docs/` wins.** If the project specifies that documentation belongs in the repo, or a top-level `docs/` already exists, write there — docs are part of that repo's committed surface. Otherwise use the local trees below, and never create a top-level `docs/` where none exists.
- **`.docs/` — durable documentation.** Design notes, deploy guides, roadmaps, per-role and per-module reference, conventions, anything explaining *why*. Fold new notes into the existing `.docs/` file that owns the topic rather than adding a new dated file.
- **`.dev/` — skill and workflow output.** The workflow runs spec → plan → implementation, one directory each (`.dev/spec/`, `.dev/plan/`, `.dev/implementation/`), plus handoffs, scratch scripts and generated or backup output. Delete these once the work lands; anything durable gets folded into `.docs/` first.
- `.docs/` and `.dev/` are local-only and must stay out of git. Both are already in `~/.gitignore_global`; also add them to the repo's own `.gitignore` so the rule survives a clone, and to `.dockerignore` where one exists.
- **Ignore them as `.docs` and `.dev`, without a trailing slash.** In a git worktree both trees are symlinks back to the main checkout (a worktree checks out tracked files only, so the real directories aren't there). A trailing slash matches directories only, and a symlink-to-a-directory isn't one — `.dev/` leaves the symlink showing as untracked in every worktree.
- `.docs/` is gitignored, so nothing in it survives a clone. Treat it as load-bearing local state and keep it in a backup rotation.
- `README.md` stays at the repo root.

# Recommendations
- Give the reason with the recommendation, not in surrounding prose. One line: what makes it better than the alternative you're rejecting.
- Say what it costs or gives up. A recommendation with no stated downside hasn't been weighed.
- This applies inside `AskUserQuestion` options too — the option that says "(Recommended)" carries its own justification, since the prose above it may not be read alongside it.
- Where you're unsure, say so and say what would settle it.

# Code comments
- Default to zero comments. Keep one only when it prevents a concrete regression — a terse guard on a genuine footgun where deleting the line silently breaks something. Anything that explains *why* goes in the docs.
- No rationale, no dated verification notes (`VERIFIED against X on <date>`), no narration of what a block does.
- This covers every human-readable string, not just comment syntax — task and step names, log lines, assert and error messages. Write `Check systemd-sysctl state`, not `Check systemd-sysctl state (the 243/CREDENTIALS canary)`. No parenthetical asides restating a condition or justifying why the code exists.
- Error and assert messages must not cite a file path — the file gets moved and the message becomes a dangling pointer in failure output.
- Applies to code blocks inside plans and specs too, since those get pasted verbatim.

# Shell tools
- `grep` on this machine is **ripgrep**, not GNU grep. Adjust flags accordingly.
  - Patterns are regex by default — **never pass `-E`**. In rg, `-E` means `--encoding` and fails with `unknown encoding: <your pattern>`.
  - Use `-F` for a literal string, `-P` for PCRE2 (lookaround, backreferences).
  - rg is recursive by default and skips `.gitignore`d and hidden files. Use `-u` to include ignored, `-uu` for ignored + hidden. This matters when searching `.docs/`, `.dev/`, `.env`, or anything else gitignored.
  - An empty result over a hidden or gitignored tree is a **tooling failure until proven otherwise**, not an absence — rg returns zero matches, not an error. Before concluding something isn't there, search for a string you know is present.
  - Don't combine `-l` and `-c` in one invocation; it produces empty output rather than a complaint.
  - `grep -r pat .` → `rg pat`. `--include=GLOB` → `-g GLOB`. `-l/-c/-o/-i/-v/-w/-n/-A/-B/-C` all behave the same.
  - Reading stdin works normally, so `cmd | grep pat` is fine — just without `-E`.

# Multi-agent workflow
- Codex is your senior coding teammate: use Codex by asking for help or opinions as you work through difficult problems and need to consult another resource
- `/codex:review` — routine review of completed work, as tasks finish.
- `/codex:adversarial-review` — when the change is risky: auth, permissions, tenant isolation, data loss, migrations, schema change, rollback, retries, idempotency, concurrency, ordering. Codex tries to break confidence in the change rather than validate it, and reports material findings only. Review-only — it never fixes.
- `/codex:rescue` — investigations, bugs, and explicit fix requests.
- Findings from any of these come back through the `workflow:review-response` skill: verify against the codebase before agreeing, push back with reasoning where a finding doesn't hold.
