# Verification: spec 091, CI fails on a dependency whose licence isn't allowed (#402)

**Status:** in progress. Built and checked locally on 2026-11-13; the implementation review (`sdd-review` Mode B, Opus 5.5), the wrap, the one full `bin/ci` and the push are not done yet.

## Evidence so far (fresh runs, 2026-11-13)

- **Specs:** `bin/rspec spec/lib/collector/third_party_licences spec/tasks/licences_rake_spec.rb spec/config/ci_definition_spec.rb spec/licences_core_spec.rb spec/third_party_licences_manifest_spec.rb spec/lib/collector/third_party_licences_spec.rb`: 102 examples, 0 failures (seed 32188).
- **`bin/ci checks`:** green. The step's line: `Licences: 151 components judged; each is under an allowed licence or a named exception.` (AC-4.2); the step took 1.28 s of 25.64 s.
- **Timing, `bin/ci checks`, same command `time bin/ci checks`:** before 35.5 s total (main at `71212946`); after 30.98 s (cold), 24.70 s and 25.80 s. The totals are below the baseline because other workers share the machine, so the step's own cost, 1.2 to 1.3 s, is the figure that counts.
- **Failure on the real task (AC-4.3):** a policy copy without `Apache-2.0` and without the `brakeman` exception made `bin/rails "licences:check[<policy>]"` print "Licences: 8 problems:" with one line per dependency, e.g. `gem addressable 2.9.2 is under Apache-2.0, none of which is on the allowed list in <policy path>: allow the licence there, or list the gem under exceptions with its reason (ADR 0031)`, and exit 1 (including the OCR engine's JavaScript-side entries, `tesseract.js` and `tesseract.js-core`).
- **`vcr`:** the real run prints no problem with the exception; with the entry commented out it also prints none (it passes on its `MIT`); with `all_required` removed it reports the exception stale ("allowed without it"). This is why the form exists (spec decision 3).

## Acceptance criteria

| AC | Evidence |
|---|---|
| AC-1.1 to AC-1.6, AC-2.1 to AC-2.3 | `policy_spec.rb` (injected sections) |
| AC-3.1, AC-3.2, AC-3.5, AC-3.6 | `policy_spec.rb`, exceptions and `all_required` groups |
| AC-3.3 | `policy_spec.rb` (shape, unreadable file), `licences_rake_spec.rb` (unreadable policy) |
| AC-3.4 | read: `config/licence_policy.yml` allows the seven ids and excepts `bundler-audit`, `brakeman`, `vcr` (`all_required`) with reasons |
| AC-4.1 | `spec/config/ci_definition_spec.rb` |
| AC-4.2, AC-2.4 | the `bin/ci checks` run above |
| AC-4.3 | `licences_rake_spec.rb` and the run above |
| AC-4.4 | `check_spec.rb` |
| AC-4.5 | no file under `.github/workflows/` in the diff |
| AC-5.1 | `spec/licences_core_spec.rb` (shown failing on a planted word, then restored) |
| AC-5.2, AC-5.3 | read: `catalog-core.md`, `release-and-deploy.md`, `CLAUDE.md`, `.claude/rules/testing.md`, `conventions.md` |
| AC-5.4 | roadmap and specs index rows (`distill-feature` finishes them) |

## Models

Spec, ADR 0031 and plan: my main session (Sonnet 5.5). Spec, ADR and plan reviews: Fable 5.2, read-only (spec 2 rounds, ADR 1, plan 1). Implementers: Sonnet 5.5 (three batches: T1.1 to T1.3, T2.1 to T2.4, T3.1 with T4.1). Docs (T4.2): my main session.

## Owed

- The implementation review below, then `session-wrap`, `distill-feature`, the full `bin/ci` under a slot and the push.

## Implementation review

SPEC-ALIGNED WITH FINDINGS

Opus 5.5, `sdd-superpowers:sdd-review` Mode B, read-only, 2026-11-13, over `git diff 71212946..HEAD`. No blocking or major finding. It ran the five feature spec files (40 examples, 0 failures) and `bin/rails licences:check` on the real tree (151 components, exit 0, as above), and found no change under `.github/`, no Dockerfile, deploy or settings file, and no collectible named in the new files. Every AC and FR is covered (the table above), and the docs state what the code does.

Findings, all minor:

1. `all_required` was never type-checked (a string `"true"` read as false). Fixed: a shape problem now names the entry.
2. An empty policy file loaded as `{}` and produced about 151 "not allowed" lines instead of one shape problem. Fixed: a mapping without `allowed` is one shape problem; `allowed: []` stays valid.
3. Stale-exception sentences follow the component sentences, not interleaved. Fixed in the `#problems` comment and the area doc.
4. The `Policy` class comment omitted `all_required`. Fixed.
5. The `DECISION` constant's comment said what, not why. Fixed.
6. The specs index row said Draft while the spec is Approved. Fixed.
7. README.md's numbered `bin/ci` step list was already stale before this branch (no migration guard, YARD or ratchet) and now also lacks the licence check. Not changed: the spec doesn't require it; owed to the maintainer as a README tidy.
