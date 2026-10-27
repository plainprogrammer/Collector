---
date: 2026-10-27
spec: "027"
tags: [documentation, area-docs, scope, distillation]
---

# Lesson: Take an area doc's scope from the specs index, not from its issue

## Context

#105 asked for the collection and lots area doc (spec 027 slice C) to cover specs 004 (the collection part), 006 and 021. A later comment widened it to 032, 033 and 034, which shipped while the doc was unwritten.

## What happened

- **The issue's scope was still short two specs.** The Areas column of `docs/specs/README.md` already assigned the collection parts of 026 (number entry) and 029 (locations) to this area, and their export parts were frozen by `data-portability.md`. Covering 034 (built on 026) and 032 (built on 029) while leaving those two unfrozen would have frozen the later specs ahead of the ones they extend. The brainstorm caught it and the maintainer agreed.
- **The code differed from the specs in three places the read-only review found:**
  - `CollectionTable::Sort.parse` sorts a known column ascending when the direction is unknown, where spec 006 AC-3.7 says the default order.
  - The card page always shows its Location column, while the grid and table hide theirs without locations.
  - Places add two statements per page, not the NFR's one, which spec 033's `verification.md` already recorded.

  These went into the doc as the current truth, with the spec's text noted, and the open ones were listed for the maintainer.
- **An open deviation decided a "frozen in part".** Spec 033 decision 5 (one line with an ellipsis) holds for tiles and not for rows (#142, kept by the maintainer). Freezing 033 whole would have made the area doc the supersession, which the rules give to a new spec. Freezing it in part leaves decision 5 for rows to #142's spec.

## What to do next time

- Before writing a slice C doc, list every row of the specs index whose Areas cell names the area, and every part a frozen line already gives to another doc. That list, not the issue, is the scope. Raise the difference with the maintainer.
- Read each spec's `verification.md` for accepted deviations and open items before deciding whole or in part. A deviation with an open issue means "frozen in part".
- Write the doc from the code as well as the specs (see `2026-10-15-plans-hold-rules-specs-dont`), and give a read-only reviewer the same instruction: where code and spec differ, the doc says what the code does and names the difference.

## Signals to watch for

- A spec that extends another one in scope, while the one it extends isn't.
- A verification file with "deviation", "open for the maintainer" or "accepted".
- An NFR's statement count that `verification.md` corrects.
