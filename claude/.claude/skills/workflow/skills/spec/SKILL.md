---
name: spec
description: Use before any creative work - new features, components, functionality, or behaviour changes. Explores intent, constraints and design, and produces an approved design document.
---

# Spec

Turn an idea into an agreed design, then write it down.

**No code, no scaffolding, no other skill until the design is approved.** This holds for small work too — "simple" is where unexamined assumptions cost the most. A short design is fine. Skipping it is not.

## Steps

Create a todo per step.

1. **Read the project first.** Files, README, recent commits.
2. **Check the scope.** If the request covers several independent subsystems, say so before spending questions on detail. Decompose, then spec the first piece. Each piece gets its own spec → plan → implementation cycle.
3. **Ask one question per message.** Purpose, constraints, success criteria. Multiple choice where it fits, open-ended where it doesn't.
4. **Offer 2-3 approaches** with trade-offs. Lead with your recommendation and say why. Cut anything YAGNI.
5. **Present the design in sections**, each scaled to its complexity — a sentence where it's obvious, a few hundred words where it isn't. Ask after each whether it holds. Cover architecture, components, data flow, error handling, testing.
6. **Write it to `.dev/spec/YYYY-MM-DD-<topic>.md`** and commit.
7. **Self-review the file, fix inline:** placeholders and TBDs, sections that contradict each other, scope that needs splitting, requirements readable two ways.
8. **Hand it over and wait:** "Spec written to `<path>`. Review it and tell me what to change before I plan."
9. **Then `workflow:plan`.** No other skill.

## Architecture decisions

Offer an ADR only when all three hold:

1. **Hard to reverse** — changing course later costs real work.
2. **Surprising without context** — a future reader will ask "why this way?"
3. **A real trade-off** — genuine alternatives existed and you picked one for stated reasons.

Any one missing, skip it — the decision belongs in the spec, not its own record. Records go to `.docs/adr/NNNN-<slug>.md`: the decision, the alternatives, why this one, and what it costs.

## Designing units

Break the system into pieces with one purpose each, communicating through defined interfaces. For each, you should be able to say what it does, how it's used, and what it depends on.

If you can't understand a unit without reading its internals, or can't change its internals without breaking callers, the boundary is wrong.

Prefer small focused files. A file that has grown large is usually doing too much — and edits are more reliable in files that fit in context at once.

## New projects

A greenfield repo has no conventions to match, so whatever the first few files do becomes the convention by accident. Settle the ones that bind every later task before planning, and record them in the spec — they become the plan's Global Constraints, which every task and every reviewer inherits.

Ask about them together, once, rather than as each comes up:

- **Doc comments** — the language's standard form on the public API, none, or enforced by a linter. Recommend the ecosystem's default: Go and Rust expect documented exports, a published library in any language does, an internal app or a script usually doesn't.
- Test framework and test layout
- Formatter and linter, and whether they run in CI

## Existing codebases

Explore the structure before proposing changes, and follow the patterns already there. Where existing code genuinely obstructs the work — a tangled file you have to touch, an unclear boundary — fold a targeted fix into the design. Don't propose unrelated refactoring.
