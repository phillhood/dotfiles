# Git commits
- Do not add a `Co-Authored-By` trailer or any "Generated with Claude Code" annotation to commits.
- Write simple, lowercase commit messages.
- Model the message on the most recent handful of commits in that repo. Where a repo's history uses ticket IDs (`CORE-155 ...`) or prefixes (`fix(console): ...`), match the history.

# Project docs
- **Durable documentation goes where the repo already keeps docs** — `docs/`, a wiki directory, or the README. Design notes, deploy guides, roadmaps, conventions, anything explaining *why*. Fold new notes into the file that owns the topic rather than adding a new dated file. Where the repo has no docs location, create `docs/`.
- **`.dev/` holds working artifacts** — specs, plans, implementation ledgers, handoffs. It is committed like any other file. When the work lands, fold anything durable into the docs and delete that work's `.dev/` files as part of landing it.
- Scratch scripts and generated or backup output don't go in `.dev/`; use the session scratchpad.
- **A repo that ignores `.dev` in its own `.gitignore` has opted out on purpose.** Keep writing there, but never commit it.
- `README.md` stays at the repo root.

# Recommendations
- Give the reason with the recommendation, not in surrounding prose. One line: what makes it better than the alternative you're rejecting.
- Say what it costs or gives up. A recommendation with no stated downside hasn't been weighed.
- This applies inside `AskUserQuestion` options too — the option that says "(Recommended)" carries its own justification, since the prose above it may not be read alongside it.
- Where you're unsure, say so and say what would settle it.

# Verification and tests
- Before saying something works, is fixed, or passes, run the command that proves it — in full, fresh — and read the output and exit code. A subagent's report is not evidence; check the diff.
- A bug fix starts with a test that reproduces the symptom, seen failing before the fix.
- Before writing a test, name the production change that would make it fail. Assert on real behaviour, not on mocks.

# Code comments
- Default to zero comments. Keep one only when it prevents a concrete regression — a terse guard on a genuine footgun where deleting the line silently breaks something. Anything that explains *why* goes in the docs.
- No rationale, no dated verification notes (`VERIFIED against X on <date>`), no narration of what a block does.
- This covers every human-readable string, not just comment syntax — task and step names, log lines, assert and error messages. Write `Check systemd-sysctl state`, not `Check systemd-sysctl state (the 243/CREDENTIALS canary)`. No parenthetical asides restating a condition or justifying why the code exists.
- Error and assert messages must not cite a file path — the file gets moved and the message becomes a dangling pointer in failure output.
- Applies to code blocks inside plans and specs too, since those get pasted verbatim.

# Doc comments
- Doc comments (JSDoc/TSDoc, docstrings, rustdoc, godoc) are interface contracts consumed by tooling — IDE hover, generated docs, and in plain JS the type checker. They are not commentary, and the zero-comment rule above does not govern them.
- Match what the repo already does — check before writing. Where a linter enforces a style, follow that style exactly.
- Public and exported surface only. Internal helpers don't get them.
- Say only what the signature can't: units, ranges and invariants, what it throws and when, side effects and mutation, a non-obvious example, deprecation and its replacement.
- Never restate the signature. `/** Gets the name. @returns The name. */` on `getName(): string` is noise — delete it. That failure is what gives doc comments their bad name, and it's the same disease as narrating a block of code.
- A new project has no convention to match, so establish one explicitly and record it in the spec rather than letting the first few files settle it by accident.

# Shell tools
- `grep` on this machine is **ripgrep**, not GNU grep. Adjust flags accordingly.
  - Patterns are regex by default — **never pass `-E`**. In rg, `-E` means `--encoding` and fails with `unknown encoding: <your pattern>`.
  - Use `-F` for a literal string, `-P` for PCRE2 (lookaround, backreferences).
  - rg is recursive by default and skips `.gitignore`d and hidden files. Use `-u` to include ignored, `-uu` for ignored + hidden. This matters when searching `.env`, a repo-ignored `.dev/`, or anything else gitignored.
  - An empty result over a hidden or gitignored tree is a **tooling failure until proven otherwise**, not an absence — rg returns zero matches, not an error. Before concluding something isn't there, search for a string you know is present.
  - Don't combine `-l` and `-c` in one invocation; it produces empty output rather than a complaint.
  - `grep -r pat .` → `rg pat`. `--include=GLOB` → `-g GLOB`. `-l/-c/-o/-i/-v/-w/-n/-A/-B/-C` all behave the same.
  - Reading stdin works normally, so `cmd | grep pat` is fine — just without `-E`.
- **Python: never `python`, `python3`, `pip` or `pip3`.** A hook blocks them anywhere in the command. Use `uv run python` (`uv run python - <<'EOF'` for heredocs) or `uv pip`.
  - Don't edit files with a Python or sed replace script. Use the Edit tool for exact replacements and Write for new files.
- **Worktree-isolated sessions refuse any command they can't prove stays out of git.** These shapes get refused:
  - `xargs ... sh -c '...'` or `find -exec sh -c`: use a `for` loop over literal paths, or the Read tool.
  - A variable holding a path that gets passed to a command, like `S=/tmp/...; sops -d $S/x`: spell the path out.
  - Long `;`/`&&` chains that mix `cd`, `mktemp`, subshells and `$(...)`.
  - When one gets refused, split it into separate plain Bash calls with literal arguments. Don't retry the same shape.

# Autonomy
- Keep moving. Stop only for a major decision (hard to reverse, visible outside this machine, or a real trade-off in scope or design), uncertainty the code, history or docs can't resolve, or a blocker.
- Everything else: pick the reasonable option, note it, and continue. When you do stop, put every open question in one message.

# Codex
- Codex is your senior coding teammate: use Codex by asking for help or opinions as you work through difficult problems and need to consult another resource
- `/codex:rescue` — investigations, bugs, and explicit fix requests.
