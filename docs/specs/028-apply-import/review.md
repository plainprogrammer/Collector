# Spec 028 review (sdd-review Mode A, 2026-10-20)

**Verdict: READY TO PLAN.** The maintainer ruled every open question on 2026-10-20 (spec v1.2.0). Reviewed by the drafting session against the Mode A checklist: completeness, ambiguity scan, feasibility.

## Found and fixed (spec v1.1.1)

| Severity | Finding | Fix |
|---|---|---|
| Critical | The fingerprint lived only with the stored upload. An apply from an older tab, after another preview replaced the stored file, would have applied a file the collector never saw on that page | The apply form carries the fingerprint; applying needs form = stored = recomputed (decision 2, AC-3.2) |
| Important | AC-3.3 mixed three cases in one run-on sentence; AC-5.6 said "previews" though a preview replaces the upload anyway | Rewritten; AC-5.6 is about applying |
| Important | "An error page" for a failed write had no status | 500 with the page (AC-2.1) |
| Important | A `[NEEDS CLARIFICATION]` left in Error Scenarios, duplicating open question 5 | Replaced by the recommended behaviour and a pointer to the question |
| Minor | FR-5 / AC-4.2 said no parameter names anything, but the fingerprint is one | Stated as the one exception |
| Minor | The Terms said the fingerprint is not shown to the browser | Aligned with decision 2 |

## Checked and fine

- Every story has numbered Given/When/Then criteria; each can be a request, model or system spec, or is marked as measured by hand (AC-1.10, AC-6.5, AC-7.3, AC-7.4).
- Every story maps to an FR: S1 FR-1 to FR-4, FR-9; S2 FR-2, FR-3; S3 FR-2; S4 FR-5; S5 FR-6, FR-7, FR-10; S6 FR-1, FR-3; S7 none (pages).
- Ambiguity scan: no "appropriate", "as needed" or "etc."; the expiry (1 hour), sweep (15 minutes), size (32 MB) and bars (30 s, 10 s, 500 MB) are concrete.
- Hosted-door rules 1 to 4 stated; the export's Coverage line is named; the supersession of spec 025's "never stored" is recorded here and in the index, and spec 025 is untouched.
- Spec 025's refusals, problem rows and outcomes are reused, not restated.

## Left for the maintainer

Nothing: all ruled in spec v1.2.0. The upload-retention ADR is expected with the plan.

## Independent review (Opus, 2026-10-20)

Source: the independent read-only review (6 major, 10 minor), verdict NEEDS REVISION on v1.2.0. Spec revised to v1.3.0. "Ruled" means the maintainer ruled it on 2026-10-20; "proposed" items P1 to P4 were agreed by the coordinator and await the maintainer's confirmation at plan review.

| Id | Resolution |
|---|---|
| M1 busy timeout | **Ruled.** Write-transaction bar is a hard under 4 s for 50,000 rows, below the 5 s busy timeout, so concurrent writers wait and never fail (decision 3, AC-1.10, error rows). FR-2 reworded: writes plus one read of the lots and the fingerprint comparison, counted in the bar. A missed bar goes to the maintainer for a fallback |
| M2 round-trip equality | Fixed. AC-6.2 to AC-6.4 use the format's "same collection" rule (generator, `exported_at` and lot order never count; the profile's name and email apart, since apply never changes them); AC-6.4 sets the instance currency to the example's and handles `empty.json` as "nothing to change, no apply offered" |
| M3 idempotency vs decision 7 | **Ruled.** Decision 12: an apply whose plan has nothing to change is refused (422), writes and clears nothing; decision 7 clears only when the apply writes; AC-2.2 rewritten against the refusal. The check precedes the fingerprint check (decision 13), so a plan made empty by an earlier apply gets "nothing to change", not a stale 409 |
| M4 Active Storage defaults | **Ruled.** Routes stay drawn but gated behind sign-in and ownership (decision 8, AC-1.12); blobs created analyzed, so no AnalyzeJob; every removal purges synchronously outside the transaction, sweep as backstop (decision 9, AC-1.9, AC-1.11); install migration listed (decision 8, Documents that change); the retention ADR records the gated routes for ADR 0013's future uploads |
| M5 sweep orphan | Fixed. An orphan is a marked blob with no attachment older than 10 minutes (the 10 is P4, proposed); the sweep only calls `purge`, never walks `storage/`; AC-5.4 builds the orphan, a fresh unattached blob that must survive, and an unmarked blob that must survive |
| M6 missing stored file | Fixed. New error row and AC-2.5 (422 "Preview the file again."); AC-2.3 says the loser gets 422 (or 409), never 500; presence, expiry and fingerprint are re-checked once inside the transaction (FR-2, AC-5.6) |
| m1 check order | Decision 13, AC-3.6 (**proposed**, P1) |
| m2 "Removed when" lacks "refused" | Added (decision 9) |
| m3 fingerprint truncated to seconds | `updated_at` at full precision in the fingerprint (decision 2; **proposed**, P2) |
| m4 AC-5.5 environments | Production and development named; the sweep runs in development too (**ruled**, Q4) |
| m5 AC-1.6 sub-cases unreachable alone | The file also changes a lot |
| m6 AC-2.1 "third write" | Rewritten: after the first write statement, injected through a stubbed collaborator of the apply step, not `Lot` or ActiveRecord |
| m7 AC-1.10 gaps | Added the removal-heavy case (empty file against 50,000 lots) and the preview re-measure with the store (**proposed**, P3) |
| m8 AC-2.5 duplicates AC-1.9 | The old AC-2.5 is folded into AC-1.9 (resubmission) and AC-2.5 now covers the vanishing-upload race |
| m9 decision 7 rationale | Corrected: `BulkRemoval#undo!` adds its lots back through `Lot.add!`, so the harm is lots the file removed returning or copies summed into lots the file set. The ruling stands |
| m10 scope and bookkeeping | The install migration, the storage and the sweep are in the same PR as the apply (Documents that change); the "Superseded by" cell of spec 025 is a task of the plan's documentation step, so both directions are recorded on shipping |
| Rulings check: decision 11, FR-3's bulk-write exception, the catalog-refresh accepted limit | **Ruled** (confirmed 2026-10-20) and labelled so |
| Rulings check: decision 3's figure | Replaced by the hard 4 s bar (M1) |

**Rejected:** none. One reading adjusted: the reviewer's M3 fix said to "refuse a plan with nothing to change" after the fingerprint check; the spec puts it before (decision 13) because a plan emptied by an earlier apply would otherwise get a stale 409 instead of the truthful "nothing to change".

**Update (2026-10-20, version 1.3.1):** the maintainer confirmed the four proposed items (P1 to P4); they are marked ruled in the spec and Open Questions is empty.
