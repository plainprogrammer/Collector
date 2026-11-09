---
name: catalog-core-slice-handoff
description: Spec 027 slice C for catalog core (#104, PR #207) moved some of specs 004, 007 and 009 into catalog-core.md; the scanner and tenancy slices extend the frozen lines, not add new ones
metadata:
  type: project
---

`docs/architecture/catalog-core.md` (PR #207, 2026-11-06) covers spec 002 FR-1, FR-2, FR-7–FR-10, spec 004's search, card-page catalog content and collecting vocabulary, spec 007's name index (FR-4's name index and matching, FR-5, AC-3.4, AC-3.5, AC-3.9), spec 009 AC-6.1, and specs 016, 018, 019, 023. Its plans for 002, 018, 019 and 023 are retired.

**Why it matters to the other slices:** specs 004, 007 and 009 already carry a `**Frozen:**` line naming catalog core (004 also names collection and lots). The scanner slice (#107) and the tenancy slice (#106) must extend those lines and the index rows' Status and Areas cells when they cover the rest of 007, 009 and 004, not add a second line (spec 027 D4: one line per spec). The scanner area also owns what `MTG::Reading` does with `Catalog::NameIndex` candidates; `Catalog::Entry.printed_as` is core's scope with the scanner's use.

**How to apply:** read the three frozen lines before writing yours. [#204](https://github.com/plainprogrammer/Collector/issues/204)'s three behaviours with no spec source (key lookups ignore the type, page numbers, sort order) were ruled on 2026-11-09 and are in catalog-core.md's rules, Decisions and Accepted limits; read them there.
