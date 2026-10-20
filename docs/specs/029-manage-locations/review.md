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

---

## Independent review (Opus, 2026-10-20)

**Source:** the independent Opus review of spec 029 v1.1.0 (`52d0023`): verdict NEEDS REVISION, 0 critical, 5 major, 13 minor, plus the note that the plan can't start before spec 028 merges. **Resolved in spec version 1.2.0.** The maintainer's rulings of the same day (relayed by the coordinator) decided M1, M2, M3, M5, Q1–Q7, m8 and m13; the details that were not ruled are marked *proposed (coordinator agreed; awaiting maintainer confirmation)* as P1–P8 and listed in Open Questions. Nothing was rejected outright; two suggestions were adapted, as noted.

| Id | Resolution |
|---|---|
| **M1** labels claim rulings the record doesn't show | Status line, preamble, changelog and headings rewritten. *Ruled* only: 1, 2, 3, 4, 7, 10 and 11 (their additions confirmed), 13, and the ADR; decisions 5 and 9 ruled for the comparison and character rules (M2, M3); 6 and 8 stand; 12 "follows from the tenancy rules". The remaining details are P1–P8. The changelog lists what was ruled and when. |
| **M2** "same collection" contradicts itself | Decision 9: location names are compared exactly, character for character; the comparison key serves `duplicate_location` and matching in an apply only. AC-6.8 and the comparison examples (case differs, reordered is the same, a different set differs). |
| **M3** names under-defined; model and schema may disagree | Decision 5 rewritten to the ruling (NFC; Unicode White_Space trimmed and collapsed; Cc and Cf refused; 1–60 code points; full case folding). Decision 9 states the same sets in the format and requires the ECMA pattern/`maxLength` to agree with the model. AC-7.8 is the parity spec over every scalar value; AC-7.2 and the examples list NBSP, U+3000, U+0085, U+2028, U+200B, NFD, 60/61 code points, the folding pair; AC-1.5, 1.7, 1.8, 1.9, 1.11 extended. NFR Reliability says SQLite's `LOWER()`/`NOCASE` fold ASCII only, so uniqueness rests on a key computed in Ruby with a unique index. *Adapted:* the review proposed lower-casing; the ruling says case folding, which is used. NFC in a **file** is P1. |
| **M4** AC-9.9's fingerprint property is over-broad | Reworded: equal for identical previews, different for an added, removed or respelled held location (case-only change included) or a changed stored file, equal for a location deleted and re-added with the same spelling (and the apply goes ahead). Decision 11's fingerprint text matches. |
| **M5** a location-only apply clears unrelated working state | Ruled: clearing happens only when the apply writes lots. Decision 11 (narrowing 028 decision 7's "whatever the plan"), AC-9.4, new AC-9.17 (location-only and view-only clear nothing; a lot-writing apply clears), Supersedes row for 028, FR-5. |
| **m1** signed-out writes and CSRF | AC-4.4 split: GET redirects; a write with an ended session redirects; a write with no cookie fails CSRF first (422); forgery protection enabled in that spec. Error row (P7). |
| **m2** `duplicate_location` pointer | `/locations/<i>` (decision 9, AC-7.3). |
| **m3** refusal wording | Exact copy for duplicate, non-NFC, missing and the generic (decision 10, AC-8.5; P6). |
| **m4** sort order | Comparison key then name, code-point order, no locale collation; AC-1.4 and AC-6.3 add "Éclair"/"eclair" (decision 2; P2). |
| **m5** cost understated | Worst case about 1 KB a row, under 0.5 MB per account, under 130 KB per export (decision 7, NFR; P8). |
| **m6** "fixed number of statements" | "A bounded number of statements" (028 FR-4's wording). |
| **m7** Supersedes gaps | Rows for spec 025 AC-3.2, spec 017 AC-3.3 with its version-history sentence, and the format document's "Locations will add…" sentence; 028 decision 7/AC-1.8; the index row has the same. |
| **m8** changing an ADR through a table | A **new** ADR (ruled) records "locations are v2, lots in locations v3" and supersedes the relevant part of ADR 0020; expected in decision 1 and listed under Documents that change with the pointer in ADR 0020's Status and the index line. The ADR 0021 row is dropped (its consequences already cover a new schema version); decision 9 still cites it. |
| **m9** navigation details | AC-5.1 (640px fit), AC-5.3 (no tab current on the locations pages), AC-5.5 (360, 640 and desktop; edit and removal pages too) (decision 8; P5). |
| **m10** notice wording | Names quoted and normalised in all four messages (decision 6, AC-1.2, 1.9, 2.2, 3.2; P4). |
| **m11** missing error scenarios | Rows and ACs for PATCH of a removed location (AC-2.10), a missing parameter (AC-1.14), two tabs renaming (AC-2.9), a race at 499 (AC-1.13); the resubmitted DELETE stays a bare 404 (AC-3.6) (P7). |
| **m12** length of the Locations list | The lots' limit applies: first 100, then "and N more" (decision 10, AC-8.9; P3). |
| **m13** size of the PR | Ruled: one PR (new decision 13, the alternative named). |
| **Q1–Q7** | Q1 and Q2 confirmed (decisions 2, 7, 10, 11); Q3 = M5; Q4 = M2; Q5 = M3; Q6 = m13; Q7 = m8. |
| Review note: plan waits for 028 | Already in the header and decision 11; the header now also says 028 is revised in parallel and that the plan re-checks every citation of it. |

## Mode A, third pass (inline, after the revision)

READY TO PLAN once spec 028 has merged. Checked: no criterion depends on an unranked decision; AC-7.8 makes the model/schema agreement testable; every proposed detail (P1–P8) has a default and is listed in Open Questions; no `[NEEDS CLARIFICATION]` remains. Citations of spec 028 use its numbering at `87308d5`.
