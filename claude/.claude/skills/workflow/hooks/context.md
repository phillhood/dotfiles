Workflow skills are available:

  new feature / behaviour change  ->  workflow:spec
  stress-test an existing idea    ->  workflow:grill
  question needs outside sources  ->  workflow:research
  approved spec                   ->  workflow:plan
  written plan                    ->  workflow:implement
  bug, test failure, surprise     ->  workflow:debug
  writing a feature or fix        ->  workflow:tdd
  about to claim done             ->  workflow:verify
  review findings came back       ->  workflow:review-response
  work ready to land              ->  workflow:finish
  work continues elsewhere        ->  workflow:handoff

Artifacts: .dev/spec/, .dev/plan/, .dev/implementation/, .dev/handoff/
Durable docs: .docs/

Both trees are gitignored local state — write them, never commit them, and
never count them as part of a diff or PR.

**Reach for workflow:spec before building something new.** Small, unambiguous
work — a few files, no new interface, nothing you'd have to ask — skips it:
state the design in a line or two and build. Anything with a real choice in it
gets the spec and its approval.

**Keep moving.** The approved spec is the one planned stop. After it, plan,
implement, review and a local merge run without check-ins. Stop only for:

- a major decision — hard to reverse, visible outside this machine (push, PR,
  deleting work), or a real trade-off in scope or design the spec didn't settle
- uncertainty that would change the outcome, which the code, history or docs
  can't resolve
- a blocker

Everything else: pick the reasonable option, record it in the spec, plan or
ledger, and continue. When you do stop, put every open question in one message.

A repo that defines its own spec, plan or commit workflow in its CLAUDE.md or
project skills overrides this one.
