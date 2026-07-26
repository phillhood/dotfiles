---
name: verify
description: Use before claiming work is complete, fixed, or passing, and before committing or opening a PR. Requires running the proving command and reading its output first.
---

# Verify

**No completion claim without fresh evidence.** If you have not run the command in this message, you cannot say it passes.

## The gate

Before any status claim:

1. What command proves this?
2. Run it — full and fresh, not a subset.
3. Read all the output and the exit code.
4. Does it actually confirm the claim?
5. Only then say it.

If the answer at step 4 is no, state the real status with the output.

## What counts as evidence

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | test output, 0 failures | an earlier run, "should pass" |
| Linter clean | linter output, 0 errors | a partial check, extrapolation |
| Build succeeds | build exit 0 | linter passing, logs look fine |
| Bug fixed | the original symptom retested | the code changed, assumed fixed |
| Regression test works | seen to fail, then pass | passes once |
| Subagent completed | git diff shows the changes | the agent reported success |
| Requirements met | line-by-line against the spec | tests passing |

## Before evidence, don't say

"Should", "probably", "seems to", "Done!", "Perfect!", or any wording that implies success you haven't demonstrated.

Being tired, being nearly finished, and having done it correctly last time are not evidence.
