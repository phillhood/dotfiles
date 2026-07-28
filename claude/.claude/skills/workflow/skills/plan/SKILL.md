---
name: plan
description: Use when an approved spec or written requirements exist and work is about to start. Produces a task-by-task implementation plan before any code is written.
---

# Plan

Write the plan for an engineer who is skilled but knows nothing about this codebase, this toolset, or this problem domain. Everything they need goes in the plan: which files, what code, how to test it, what to check.

Save to `.dev/plan/YYYY-MM-DD-<feature>.md`. That tree is gitignored — the plan is local state, not a commit.

## Before writing tasks

**Scope check.** If the spec covers several independent subsystems, split it into one plan per subsystem. Each plan must produce working, testable software on its own.

**Map the file structure.** List what gets created and modified, and what each file is responsible for. This is where decomposition gets locked in.

- One clear responsibility per file. Files that change together live together — split by responsibility, not by layer.
- Follow the codebase's existing patterns. Don't unilaterally restructure; but if a file you're already modifying has grown unwieldy, planning a split is reasonable.

## Task sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate.

Fold setup, configuration, scaffolding and documentation into the task whose deliverable needs them. Split only where a reviewer could sensibly reject one task and approve its neighbour. Every task ends with something independently testable.

## Plan header

```markdown
# <Feature> Implementation Plan

**Goal:** <one sentence>

**Architecture:** <2-3 sentences>

**Tech Stack:** <key technologies>

## Global Constraints

<Project-wide requirements from the spec — version floors, dependency limits,
naming and copy rules, platform requirements. One line each, exact values
copied verbatim. Every task implicitly includes this section.>

---
```

## Task structure

````markdown
### Task N: <Component>

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: <what this uses from earlier tasks — exact signatures>
- Produces: <exact names, parameter and return types later tasks rely on.
  A task's implementer sees only its own task; this is how it learns the
  names its neighbours expect.>

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run it, expect failure**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL, "function not defined"

- [ ] **Step 3: Minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run it, expect pass**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**
````

Each step is one action, 2-5 minutes. Code steps contain real code.

Code in a plan gets pasted verbatim, so it follows the same rules as committed code: no comments, no narration, no rationale.

## No placeholders

These are plan failures. Never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above", without the test code
- "Similar to Task N" — repeat the code; tasks get read out of order
- Steps describing what to do without showing how
- References to types, functions or methods no task defines

## Self-review

Run this yourself against the spec, then fix inline. No second pass.

1. **Coverage** — walk each spec requirement. Point at the task implementing it. List gaps, then add the missing tasks.
2. **Placeholders** — search for the patterns above.
3. **Type consistency** — do names and signatures in later tasks match what earlier tasks defined? `clearLayers()` in Task 3 and `clearFullLayers()` in Task 7 is a bug.

## Handoff

Save the plan, then say where it is and hand to `workflow:implement`.
