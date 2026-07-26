---
name: finish
description: Use when implementation is complete and the work needs to land - merged, pushed as a PR, or left on its branch. Verifies tests, then presents the options.
---

# Finish

## 1. Tests

Run the project's full suite (`npm test`, `cargo test`, `pytest`, `go test ./...`).

**Tests must be green before the options appear.** If they fail, show the failures and stop. There is no menu after a red suite.

## 2. Note the workspace

Capture these now — step 4 changes directory, and cleanup still needs them:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
WORKTREE=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
```

## 3. Confirm the base branch

The base is whatever this work forked from — usually named in the plan, the conversation, or the branch's upstream. If it isn't already known, ask: "This branch split from `<best guess>` — correct?"

Confirm before merging. Merging into the wrong base is expensive to undo.

## 4. Present the options

```
Implementation complete. What next?

1. Merge into <base> locally
2. Push and open a PR
3. Keep the branch as-is
```

**Merge before removing anything.** Merge, confirm it succeeded, re-run the suite on the merged result, and only then tear down the workspace. A clean merge that breaks on integration is still a broken merge.

Commit and PR text follows the repo's conventions: lowercase, no `feat:`/`fix:`/`docs:` prefix, no scope parens, no `Co-Authored-By` trailer. Model the message on the repo's recent history.

Options 2 and 3 keep the workspace.

## 5. Clean up

Only after a successful merge, and only for a workspace this work created.

If `GIT_DIR` equals `GIT_COMMON`, it's a normal checkout — nothing to clean up.

If the session entered a worktree via `EnterWorktree`, use `ExitWorktree`. Otherwise the host environment owns the workspace: leave it alone.

The `.dev/implementation/<plan>/` artifacts go once the work is merged — git history is the record now. Leave sibling plan directories alone.

## Discarding

Only on an explicit request to throw the work away. Show exactly what will be destroyed:

```
This permanently deletes:
- Branch <name>
- Commits: <list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact word. Never infer a discard from frustration or from "this isn't working".
