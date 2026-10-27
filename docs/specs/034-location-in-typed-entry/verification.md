# Verification: Choose a Location During Typed Entry (spec 034)

**Spec:** [spec.md](spec.md) v1.0.0 · **Plan:** [plan.md](plan.md) · **Branch:** `034-location-in-typed-entry` · **Issue:** [#51](https://github.com/plainprogrammer/Collector/issues/51)

## Rulings

By the maintainer, 2026-10-26, with the spec's approval: decision 1 (a Location field on each line, kept in the URL), decision 2 (nothing new for an account without locations) and decision 3 (the place is read from the lot; no column), each as recommended.

## Evidence

| Criterion | Proved by |
|---|---|
| AC-1.1, 1.4, 1.5, AC-2.1, 2.2 | `spec/requests/number_entries_spec.rb`, "choosing a location (spec 034)" |
| AC-1.2, 1.3, 1.6 | the same group, and `spec/models/number_entry_spec.rb`, ".add! into a location" |
| AC-3.1, 3.3 | the same group (Undo from the lot; a gone lot names no place in the helper) |
| AC-3.2 | not exercised for a moved lot in this spec; the line reads the lot's place through the preload, and spec 032 AC-7.6 covers the move |
| AC-4.1, 4.2, 4.3, 4.4 | request group and `spec/models/number_entry/line_form_spec.rb`, "#location" |
| AC-5.1 | the Location select is a native select with the Finish select's Enter action; not driven in a browser in this spec |
| FR-4 | `spec/number_entry_core_spec.rb` (no file added or renamed; no type named) |

`bin/ci` (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec) passed on the build before the commit, and the push hook's `bin/ci` passed on the pushed commit.

## Gaps

- AC-3.2 (a line whose lot was moved or merged) and AC-5.1 (keyboard use of the select in a browser) have no example of their own.
- The design system's markup was reused from the Finish field; the page was not looked at in a browser, so no screenshot is recorded.

## Implementation review

SELF-REVIEWED, SPEC-ALIGNED, with the two gaps above. This is the author's own reading of the diff against the spec; the independent `sdd-review` step was not available in this session, so the maintainer's review is still owed.

## Distillation

No area doc covers collection and lots yet (`docs/architecture/README.md`: not written yet), and the number-entry list stays left out of the export, so `data-portability.md` is unchanged. Nothing was written to an area doc; the spec stays unfrozen and its plan is owed retirement after the merge.
