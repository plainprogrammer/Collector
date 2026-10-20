---
name: spec-017-followups
description: Spec 017 (export format) — PR #68 draft and what is owed; what export (#38), import (#39, #40) and locations (#45) inherit from it
metadata:
  type: project
---

Spec 017 defined the export format (`docs/export-format/`, ADR 0020). PR #68 was opened as a draft on 2026-10-11 and closes #37.

**Owed before it is marked ready:**
- the maintainer's read of `docs/export-format/README.md` as GitHub renders it, with its relative links
- the GitHub checks (the `ci` job and both image builds)
- at merge, a re-check that ADR 0020 and the roadmap's decision-log row 32 are still free against specs 018 and 019, which ran in sibling worktrees and may also touch `CLAUDE.md` and `.claude/memory/MEMORY.md`

**What the next specs inherit:**
- **Import (#39, #40)** reads `format_version` before it validates. A file of a higher version fails version 1's schema at `/format_version`, and it is "newer than this reader", not malformed. `ExportFormatRules.problems` (test support) doesn't make that distinction.
- **Import** decides where a copy of the rules lives inside the app. Today they are in `spec/support/export_format_rules.rb`, and `json_schemer` is a `:test` gem with `require: false`.
- **Import** keeps each lot's `added_at` and `changed_at` from the file, or a restored collection won't match.
- **Export (#38)** is built (spec 022, PR #97). It leaves `generator` out, because the app has no version constant ([[spec-022-followups]]).
- **Locations (#45)** raise the format to version 2 whichever way their ADR goes, and add `v2.schema.json` beside `v1.schema.json`.
- **Currency per account (#64)** adds a column to `accounts`, which fails the coverage guard until the document's Coverage tables list it. That is intended.

Related: [[adr-numbers-across-branches]], [[pr-exists-and-conflicts-check]].
