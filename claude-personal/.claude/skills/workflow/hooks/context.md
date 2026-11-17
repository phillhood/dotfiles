Workflow skills are available:

  user asks for a spec, or a design decision is theirs  ->  workflow:spec
  stress-test an existing idea                          ->  workflow:grill
  question needs outside sources                        ->  workflow:research
  work continues elsewhere                              ->  workflow:handoff

  /workflow:finish is user-invoked only.

Artifacts: .dev/spec/, .dev/handoff/ — committed with the work, removed when
it lands.
Durable docs: wherever the repo keeps docs, else docs/.

**Build directly by default.** Features, fixes and changes go straight to
code: state the approach in a line or two and build it, with tests. Reach for
workflow:spec only when the user asks for one, or when the work spans several
subsystems or turns on a design choice that is the user's to make.

Review happens when work lands — workflow:finish picks the reviewer.

A repo that defines its own spec or commit workflow in its CLAUDE.md or
project skills overrides this one.
