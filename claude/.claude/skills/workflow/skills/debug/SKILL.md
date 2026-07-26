---
name: debug
description: Use when hitting a bug, test failure, crash, or any unexpected behaviour, before proposing a fix. Finds the root cause first rather than treating the symptom.
---

# Debug

**No fixes without a root cause.** A fix you can't explain the cause of is a guess, and a guess that makes the symptom disappear is worse than no fix — it hides the real defect.

Work the phases in order. Don't start proposing fixes from phase 1.

## 1. Investigate

**Read the error properly.** All of it, including the stack trace. Note line numbers, file paths, error codes. The exact solution is often already in the message.

**Reproduce it reliably.** What are the exact steps? Does it happen every time? If you can't reproduce it, gather more data — don't start guessing.

**Check what changed.** Recent commits, `git diff`, new dependencies, config changes, environment differences.

**Instrument the boundaries** when the system has multiple components (CI → build → sign, API → service → database). Before proposing anything, log what enters and what exits each component, and verify config and environment propagate across each boundary. Run once to find *where* it breaks, then investigate that component. Guessing which layer is at fault wastes the most time in exactly these systems.

**Trace backward.** Where does the bad value originate? What called this with it? Keep walking up until you reach the source, and fix there. See `references/root-cause-tracing.md`.

## 2. Compare against something that works

Find similar working code in the same codebase. If you're implementing a known pattern, read the reference implementation completely — every line, not a skim.

Then list every difference between working and broken, however small. "That can't matter" is how root causes get missed.

Check what the broken path depends on that the working one doesn't: config, environment, assumptions about state.

## 3. Hypothesise

State one hypothesis, specifically: "X is the root cause, because Y."

Test it with the smallest possible change. One variable at a time.

If it worked, go to phase 4. If it didn't, form a *new* hypothesis — do not stack another fix on top of the failed one. If you don't understand something, say so rather than working around the gap.

## 4. Fix

Write a failing test that reproduces the bug first — see `workflow:tdd`. Then fix the cause you identified, not the symptom, and confirm the original reproduction now passes.

Consider whether the same defect exists elsewhere, and whether a guard at another layer would have caught it. See `references/defense-in-depth.md`.

## No root cause found

Say so. Report what you ruled out and what you'd need to narrow it further. Shipping a plausible-looking change you can't justify is the failure this skill exists to prevent.

## References

- `references/root-cause-tracing.md` — tracing a bad value backward through the call stack
- `references/defense-in-depth.md` — adding validation at multiple layers once the cause is known
- `references/condition-based-waiting.md` — replacing arbitrary timeouts with condition polling
