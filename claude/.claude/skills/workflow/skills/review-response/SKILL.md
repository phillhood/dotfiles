---
name: review-response
description: Use when review findings come back - from codex, a review subagent, or a person - before implementing any of them. Requires verifying findings against the codebase rather than agreeing on reflex.
---

# Review response

Findings are technical claims to evaluate, not instructions to execute. They arrive from `/codex:review`, `/codex:adversarial-review`, `/code-review`, a review subagent, or a person. Same handling either way.

## The pattern

1. **Read all of it** before reacting to any of it.
2. **Restate the requirement** in your own words, or ask.
3. **Verify it against the codebase.** Reviewers are wrong sometimes, and a reviewer working from a diff cannot see what surrounds it.
4. **Evaluate it for *this* codebase** — its patterns, its constraints, its scale.
5. **Respond technically**, or push back with reasoning.
6. **Implement one item at a time**, testing each.

**Verify before implementing.** Agreeing to a finding you haven't checked is how a reviewer's wrong guess becomes your bug.

## Don't say

"You're absolutely right!" — "Great point!" — "Excellent feedback!" — "Let me implement that now", before verifying.

Restate the technical requirement, ask a question, push back, or just start working. Actions over acknowledgement.

## Unclear items

**If any item is unclear, stop and ask about all of it.** Don't implement the parts you understood and ask about the rest later — review items are frequently related, and partial understanding produces the wrong implementation.

> "I understand items 1, 2, 3 and 6. I need clarification on 4 and 5 before starting."

## Adversarial findings

`/codex:adversarial-review` returns findings with confidence scores, and it is explicitly trying to break confidence in the change rather than validate it. Low confidence is not dismissal and high confidence is not proof — verify either way. It reports only material risks, so a finding you can't reproduce deserves a second look before you rule it out.

## Pushing back

Push back when a finding doesn't hold: state what you checked and what you found. Where a reviewer suggests capability the work doesn't need, say YAGNI and say why.

If you pushed back and the reviewer was right, correct it plainly and continue. No preamble.
