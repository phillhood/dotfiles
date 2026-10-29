---
name: finish
description: Use when implementation is complete and the work needs to land - merged, pushed as a PR, or left on its branch. Verifies tests, runs the review, then lands it - merging locally on its own, asking before anything is pushed.
---

# Finish

## 1. Tests

Run the project's full suite (`npm test`, `cargo test`, `pytest`, `go test ./...`).

**Tests must be green before anything lands.** If they fail, show the failures and stop.

## 2. Note the workspace

Capture these now — step 5 changes directory, and cleanup still needs them:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
WORKTREE=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
```

## 3. Confirm the base branch

The base is whatever this work forked from — named in the plan, the conversation, or the branch's upstream; failing those, the branch `git merge-base` puts closest. Ask only when two candidates are plausible: "This branch split from `<best guess>` — correct?" Merging into the wrong base is expensive to undo.

## 4. Review

Review the branch against the base before it lands. Pick one by what the change touches:

| Change | Reviewer |
|---|---|
| Routine — config, docs, a contained fix | `/code-review medium` |
| Non-trivial — new behaviour, several files, a public interface | `/codex:review --base <base> --wait` |
| Auth, permissions, tenant isolation, data loss, migrations, schema, rollback, retries, idempotency, concurrency, ordering | `/codex:adversarial-review --base <base> --wait` |

Coming from `workflow:implement`, its final review already covered the branch — skip this step unless the change hits the last row and the final review wasn't adversarial.

Findings go through `workflow:review-response`. Fixes re-run the suite before landing.

## 5. Land it

Check whether the repo lands work through PRs:

```bash
git log --merges -30 --format=%s | grep -ci -e 'pull request' -e 'merged pr' -e 'merge request'
ls .github/pull_request_template.md .gitea/pull_request_template.md .forgejo/pull_request_template.md 2>/dev/null
```

Also count it as a PR repo when its CLAUDE.md or contributing docs say so.

**No PR workflow — merge into `<base>` locally without asking.** Report the merge in one line.

**PR workflow — ask before anything leaves the machine:**

```
Implementation complete and reviewed. Push and open a PR, or keep the branch as-is?
```

Never push, open a PR, or delete a remote branch without that answer.

**Merge before removing anything.** Merge, confirm it succeeded, re-run the suite on the merged result, and only then tear down the workspace. A clean merge that breaks on integration is still a broken merge.

Commit and PR text follows the repo's conventions — model it on the recent history, including whether it uses prefixes. No `Co-Authored-By` trailer.

Pushing for a PR, or keeping the branch, keeps the workspace.

## 6. Clean up

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
