# Spec 029 review (sdd-review Mode A)

**Date:** 2026-10-20 · **Spec version reviewed:** 1.0.0 · **Reviewer:** the drafting session, inline (not an independent Opus pass; the project's default read-only review by a second model is still owed before approval)

## Verdict: READY TO PLAN once decisions 1–4 are ruled

Every story has Given/When/Then criteria with `AC-N.M` ids; every story maps to a functional requirement; the error scenarios, tenancy (AC-4.1–4.6), cost per account and the export/Coverage impact are stated. No `[NEEDS CLARIFICATION]` marker remains: the open items are the maintainer's decisions 1–4, each with a recommendation.

## Found and fixed

- **Critical (contradiction).** Decision 5 collapsed all whitespace to one space, yet AC-1.8 rejected a tab inside a name as a control character. Fixed: a tab or newline is whitespace and becomes a space; only non-whitespace control characters are refused; AC-1.8 tests both; the invalid example list and AC-7.2 name the tab case.
- **Important (vague).** AC-7.5 named "the derived comparison key if the table has one". Reworded to say what Coverage must do for every column, without choosing the column set.
- **Important (coverage).** Story 5 (reach the page) had no functional requirement; FR-2 now requires the linking of decision 8.
- **Minor.** A wrong cross-reference in decision 1 ("decision 8 of the format's shape") now points to decision 9. FR-2's id wording tightened.

## Checked and left

- Goals measurable; non-goals exclude #45–#51, #56, a kind, per-location counts and applying an import.
- No technology is chosen beyond routes and statuses, which specs 025 and 026 also state in their decisions.
- Feasibility: the one non-obvious dependency is the import preview's reader (decision 10), which today knows only version 1 (`ExportFormat::Rules::VERSION`, `CollectionImport`); the plan must make it version-aware and keep `v1.schema.json` readable.

## Owed

- An independent read-only review of the spec on Opus (memory: sdd-review-model-choice) before the maintainer approves.
- The maintainer's rulings on decisions 1–4; the coordinator was asked and had not answered when this was written.

---

# Re-review of version 1.1.0 (sdd-review Mode A)

**Date:** 2026-10-20 · **Spec version reviewed:** 1.1.0 (approved) · **Reviewer:** the drafting session, inline; an independent Opus read is still owed (memory: sdd-review-model-choice)

## Verdict: READY TO PLAN, once spec 028 has merged

The rulings are in: decisions 1–4 ruled, 5–9 and 12 confirmed, Open Questions empty, Status Approved. The revision reads spec 028 (approved, branch `028-apply-import`, read with `git show`, never edited) and makes this spec own the preview and the apply of version 2 locations.

## Found and fixed in this pass

- **Critical (stale scope).** The draft left applying locations to spec 028 and ordered the merges either way. Rewritten: 028 merges first, this spec depends on it (header, decision 11), and decisions 10 and 11, FR-5 and Story 9 (16 criteria) cover reading, planning, fingerprinting, confirming, applying and the round trip.
- **Important (a case the draft hadn't named).** A held location spelled differently from the file's ("box", "Box") had no outcome. Added *Renamed* (same id, file's spelling), so a restore gives the file's exact names and anything that points at the location stays pointed (decision 10, AC-8.2, AC-9.1).
- **Important (028 text that would become false).** 028 says version 1 only, "nothing to change" counts lots and the view only, the fingerprint and the checkbox cover lots only, the notice counts lots only, and its round trip compares lots. Each is listed in the Supersedes table and the index row, with AC-9.9, AC-9.10, AC-9.14 and AC-9.5/9.6/9.15 as the replacements; 028 and its README row are untouched.
- **Important (edge).** Replacing 500 locations with 500 others must not fail on the cap because additions come before removals (AC-9.12).
- **Minor.** AC-8.8 ("nothing is written") contradicted 028's stored upload; it now allows exactly that. The version 1 valid examples can't export equal to themselves any more (the export writes version 2); AC-9.15 says so.

## Checked and left

- Every story has criteria (76 in all), every story maps to a requirement, tenancy has AC-4.1 and AC-9.13, cost per account is stated (decision 7, NFR), and the export/Coverage impact is in decision 9, Story 7 and Documents that change.
- One judgement is not the maintainer's word for word: the apply's confirmation also covers removed locations (decision 11). It follows from 028 decision 6 (no undo, an explicit confirmation for anything destroyed) and decision 3 (under #45 removal forgets where copies were). It is stated, not hidden; the maintainer can strike it at plan review.
- Feasibility notes for the plan: `ExportFormat::Rules` and `CollectionImport` are version-1 constants today (`VERSION = 1`, one `SCHEMA_FILE`), and 028 builds on them; the plan starts from `main` after 028 merges and extends its plan/fingerprint/apply rather than writing a second path.

## Owed

- An independent read-only review of this spec before the plan.
- Spec 028's merge, which this spec's plan waits on.
