---
date: 2026-11-13
spec: 080 (#343)
tags: [documentation, design-system, ci, plans]
---

# Lesson: "YARD builds without warnings" is no evidence for design-system documents

## Context

Spec 080's documents (the design-system README's rules, `StatusBand.md`, `Sheet.md`, `Scanner.md`) live under `docs/design-system/`. The verification needed evidence that they are well formed and that their links resolve.

## What happened

`.yardopts` builds only the code comments plus `docs/architecture/` and `docs/adr/` as extra pages. Nothing under `docs/design-system/` reaches the YARD build, so the `bin/ci checks` step "Docs: YARD builds without warnings" passes whatever those files say: a broken link or a stray `{…}` there fails nothing.

## What to do next time

- In a plan, don't cite the YARD step as proof for a design-system document. Verify those documents by reading them, and quote the reading in `verification.md`, as `.claude/rules/testing.md` asks for prose documents.
- Check relative links in a design-system document by hand, or with a throwaway script that is never committed.

## Signals to watch for

- A plan's verification table that lists "YARD builds" against a file outside `docs/architecture/`, `docs/adr/`, `app/` or `lib/`.
