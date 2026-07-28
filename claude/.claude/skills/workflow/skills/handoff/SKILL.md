---
name: handoff
description: Use when work must continue in a different session, repo, or agent - writes the orientation document the next reader starts from. Not needed for mid-task compaction, which preserves context automatically.
---

# Handoff

Write the document the next reader opens first. Assume they have none of this session's context and no memory of the decisions in it.

Write one when work crosses a boundary — a new session tomorrow, a different repo, a handover to Codex or to a person. **Not** for mid-task context pressure: compaction carries that, and stopping early to hand off wastes the run.

Save to `.dev/handoff/YYYY-MM-DD-<topic>.md`. That tree is gitignored, so the next session reads it off the local checkout — a handoff never travels in a commit or a PR.

## Sections

Drop any that would be empty. Keep the order — it's the order the reader needs them in.

**1. Read first, in order.** A numbered list of exactly what to open, starting with `CLAUDE.md`, then this file, then the spec, plans, and any memory to recall. The next session's first move is reading; make it unambiguous.

**2. What you're building.** One paragraph. What and why, not how.

**3. State of the world.** Where things actually stand — branches, what's merged, what's running. **Give the command to re-verify, never a pinned SHA.** A SHA in a handoff is stale before it's read.

**4. Decisions made — do not relitigate.** Everything already settled with the user, and the reasoning in one line each. Without this section the next session re-opens closed questions and spends the user's time twice.

**5. Traps.** Each thing that cost real time to discover: environment gotchas, tooling that misbehaves here, a step that looks skippable and isn't. Say what happens if it's ignored. This is the highest-value section — it's the part that can't be re-derived from the repo.

**6. Next action.** The single concrete thing to do first.

**7. Carried open items.** Known-open work that belongs to nobody else yet. Mark what blocks and what doesn't.

**8. Done when.** The finish condition, in terms that can be checked.

## What goes somewhere else

- **A durable fact that outlives this effort** — a tool's quirk, a machine's config, a preference — belongs in memory. Write it there and link it from the handoff as `[[memory-name]]`. Don't inline it.
- **Anything explaining why the system is the way it is** — architecture, conventions, deploy procedure — goes in `.docs/`, folded into the file that owns the topic.
- **Per-task progress inside a running plan** belongs in the implementation ledger, not here. The handoff points at the ledger; it doesn't duplicate it.

A handoff carries orientation for *this* effort. Everything durable should have already moved out of it.

## Size

Keep it under about 150 lines. A handoff nobody finishes reading has failed at its only job.

If it's growing past that, the excess is usually durable content that belongs in `.docs/` or memory — move it rather than trimming detail out of the traps.
