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
