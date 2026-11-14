# Verification: spec 090, every user has a household

Spec v0.3.2, plan, ADR 0030. Issue #380. Branch `090-every-user-has-a-household`. Models: the spec, ADR and plan were written by the main session (Sonnet 5.5 until the plan, Opus 5.5 and Sonnet 5.5 after, as the session reminders gave them); every implementer batch was Sonnet 5.5; the spec reviews (two rounds), the plan review and the extra phase 6 review were read-only Fable 5.2; the implementation review was read-only Opus 5.5.

## Implementation review

SPEC-ALIGNED WITH FINDINGS

Reviewed 2026-11-13 (sdd-review Mode B, read-only, Opus 5.5) against spec 090 v0.3.2, plan 090 and ADR 0030, over `git diff 71212946..HEAD` at the documentation commits (code 3c01b6a3 to 40f3553d). Nothing blocking; one important finding and nine minor; all fixed or recorded below. `bin/upgrade-smoke` from the v0.3.0 tag (AC-6.6) and the one full `bin/ci` had not run at the time of the review.

### Coverage (AC to test, from the review)

| AC | Test | Note |
|----|------|------|
| 1.1 to 1.4, 1.6, 1.7 | `spec/requests/households_creation_spec.rb`; `spec/models/user_spec.rb` | the first-user race is approximated by an admin created between the GET and the POST |
| 1.5 | `household_spec.rb` `.name_for`; `user_spec.rb`; `backfill_households_spec.rb` | the same three names in the harness fixture |
| 2.1 to 2.7, 2.9 | `membership_spec.rb`, `account_spec.rb`, `household_spec.rb`, `create_households_and_memberships_spec.rb` (model and database halves) | |
| 2.8 | `expect_household_invariants!` after the four create paths, the delete and an apply | the apply was added after the review (m1) |
| 3.1 to 3.3, 3.8 | `spec/migrations/backfill_households_spec.rb` | |
| 3.4 | `create_households_and_memberships_spec.rb` (literals and the full shape of the three tables before and after) | m3 fixed |
| 3.5 | `create_households_and_memberships_spec.rb` (all thirteen referencing tables filled, down and up), `make_account_household_required_spec.rb` | I1 fixed |
| 3.6, 3.7 | `make_account_household_required_spec.rb` (ten examples: counts, sequence, PRAGMA checks, shapes, the enforcement refusal, a dangling row kept, the fault after the DROP, the orphan refusal, the stragglers step, a count of each of the thirteen tables changing) | m2 fixed |
| 4.1, 4.5 | `spec/requests/households_invisible_spec.rb` (admin, collector, signed out; queries naming the new tables counted on all) | m4 fixed |
| 4.2 | `bin/rails routes` check, recorded below | |
| 4.3 | the existing tenancy request specs, unedited | 1403 examples green on their implementer's run; the full `bin/ci` is the final proof |
| 4.4 | `households_creation_spec.rb`, `user_spec.rb` | |
| 5.1 to 5.4 | `spec/export_format_document_spec.rb`; `collection_import/household_untouched_spec.rb`; the backup guards; the format README | |
| 6.1 to 6.5 | `spec/script/upgrade/households_spec.rb`, `harness_spec.rb` ("the households"), `seeds_spec.rb` | the restore leg's household check is proved by the smoke run (m5) |
| 6.6 | `bin/upgrade-smoke`, recorded below | |

### Findings and their disposition

- **I1 (important), AC-3.5: migration (a)'s `down` was untested with rows in the eleven cascading tables and lacked (c)'s guards.** Fixed in `7187f2f1`: `fill_every_referencing_table` is a spec support module used by both migration specs; (a)'s `down` has `require_enforcement_off` and the before and after state check; two examples (rows in all thirteen referencing tables going down through all three migrations and back; an outer-transaction refusal) were added. The refusal example failed first for the right reason (the cascades deleted rows and the columns were dropped); the rows example is a characterisation of the working path and passed first.
- **m1** invariants after an apply: fixed (`051d55ec`). **m2** "run again changes nothing" could not fail: fixed to capture the counts and sequence and run the migration instance (`7187f2f1`). **m3** AC-3.4 literals only: the full shape before and after added (`7187f2f1`, `30c19498` for the column order a schema-loaded table has). **m4** queries counted on the collector's and signed-out requests: fixed (`051d55ec`).
- **m5** the harness spec has no restore-leg household example: accepted; the smoke run below is the evidence that the restored snapshot passes both tiers.
- **m6** an older container's delete of a user after the third migration leaves a household with no member that nothing removes: added to `docs/releasing.md`'s Upgrade note (`2c251ca4`); #381 or an operator removes it.
- **m7** comment accuracy: `Household.name_for`'s comment names the two specs, the harness fixture uses `Household.name_for`, the history phrase is gone (`26f210a7`). **m8** the format README's sentence carries its reason (`2c251ca4`). **m9** ADR 0030's wording (`2c251ca4`).
- **m10** (c)'s orphan-account refusal and the re-homing `UPDATE` before it go beyond decision 5: deliberate, sound, and inside the one transaction; recorded here. The plan's note on why they are right is in `plan.md` phase 6.

### Migration (c) review trail

Traced line by line against activerecord 8.1.4.1's `sqlite3_adapter.rb` and `database_statements.rb` by a plan review (Fable 5.2) before the batch, and again as changed by a second review (APPROVE WITH CHANGES; the dangling-row boot loop, the unproven guards and the lambda's association instance were fixed), then by this review. One bug neither trace found was found by the phase 1 implementer: a table copy builds a TEMP table with AUTOINCREMENT, so a bare `sqlite_sequence` resolves to `temp.sqlite_sequence`; every migration now reads and writes `main.sqlite_sequence` (lesson recorded in the wrap).

## Evidence

All commands from the worktree. Targeted runs until the final one; one full `bin/ci` is owed after the smoke.

| Check | Result |
|---|---|
| `bin/ci checks` on the code commit before the review fixes | green (RuboCop, YARD with no warning, the comment ratchet on 6 objects, Brakeman, bundler-audit, importmap audit) |
| `bin/ci checks` on the merge `b13fb164` (origin/main at f7df86ce, with the new licences step) | green, 30.4 s |
| Targeted specs on the merge `b13fb164`: `spec/migrations spec/script/upgrade`, the household model, request and import specs, the export guard, the backup guards | 471 examples, 0 failures (seed 15539) |
| Phase runs by the implementers | phase 1: 11 + 9 examples; phase 2: 39; phase 3: 7 (+ the 10,000-user timing example, 3.0 s and 4.1 s); phases 4 and 5: `spec/requests` 1403, `spec/script/upgrade` 171; phase 6: `spec/migrations` 80 under three seeds; review fixes: 95 |
| One-off search (decision 9 (iv)): `git grep -n -i 'household\|membership' -- app/views app/helpers app/controllers app/javascript config/locales ':!.kamal/secrets'` | nothing |
| Routes (AC-4.2, decision 9 (iii)) | `git diff main -- config/routes.rb` empty; no controller, route or view file changed in the diff; `bin/rails routes | wc -l` is 145 on the branch |
| `households_invisible_spec` and `household_untouched_spec` on their first run | passed (nothing visible was added; an apply never wrote a household), as the plan expected |

### `bin/upgrade-smoke`

Run 2026-11-13 on the merge `0a098089957c19835529fbee6ce0d28b5c58cfb1` (origin/main at b9da192e merged; the commits after it change only `verification.md`), docker through colima: the previous release v0.3.0 built from its tag (`git archive v0.3.0` into `tmp/smoke090/v030`, image `collector:v030local`, digest `sha256:61834f698f57…`), the code under test built from the worktree (`collector:smoke090`, `--build-arg` COLLECTOR_VERSION, REVISION and SOURCE_URL), `TMPDIR` under the worktree, `/opt/homebrew/bin` appended to the PATH:

```
TMPDIR="$PWD/tmp/smoke090/run" bin/upgrade-smoke collector:v030local collector:smoke090 --previous-version 0.3.0
```

It passed, as expected. The output that reads against the expectation:

- After the upgraded snapshot's comparison: all 28 old tables `same` (accounts 2, users 2, lots 2003, locations 6, decks 1, deck_proxies 1, bulk_selections 1, bulk_selection_marks 3, bulk_removals 1, import_uploads 1, number_entries 1, scanner_sittings 1 and the rest, each with its digest), then **`households: ok (backfilled)`**, then the prices line.
- After the backup leg's comparison: `sessions`, `bulk_removals`, `bulk_selections` and `bulk_selection_marks` `differs` and listed as `expected: … rows_removed (backup:restore ends every session …)` (spec 030, not this feature), every other table `same`, then **`households: ok (backfilled)`** again.
- The seed of the next release printed nothing for the households (its check raises only on a problem).
- The last line: `OK: v0.3.0 (collector@sha256:61834f698f57…) upgraded to 0a098089957c; 28 tables compared, behaviour verified, 83 s`.

So the two tiers held on the real database the v0.3.0 seed leaves (two users, two accounts, 2,003 lots, a row in each of the thirteen tables that reference `accounts`): every user has one manager membership in a household named for them, every account is in its user's household and personal, nothing old changed (`expected_changes.yml` is empty), and the third migration's table copy lost no row. This closes AC-6.1, AC-6.2 (restore leg), AC-6.6 and the m5 finding.

**Second run, on the merged commit.** After spec 089's merge (two prices-database migrations, `db/prices_structure.sql`) the same run on `60951eec3404c0bbefee752ecaced6cd68c579ec` (the commit that is pushed), with the current image rebuilt from it: all 28 old tables `same` after the upgrade; **`households: ok (backfilled)`** after the upgraded and again after the restored snapshot; the prices line reads `schema 20261113190002`; the backup leg's `expected:` rows are the same four (`sessions` and the three bulk tables); `OK: v0.3.0 (collector@sha256:61834f698f57…) upgraded to 60951eec3404; 28 tables compared, behaviour verified, 62 s`. On the same tree `bin/rails db:prepare` and 325 targeted examples passed (`spec/script/upgrade`, the backup guards and upgrade, `spec/models/prices_record_spec.rb`, `spec/prices_core_spec.rb`, `spec/migrations`, the household model and request specs, the export guard): 0 failures, seed 6927.

### The full `bin/ci`

To be recorded with the CI run of the push.

## Distillation

Written during phase 7 and checked by the implementation review against the code: `tenancy-and-accounts.md` (the household, membership, personal and shared account, the invariants, the instance-level tables, the delete order, the accepted limits), `release-and-deploy.md` (the upgrade proof's two-tier households check), `data-portability.md` (the household's tables and columns left out, `households` outside the guard), `.claude/rules/multi-tenancy.md`, `docs/releasing.md`'s Upgrade note and `CLAUDE.md`. At the wrap (maintainer-approved digest): one Distillation log row in each of the three area docs with the placeholder "spec 090's pull request" (replaced by the pull request's link once it is open), the index row Frozen, by those three docs, Plan "retirement owed", and the spec's frozen line (spec 027 D4). No new ADR: ADR 0030 stays Proposed in the pull request; the maintainer accepts it, recorded in the plan-retirement pull request as for ADR 0029. Lessons: two (`docs/lessons/2026-11-13-a-table-copy-of-a-referenced-table.md`, `...-association-name-creates-the-association.md`); one feedback memory (`rereview-changed-data-loss-steps`).
