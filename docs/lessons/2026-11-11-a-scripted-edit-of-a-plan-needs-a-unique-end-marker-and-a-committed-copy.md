---
date: 2026-11-11
spec: 073 (#50)
tags: [process, plans, tooling]
---

# Lesson: a scripted edit of a plan needs a unique end marker and a committed copy

## Context

Spec 073's plan was revised after review with a small Python helper that replaced the text between two markers (`block(start, end, new)`). The plan was written, reviewed and still untracked when the helper ran.

## What happened

- One call used `"  end\nend\n"` as the end marker. That text also closes the code block of a spec file much later in the plan, so the helper deleted everything between: Task 4.3 through Phase 6 (about 280 lines). The helper printed "ok" and nothing noted the span's size.
- The text was still in the conversation, so it was rebuilt, but only because the session held it. The plan had no commit to restore from.

## What to do next time

Commit (or copy aside) the document before a scripted multi-edit. Make each end marker unique in the file (assert `count == 1`) and print the length of the replaced span; or use the Edit tool, which refuses an ambiguous match. After a script, check the heading list (`grep -n '^## \|^### '`) and the line count before moving on.

## Signals to watch for

- An end marker that is a closing `end`, a fence or a blank line.
- A helper that reports success without the size of what it replaced.
