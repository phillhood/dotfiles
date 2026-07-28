---
name: research
description: Use when a question needs investigating against outside sources - library behaviour, API facts, protocol details, comparing tools. Produces a cited findings document. Not for exploring this codebase.
---

# Research

Investigate a question against sources that can be checked, and write down what you found with its provenance.

## Primary sources

Go to the thing itself: official documentation, the library's source, the specification, the first-party API. Not a blog post summarising it, not a Stack Overflow answer quoting a version from three years ago.

Where a secondary source is the only one available, say so explicitly and mark the claim as unverified.

**Every claim carries its source.** A claim you can't attribute doesn't go in the document. Link the page, name the file and line, give the version you checked against — version matters more than anything else here, and a fact without one rots silently.

**Say what you couldn't establish.** A named gap is worth more than a plausible-sounding guess, and it tells the reader where to look next. Never fill a hole with something that sounds right.

## Output

One file. Fold it into the `.docs/` file that already owns the topic if there is one; otherwise create `.docs/<topic>.md` and say where you put it. That tree is gitignored — don't commit it.

Structure it as: the question, what you found, and the open gaps. Group findings by claim, each with its source inline — not a bibliography at the bottom that nobody maps back.

If the finding is only relevant to the task in hand and won't outlive it, it belongs in the spec or the handoff instead.

## Delegating

When the reading is broad enough that it would fill this session's context — several sources, a lot of pages — offer to run it in a subagent and say why. Don't dispatch one unasked.

A subagent gets: the question, the sources to start from, the output path, and the sourcing rules above. It returns the file path, not the findings.
