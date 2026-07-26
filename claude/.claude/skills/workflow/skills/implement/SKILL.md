---
name: implement
description: Use when a written plan exists and the work should be built. Dispatches a fresh subagent per task with review gates between them, tracking progress in a ledger that survives compaction.
---

# Implement

Execute a plan task by task. Each task gets a fresh implementer subagent, a review, and a fix loop; the branch gets one broad review at the end.

Subagents never inherit your session history — you construct exactly what each one needs. That keeps them focused and keeps your own context free for coordination.

**Execute all tasks without stopping.** Don't check in between them. The only reasons to stop are a blocker you can't resolve, ambiguity that genuinely prevents progress, or completion. Between tool calls, narrate at most one short line — the ledger and the tool results are the record.

## Setup

**Isolation.** Check whether you're already isolated:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
git rev-parse --show-superproject-working-tree
```

`GIT_DIR != GIT_COMMON` means a linked worktree — **unless** the third command prints a path, which means a submodule. Already isolated: use it, don't nest.

Otherwise ask before creating one, unless the user has already said to use worktrees. Then `EnterWorktree`.

**Symlink the local trees.** A worktree checks out tracked files only, so `.dev` and `.docs` aren't there:

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
ln -s "$MAIN/.dev" .dev
ln -s "$MAIN/.docs" .docs
```

This also means the ledger written inside the worktree lands in the main checkout and survives `git worktree remove`.

**Never start on main or master without explicit consent.**

**Baseline.** Install dependencies, then run the full suite. It must be green before Task 1, so that a later failure is unambiguously yours.

**Workspace and ledger.** Run `scripts/workspace PLAN_FILE` — it prints this plan's artifact directory (`.dev/implementation/<plan-basename>/`), holding the ledger, briefs, reports and review packages for *this* plan only. Another plan's directory is never yours to touch.

Check for `<workspace>/progress.md`:

- First line names your plan file: tasks with a `Task <N>: complete` line are **done**. Resume at the first without one. A task whose last line is a fix round is mid-loop — resume at the next round.
- First line names a different plan: leave it, start your own.
- Absent: create it, with its identity on line one — `# ledger — plan: <path>`.

**Trust the ledger over your own recollection.** Conversation memory doesn't survive compaction; the commits the ledger names exist in git regardless. Controllers that lost their place have re-dispatched entire completed task sequences — the most expensive failure this loop has. After a compaction, believe the ledger and `git log`, not your memory.

`git clean -fdx` destroys the workspace. If that happens, rebuild from `git log`.

**Read the plan once.** Note its context and Global Constraints. Create a todo per task.

**Pre-flight scan.** Before Task 1, read the plan for conflicts: tasks contradicting each other or the Global Constraints, and anything the plan mandates that a reviewer would call a defect (a test asserting nothing, a duplicated logic block). Present everything you find as one batched question — each finding beside the plan text mandating it — and ask which governs. Clean scan: proceed silently.

## Tightly-coupled plans

If the plan's tasks are genuinely coupled — each depending on the previous task's in-flight state — work them inline in this session instead of dispatching. Same ledger, same commit per task, same test discipline. Fresh subagents fight each other on coupled work.

Everything below assumes the dispatching path.

## Model selection

Use the least capable model that can do the job, and **always name it explicitly** — an omitted model inherits your session's, usually the most expensive.

- Plan text contains the complete code: transcription plus testing, cheapest tier.
- 1-2 files with a complete spec: cheap.
- Multiple files, integration concerns: standard.
- Design judgement or broad codebase understanding: most capable.
- Reviewers: scale to the diff's size and risk. Scoped re-reviews of small fix diffs are cheap-to-mid.
- Fix rounds 4-5: at least one tier above the implementer that got stuck.
- Final whole-branch review: most capable.

Turn count beats token price. The cheapest models often take 2-3× the turns on multi-step work and cost more overall, so use mid-tier as the floor for reviewers and for implementers working from prose.

## The task loop

Everything you paste into a dispatch, and everything a subagent prints back, stays in your context for the rest of the session and is re-read every turn. **Hand artifacts over as files.**

### 1. Dispatch the implementer

Record BASE (`git rev-parse HEAD`) first — the review package needs it.

Run `scripts/task-brief PLAN_FILE N`. It writes the task's full text to a file and prints the path.

The dispatch contains: one line on where this task fits; the brief path, introduced as "read this first — it is your requirements, use its exact values verbatim"; interfaces and decisions from earlier tasks the brief can't know; your resolution of any ambiguity you spotted; and the report-file path (`task-N-report.md`, beside the brief).

Exact values — numbers, magic strings, signatures, test cases — appear **only in the brief**. Never make a subagent read the whole plan.

A dispatch describes one task, not the session's history. Don't paste accumulated prior-task summaries into later dispatches. If an earlier task parked a finding in this area, carry a pointer to that ledger line.

Record the implementer's agent identity — rounds 1-3 resume it. Never run implementers in parallel.

Template: `prompts/implementer.md`

### 2. Handle the report

**DONE** — generate the review package and dispatch the reviewer.

**DONE_WITH_CONCERNS** — read the concerns. Correctness or scope: address before review. Observations: note and proceed.

**NEEDS_CONTEXT** — supply what's missing, re-dispatch.

**BLOCKED** — assess. Context problem: add context, same model. Needs more reasoning: stronger model. Too large: split it. Plan is wrong: escalate to the user.

Never ignore an escalation, and never make the same model retry unchanged. If the implementer said it's stuck, something has to change.

### 3. Review the task

Both verdicts are required — spec compliance **and** code quality. Never skip the task review; the implementer's self-review doesn't replace it.

Run `scripts/review-package PLAN_FILE BASE HEAD` and pass the reviewer the path it prints. Use the BASE you recorded — **never `HEAD~1`**, which silently drops all but the last commit of a multi-commit task. **Never dispatch a reviewer without a diff file.**

The reviewer gets three paths — brief, report, review package — plus the Global Constraints that bind this task, copied verbatim: exact values, exact formats, and stated relationships between components. The template already carries the process rules; the constraints block is for what this project demands.

**Don't pre-judge findings.** If your prompt contains "do not flag", "don't treat X as a defect", "at most Minor", or "the plan chose" — stop. You're sparing yourself a review loop. Let the reviewer raise it; adjudicate afterwards.

Don't add open-ended directives without a concrete reason, and don't ask a reviewer to re-run tests the implementer already ran.

"⚠️ Cannot verify from diff" items are requirements living in unchanged code or spanning tasks. They don't block the review, but resolve each one yourself before completing the task — you hold the cross-task context. A confirmed gap enters the fix loop.

Template: `prompts/task-reviewer.md`

### 4. The fix loop

Triggers on spec ❌, any Critical or Important finding, or a ⚠️ you confirmed real.

Two things leave immediately:

- **Minor findings** go to the ledger (`Task <N>: minor (deferred): <one-liner>`) and get pointed out to the final review. They never enter the loop.
- **Plan-mandated findings** — anything conflicting with what the plan requires — are the user's call. Present the finding beside the plan text and ask which governs. Don't dismiss it because the plan mandates it, and don't dispatch a fix contradicting the plan.

Everything else loops. One fix dispatch plus one scoped re-review is a round. **Five rounds maximum.**

**Rounds 1-3:** resume the original implementer with the open findings verbatim. Its context is intact.

**Rounds 4-5:** fresh implementer, stronger model, framed as "a prior implementer attempted this [N] times; you own it now — read the report file for what was tried." Three failed resumes usually means it can't see its own problem.

Every round the implementer fixes, re-runs the tests covering the amended code, appends to the same report file, and returns the short contract. Confirm the fix report has the covering tests, the command, and the output before re-dispatching the reviewer.

The re-review is **scoped**: `scripts/review-package PLAN_FILE FIX_BASE HEAD` where FIX_BASE is the head the last review saw. The re-reviewer verdicts each finding ADDRESSED or NOT ADDRESSED and flags new breakage in the fix diff only. New Critical/Important breakage joins the open list; out-of-scope observations go to the ledger as deferred minors and never extend the loop.

Append after each round: `Task <N>: fix round <R>/5 (<X> addressed, <Y> open — <one-liners>; commits <a7>..<b7>)`

**Never fix findings yourself in the controller session.** Controller fixes pollute your context and skip review entirely.

Template: `prompts/re-review.md`

**At the cap.** When round 5 still leaves findings open, stop dispatching and adjudicate each one — you hold the plan and cross-task context the reviewer lacks:

- **Reviewer wrong, or contestable:** park it — `Task <N>: parked — <finding> — ruling: <why the code stands>`.
- **Real, nothing downstream depends on it:** park it, ruling says real and deferred.
- **Real and load-bearing** — a later task builds on it, or it exposes a plan defect: **STOP.** Append `Task <N>: BLOCKED — <reason>` and report to the user with the finding, the plan text it collides with, and the fix history.

**Adjudicate only at the cap.** Doing it earlier to end a loop is pre-judging under a different name. Every adjudication is a ledger entry — silent discards are forbidden.

### 5. Complete the task

Review clean, or every finding parked with a ruling at the cap:

- `Task <N>: complete (commits <base7>..<head7>, review clean)`
- `Task <N>: complete (commits <base7>..<head7>, <K> parked)`

Confirm with `git diff` that the work exists — the implementer's report is not evidence. Then mark the todo done and move on.

Never advance while Critical or Important findings are neither fixed nor parked-with-ruling at the cap.

## Final review

Generate the package over the whole branch: `scripts/review-package PLAN_FILE MERGE_BASE HEAD`, where MERGE_BASE is `git merge-base <base-branch> HEAD`. Dispatch on the most capable model using `prompts/final-reviewer.md`, and point it at the ledger's deferred-minor and parked lines so it can triage what must be fixed before merge.

**Escalate to `/codex:adversarial-review`** when the branch touches auth, permissions or tenant isolation; data loss, migrations or schema change; rollback, retries or idempotency; or concurrency, ordering and re-entrancy. It reviews the same range and tries to break confidence in the change rather than confirm it. Findings from either reviewer come back through `workflow:review-response`.

If findings return, dispatch **one** fix subagent with the complete list — not one fixer per finding. Per-finding fixers each rebuild context and re-run suites. Then exactly one scoped re-review of the fix wave. Adjudicate residuals as at the cap: park with rulings, or stop on load-bearing ones. There is no second fix wave.

## Finish

Final review clean and fixes merged: delete this plan's workspace — git history is the record now. Leave sibling plan directories alone.

Then `workflow:finish`.
