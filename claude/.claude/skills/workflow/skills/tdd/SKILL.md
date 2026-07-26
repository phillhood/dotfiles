---
name: tdd
description: Use when implementing any feature or bugfix, before writing implementation code. Covers the red-green-refactor cycle and what makes a test honest.
---

# TDD

**No production code without a failing test first.** If you wrote the code first, delete it and start over — don't keep it as reference, don't adapt it, don't look at it while writing the test. Implement fresh from the test.

## The cycle

**RED** — write the failing test.

**Verify RED** — run it. Watch it fail, and check it fails for the *right reason*. A test that fails because of a typo or a missing import proves nothing.

**GREEN** — the minimum code that passes. Not the design you have in mind; just enough.

**Verify GREEN** — run it. Watch it pass.

**REFACTOR** — clean up with the tests staying green.

Repeat. Commit at each green point.

## Honest tests

**Before writing a test, name the production change that would make it fail.** If you can't name one, the test proves nothing — don't write it.

- **Assert on real behaviour.** A test asserting that a mock was called tests your mock.
- **Test-only helpers live in test utilities**, never in production classes.
- **Understand a dependency's side effects before mocking it.** A mock that doesn't match real behaviour passes while production breaks.
- **One behaviour per test.** "and" in the test name means split it.
- **Name the behaviour, not the number.** `test_rejects_expired_token`, not `test3`.

## Bug fixes

The failing test comes first and reproduces the reported symptom. Watch it fail, fix the cause, watch it pass. That test is now the regression guard — without having seen it fail, you don't know it guards anything.

## When stuck

If a test is hard to write, that's usually the design talking: too many dependencies, unclear boundaries, or the unit doing more than one thing. Fix the design rather than writing a test that contorts around it.
