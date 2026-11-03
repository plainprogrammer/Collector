# Spec 040 plan review

## Round 1 (independent, Opus, read-only, 2026-11-03)

Verdict: **NEEDS REVISION** (no blockers), fixed in the plan's revision of the same day.

| # | Finding | Resolution |
|---|---|---|
| M1 | Phase 3 could not end green: its locals broke the strict-locals templates until Phase 4 | The plumbing (locals, signatures, picker partial) moved into Phase 3; Phase 4 keeps header, copy, entry line, styling |
| M2 | The render-time delete still rendered the destroyed `has_one` target | `ScannersController#show` passes `nil` explicitly; the test asserts the hidden or control-only markup |
| M3 | No way to tell "no entries ever" from "all undone" without a view query | `added_any` flag in `sitting_locals`; three copies named |
| M4 | P1's predicate is narrower than AC-3.2's "holds no cards" | Recorded as open item P1 for the maintainer's ruling; recommended: the narrower rule, with spec 0.2.2 rewording AC-3.2 |
| m1–m12 | Done redirects (not renders); picker local names; `selected` on "No location"; `c-select` vs `Form.md`; Scanner.md update; hash syntax; `12abc` guard; the AC-3.2 import case through a real apply (`apply_spec.rb:314`) and AC-5.3 (`:152`); migration spec details and schema `version:` line; 360px and keyboard steps; the deleted-sitting message; optional upgrade-seed place | Applied in the plan; the upgrade-seed place is an open ruling at approval |
