Workflow skills are available:

  user asks for a spec, or a design decision is theirs  ->  workflow:spec
  stress-test an existing idea                          ->  workflow:grill
  question needs outside sources                        ->  workflow:research
  approved spec                                         ->  workflow:plan
  bug, test failure, surprise                           ->  workflow:debug
  review findings came back                             ->  workflow:review-response
  work continues elsewhere                              ->  workflow:handoff

  /workflow:implement and /workflow:finish are user-invoked only.

Artifacts: .dev/spec/, .dev/plan/, .dev/implementation/, .dev/handoff/
Durable docs: .docs/

Both trees are gitignored local state — write them, never commit them, and
never count them as part of a diff or PR.

**Build directly by default.** Features, fixes and changes go straight to
code: state the approach in a line or two and build it, with tests. Reach for
workflow:spec only when the user asks for one, or when the work spans several
subsystems or turns on a design choice that is the user's to make.

**Keep moving.** Stop only for:

- a major decision — hard to reverse, visible outside this machine (push, PR,
  deleting work), or a real trade-off in scope or design
- uncertainty that would change the outcome, which the code, history or docs
  can't resolve
- a blocker

Everything else: pick the reasonable option, note it, and continue. When you
do stop, put every open question in one message.

A repo that defines its own spec, plan or commit workflow in its CLAUDE.md or
project skills overrides this one.
