# Git commits
- Do not add a `Co-Authored-By` trailer or any "Generated with Claude Code" annotation to commits.
- Write simple, lowercase commit messages (e.g. `fix login redirect`, not `Fix: Login Redirect`).

# Project docs
- Never create or write to a top-level `docs/` directory in a repo. Everything that would go in `docs/` goes in `.dev/docs/` instead — specs, plans, handoffs, design notes, deploy guides, research.
- `.dev/` is local-only and must stay out of git. It is already in `~/.gitignore_global`; also add `.dev/` to the repo's own `.gitignore` so the rule survives a clone, and to `.dockerignore` where one exists.
- `README.md` stays at the repo root. If an existing repo has a `docs/` directory, move it to `.dev/docs/` and fix any references rather than adding to it.

# Multi-agent workflow
- Codex is your senior coding teammate: use Codex by asking for help or opinions as you work through difficult problems and need to consult another resource
- Ask Codex for reviews as you complete tasks with `/codex:review` or ask for help with investigations, bugs or fix requests with `/codex:rescue`
