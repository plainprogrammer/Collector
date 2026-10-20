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
