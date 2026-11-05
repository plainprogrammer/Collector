# Spec 036: Verification

**Spec:** [spec.md](spec.md) (1.0.0) | **Plan:** plan (retired in `3ebd563429e487d6f03f5bf33c2490664a7d353b`; read it with `git show 3ebd563429e487d6f03f5bf33c2490664a7d353b^:docs/specs/036-advisory-response/plan.md`)

## Before the merge

| Criterion | Evidence | Result |
|---|---|---|
| AC-1.1, AC-1.2 | `spec/advisory_response_spec.rb`, the `.github/dependabot.yml` examples; mutation rows 9 and 10 fail them | `bin/rspec spec/advisory_response_spec.rb`: `8 examples, 0 failures` before and after the mutations; row 9 (drop the security group): `8 examples, 1 failure`, `spec/advisory_response_spec.rb:13` "groups the Ruby gems' security updates into one pull request (AC-1.1, FR-1)"; row 10 (weekly to daily): `8 examples, 1 failure`, `:18` "leaves the schedule, the limit and the github-actions entry as they were (AC-1.2, FR-1)" |
| AC-2.1 to AC-2.5, AC-2.9, AC-2.11 | the `.github/workflows/advisory-audit.yml` examples; mutation rows 1 to 8 fail them | `8 examples, 0 failures` before and after; each row gave `8 examples, 1 failure`: row 1 (`push:` trigger) and row 2 (cron minute 0) failed `:37` "runs once a day and by hand, never on pushes or pull requests (AC-2.1, FR-2)"; row 3 (`continue-on-error`) failed `:47` "runs both audits as separate steps that cannot hide a failure (AC-2.2, FR-2)"; row 4 (no `!cancelled()`) failed `:57` "runs the second audit after the first fails, and neither after a failed setup (AC-2.3, AC-2.9, FR-2)"; row 5 (`contents: write`) and row 6 (`@v7`) failed `:67` "asks for read-only access and uses only actions pinned as ci.yml pins them (AC-2.4, FR-2, NFR Security)"; row 7 (timeout 30) failed `:74` "stops a hung run within 10 minutes (AC-2.5, FR-2)"; row 8 (no `--update`, a step naming the database) failed `:78` "keeps no copy of the Ruby advisory database between runs (AC-2.11, FR-2)"; `git status --short` empty after each restore |
| AC-3.1 to AC-3.4 | read against `docs/architecture/release-and-deploy.md` and `README.md:137` | AC-3.1 met: Scope names "the daily audit workflow `.github/workflows/advisory-audit.yml` (spec 036)" (line 10); version updates "cover the dependencies a manifest names, so a gem that only another gem needs is never offered one" (line 62, citing spec 036 and Dependabot's `allow` and `cooldown` documentation); "The Ruby gems' security updates are one group" (line 63, citing spec 036 FR-1 and Dependabot's `groups` documentation); "A daily workflow audits `main`" running both audits (line 64, spec 036 FR-2); Named constants has "Advisory audit schedule" `17 5 * * *` (line 201, spec 036 FR-2); AC-3.2 met: "run `bin/bundler-audit`, update every flagged gem in one change with `bundle update --conservative <gems>`, run `bin/ci checks` and the suite, and open one pull request" (line 65); AC-3.3 met: "`config/importmap.rb` pins no versioned package, so the importmap audit checks nothing today and no response to it is defined until one does" (line 64); AC-3.4 met: README line 137 "Dependabot keeps gems and GitHub Actions up to date." is true at its level of detail (version updates cover direct gems, security updates the rest), so the README is not edited; the maintainer may prefer it to say so |
| The two audits in a bare checkout | the rehearsal of Phase 2 (a clone with no `bin/setup`, no database, no `config/master.key`, no `storage/`) | `bin/bundler-audit check --update`: `Updated ruby-advisory-db` (1329 advisories, last updated 2026-11-03), `No vulnerabilities found`, exit 0; `bin/importmap audit`: `No vulnerable packages found`, exit 0 |
| `bin/ci` | the full run on `eefdd1a` | all six checks passed (setup, released migrations unchanged, RuboCop, Brakeman, gem audit, importmap audit); `2420 examples, 0 failures, 3 pending` (the 2,412 examples of the suite on 2026-11-03 plus the 8 new ones); `Tests: RSpec passed in 5m52.84s`; `Continuous Integration passed in 6m11.28s` |

## After the merge (the maintainer's, Quickstart Validation)

| Criterion | Evidence | Result |
|---|---|---|
| AC-2.7 | the hand run on `main` | pending |
| AC-2.6 | the hand run against the throwaway branch | pending |
| AC-2.8 | the failed run in the Actions tab and the notification | pending |
| AC-2.10 | the maintainer's commit moving the cron minute | pending |
| AC-1.3 | Insights, Dependency graph, Dependabot, the `bundler` job | pending |
| AC-1.4 | the next batch of security-update pull requests | pending, observed when it happens |
| Open question (Decision 4) | the Dependabot alerts for the five gems | pending, owned by the maintainer |

## Rulings during execution

- Skipped the plan's first Phase 0 step (commit the plan): it was done in `dd52814`. Cost if wrong: none.
- The baseline was GitHub's green full run of `ac77b30` (same code as this tree; later commits were documents), not a local rerun. Cost if wrong: a red baseline found late; the full `bin/ci` above ran on the final tree.
- Implementers ran on Opus, the maintainer's standing preference. Cost: none.
- Each implementer's commit body carries the plan section's heading verbatim, so restart detection can match it.

## Implementation review

SPEC-ALIGNED

Mode B (`sdd-review`), 2026-11-03, a read-only Opus review of the branch at `869e287`. Every functional requirement (FR-1 to FR-3) and every acceptance criterion that can be checked before the merge passes: AC-1.1, AC-1.2, AC-2.1 to AC-2.5, AC-2.9, AC-2.11 are met by the examples in `spec/advisory_response_spec.rb` (each walked by hand against the real YAML), and AC-3.1 to AC-3.4 by the area doc and the README, read. No implementation exceeds the spec, falls short of it or differs from it. The reviewer's own runs: `bin/rspec spec/advisory_response_spec.rb` gave `8 examples, 0 failures` and `bin/rubocop spec/advisory_response_spec.rb` gave `1 file inspected, no offenses detected`.

Six criteria are the maintainer's after the merge, by the spec's own design (AC-1.3, AC-1.4, AC-2.6, AC-2.7, AC-2.8, AC-2.10); each has a concrete route in the plan's Quickstart Validation and a pending row above.

Optional follow-ups the review raised, neither blocking, neither done (an optional finding does not start a push):

- Tighten the examples: also reject a job-level `continue-on-error` (AC-2.2 names the steps, but a job-level key would hide a failure the same way), and compare the second audit step's `if:` exactly instead of by substring (AC-2.3).
- The README's sentence "Dependabot keeps gems and GitHub Actions up to date." could say that version updates cover direct gems only; the maintainer's choice (AC-3.4).

Could not be confirmed offline: GitHub's evaluation of the second audit step's `if:` at run time (the first run after the merge shows it), that `setup-ruby` fails its own step when `bundle install` fails, GitHub's schedule delays and the 60-day disabling, who GitHub notifies of a scheduled run, whether Dependabot accepts the group, and the deferred question of why security updates opened nothing.

## Distillation

2026-11-03, `distill-feature`, before the merge.

- **Area doc:** `docs/architecture/release-and-deploy.md` carries the feature's rules, each with its source, written with the feature itself (plan Phase 3): the Scope mention, the Dependabot bullet split into four, the sentence on where the configuration files are checked, the two Named constants rows, the Sources entries for spec 036 and #164. Distilled now: its Distillation log row ([#163](https://github.com/plainprogrammer/Collector/pull/163)).
- **Index:** spec 036's row reads Frozen, by release and deploy, Plan "retirement owed"; no supersessions in either direction (the spec supersedes nothing).
- **Spec:** the frozen line is its header's last line (a commit of its own, spec 027 D4).
- **CLAUDE.md:** no statement in it restates a rule this feature changed, so it is unchanged (its "Release and deploy" bullet lists spec numbers as pointers; adding 036 to that list is the maintainer's call).
- **ADR:** none proposed. Nothing here is a decision of architectural weight beyond the spec's own Decisions 1 to 9.
- **Left for after the merge:** the plan's retirement (a commit of its own, then the spec's and the index's retirement pointer, per `distill-feature` state 1); the Quickstart Validation results in the second table above; the roadmap line for #164 ("In progress" now; "Done" with the merge date).

Two stale statements found while checking the repository's live state, not changed here because they predate this feature and sit outside it:

- ADR 0008 says "The repository is private and will become public later". The repository is public now (`gh api repos/plainprogrammer/Collector` returns `"visibility":"public"`).
- The area doc's Open points still say provenance attestations and SBOMs "wait until the repository is public" (ADR 0008; spec 012 Non-Goals). With the repository public, that wait may be over; a decision for the maintainer.
