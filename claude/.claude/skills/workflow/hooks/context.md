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

**Reach for workflow:spec before building something new — including when it
looks small.** Don't write code against a design you haven't shown the user.
