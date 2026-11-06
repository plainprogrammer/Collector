---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, review]
---

# Lesson: three claims an area doc gets wrong on a first draft

## Context

Writing `docs/architecture/catalog-core.md` (spec 027 slice C, #104) from specs 002, 004, 007, 009, 016, 018, 019 and 023, then a read-only review on Fable, statement by statement against the code. Round 1 found one major and several minor items; round 2 found two wording nits.

## What happened

Three kinds of error accounted for most findings:

- A sentence said "the specs index now lists them under this doc" while `docs/specs/README.md` was unchanged. The doc described a state a later commit would create.
- The card page's section was written as the core's content ("type line, mana cost, rules text, rarity, finishes, legality"), when at the head those come from `render_catalog_extension` and the `mtg/printings` partials. The doc said what the page shows without saying whose code shows it.
- Scope and Sources claimed spec 002's Story 7 whole, when only AC-7.4, AC-7.5 and AC-7.10 belong to this area; the rest are refresh rules the catalog operations doc already holds.

Smaller ones followed the same shapes: a step list cited to an AC that said less ("names are normalised identically"), "Show all N printings" written as always shown, and a fallback in an algorithm described more loosely than its code.

## What to do next time

- Write a statement about another file's state (the index, a neighbouring area doc) only in the commit that makes it true, or word it as what this change does.
- For a page or flow that crosses the extension boundary, say which side shows each part ("the extension's partials show…"), as the catalog operations doc keeps MTG rules in `MTG::` statements.
- When a spec is split across areas, name the criteria that belong here, not the story.
- Cite the source that says the thing: an ADR's decision, not the AC that only gestures at it; mark exact lists that come from code as the code's.
- Check each constants-table row against its definition and each conditional ("when", "only if") against the view or model before the review, since those were where the code differed from the prose.

## Signals to watch for

- "now", "already" or "the index lists" in an area doc.
- A section for a page that names collectible attributes under a `Catalog::` heading.
- A Sources line that cites a whole story or spec for an area that shares it.
