# Verification: Store Currency per Account (spec 038)

**Spec:** [spec.md](spec.md) v0.2.0 · **Plan:** plan (retired in `cb2af5fdfd1b11f871ad9d7c8962540871eaa4e2`; read it with `git show cb2af5fdfd1b11f871ad9d7c8962540871eaa4e2^:docs/specs/038-currency-per-account/plan.md`) · **Branch:** `038-currency-per-account` · **Issue:** [#64](https://github.com/plainprogrammer/Collector/issues/64) · **Pull request:** [#173](https://github.com/plainprogrammer/Collector/pull/173)

## Rulings

By the maintainer, 2026-11-03, with the spec's approval: decisions 2 (`COLLECTOR_CURRENCY` is the default for new accounts), 4 (a Currency page linked from More), 6 (no export version change) and 7 (an import's currency becomes the account's), each as recommended.

Made during execution and recorded in the commit bodies:

- The format document's Coverage rows landed with the column (phase 1's first commit), not in the documents commit, so that every commit leaves the suite green.
- Phase 2b's refusal, plan and apply landed as one commit: removing `other_currency` makes a EUR file previewable, which needs the plan's change to be right.
- The Currency page's two sentences are the field's `c-field__hint`, tied to the select with `aria-describedby` (as the import page's hint is). So there is no new CSS and no new pattern doc under `docs/design-system/components/`; `MorePage.md` gains the Currency row.
- `Collector::Currency.fetch!` takes `setting:` so that `Account#currency_unit` names `accounts.currency`, not the environment variable (review m2).
- On a refused code, the controller clears the record's errors after copying the messages, because Rails' `.field_with_errors` wrapper narrowed the select. This was found in the screenshots.

## Evidence

| Criterion | Proved by |
|---|---|
| AC-1.1 | `spec/requests/admin/navigation_spec.rb` (More and the account menu, member and admin), `spec/requests/locations_spec.rb` "puts a Locations row in More…", `shell_spec.rb`, `number_entries_spec.rb` (positions) |
| AC-1.2, 1.6, 1.7 | `spec/requests/currencies_spec.rb` (options and their order, the hint and the counts 1 and 3, 422 for `XYZ`, `eur`, empty and `"EUR "`, 400 without `account`, no `.field_with_errors`) |
| AC-1.3 | `currencies_spec.rb` "saves a code…"; `spec/requests/lots_spec.rb` "asks for the price in the account's currency" (label `(EUR)`, prefix `€`, add and edit) |
| AC-1.4 | `spec/helpers/lots_helper_spec.rb`; request examples in `catalog/entries_show_spec.rb`, `collection_table_spec.rb` (the table, and the grid shows no symbol), `lot_moves_spec.rb`, `locations_spec.rb` (removal refusal) |
| AC-1.5 | `currencies_spec.rb` "saves a code…" (`price_paid_cents` and `lot_key` unchanged) |
| AC-1.8 | `currencies_spec.rb` "when signed out" |
| AC-2.1, 2.2 | `currencies_spec.rb` "changes only the signed-in account's currency…" (`id` and `account_id` ignored; the other collector's table still writes `$12.50`) |
| AC-2.3 | `spec/requests/admin/users_spec.rb` "shows and takes no currency…" |
| AC-3.1 | `spec/models/user_spec.rb` (factory, `User::Command`, `Registration#save`), `admin/users_spec.rb` (admin-created user) |
| AC-3.2, 3.5 | `spec/lib/collector/currency_spec.rb` (the boot default is USD; ` eur ` reads as `EUR`), `spec/models/account_spec.rb` |
| AC-3.3 | `account_spec.rb` "keeps its currency when the instance default changes" |
| AC-3.4 | By reading: `config/initializers/currency.rb` still calls `Collector::Currency.fetch!` on `COLLECTOR_CURRENCY` at boot, and `currency_spec.rb` "rejects an unknown code, naming it" proves the error. No example boots the app with a bad value. |
| AC-4.1–4.4 | `spec/migrations/set_account_currency_from_the_instance_spec.rb` (EUR; unset gives USD; ` eur `; `XYZ` raises naming the variable and value and changes no account; no account) |
| AC-4.3, second clause | By structure: the schema step and the data step are two migrations, and the data step raises before its `UPDATE`, so the column stays and the next `db:migrate` runs the data step again. No example covers it. |
| AC-4.5 | `spec/migrations/add_currency_to_accounts_spec.rb` (down and up through the Migrator, every row and other column kept, `disable_ddl_transaction`); the data step's `down` is in the migration spec above |
| AC-4.6 | CI's `bin/upgrade-smoke` only (spec 031): `script/upgrade/compare.rb` compares the columns both databases have, so the new column is no difference, and the data step changes no existing value (it sets `USD` on an instance that never set the variable). See the vacuity note below. |
| AC-4.7 | `script/upgrade/seeds/next.rb` (Grace in EUR), `spec/script/upgrade/seeds_spec.rb` "gives one account a currency other than the default" |
| AC-5.1–5.3 | `spec/models/collection_export_spec.rb` (EUR at version 3, two accounts each their own, `VERSIONS` `[1, 2, 3]`); `export_format_examples_spec.rb` and `rules_spec.rb` unchanged and green |
| AC-5.4 | `spec/export_format_document_spec.rb` (`accounts` "Exported", the `accounts.currency` column row); the prose was checked by reading |
| AC-6.1, 6.2, 6.6 | `spec/models/collection_import_spec.rb` (EUR read; own currency has no change; `XYZ` is `unsupported_currency`; `EURO` and `xyz` are `pattern`), `spec/requests/collection_import_previews_spec.rb` (Profile line, `EUR` in the file line, apply offered; refusal list) |
| AC-6.3 | `spec/models/collection_import/apply_spec.rb` "sets the account's currency…", `spec/requests/collection_imports_spec.rb` (notice, alone and after locations) |
| AC-6.4, 6.5 | `spec/models/collection_import/plan_spec.rb` "the currency", `apply_spec.rb` "applies a file whose only difference…", previews request examples for the empty examples |
| AC-6.7 | `apply_spec.rb` "is stale when the currency changed…" (plan `EUR` from `GBP`) and "has nothing to change when the account was changed to the file's currency…"; `collection_imports_spec.rb` "answers 409 when the currency changed…" (the rendered sentence); `plan_spec.rb` (the fingerprint holds both codes, and a plan without a change keeps spec 028's fingerprint) |
| AC-6.8 | `collection_import_previews_spec.rb` "writes a removed lot's price in the account's currency and a problem row's in the file's", `spec/helpers/import_previews_helper_spec.rb` |
| AC-6.9 | `apply_spec.rb` "leaves the currency as it was when the apply's transaction fails" (a `BEFORE INSERT ON lots` trigger) |
| AC-6.10, 6.11 | `spec/models/collection_import/round_trip_spec.rb`: every valid example (versions 1–3) applied to an account at the default exports the same collection with its currency, then has nothing to change |
| AC-7.1 | `spec/backup_restored_instance_spec.rb` "keeps each account's own currency…" |
| FR-4's guard | `spec/currency_reads_spec.rb` |

**AC-4.6 vacuity note:** `spec/backup_upgrade_spec.rb` rolls back `STEP=1`. That is now `SetAccountCurrencyFromTheInstance`, whose `down` is empty, so that spec no longer exercises a schema rollback of the newest release. The column's rollback is proved by `add_currency_to_accounts_spec.rb`, and the upgrade by CI's `bin/upgrade-smoke`. That spec is unchanged; the maintainer may want it to roll back `STEP=2`, or roll back to the last release's version.

**Runs:** local `bin/ci` passed on `5847f25` (2471 examples, 0 failures, 1 pending; RuboCop, Brakeman, bundler-audit, importmap audit and the migration guard green). The run after the review fixes is recorded in the pull request.

**Screenshots** (`screenshots/`): `walkthrough.gif` (More → Currency → EUR → Save, the notice, the collection table in `€`, the lot form `(EUR)`/`€`, an import preview of a USD file); `currency-desktop-light.jpg`, `currency-desktop-dark.jpg`, `currency-phone-light.jpg`, `currency-phone-dark.jpg` (390px frame), `currency-desktop-error.jpg` (the 422), `more-phone-light.jpg`, `import-preview-full.jpg`. All were captured against the worktree's dev server with a seeded collector (four printings, three priced lots; the tiles have no card art).

## Gaps

- AC-3.4 and AC-4.3's second clause are proved by reading and by structure, not by an example.
- AC-4.6 is proved only by CI's upgrade proof.

## Implementation review

SPEC-ALIGNED WITH MINOR GAPS. `sdd-review` Mode B ran read-only on Opus, 2026-11-06, over `b06e9e0..5847f25`. It found nothing blocking.

- Every AC was MET; AC-4.6 was MET BY RUN ONLY, and AC-3.4 was met by the unit test plus reading.
- **Major:** this file was missing. It is now written.
- **m1:** `MorePage.md` didn't list Currency. Fixed.
- **m2:** `fetch!`'s error blamed `COLLECTOR_CURRENCY` for a bad stored code. Fixed with `setting:`, tests first.
- **m3:** AC-6.7's rendered sentence was not asserted. A request example now asserts it.
- **m4:** `xyz` was not tested. It now is.
- **m5:** AC-4.3's second clause has no example. Recorded under Gaps, and no example was added: the two-migration structure is the guarantee, and a Migrator-level example would re-test Rails.
- **m6:** the local `Gemfile.lock` arm64 platform lines. Left uncommitted, as for every branch on this machine.

The review confirmed the `backup_upgrade_spec` vacuity note above. It also checked the stale-currency path, `Current.account` after a refusal, nil handling and tenancy, and found them clean.

## Distillation

Distilled before the merge (2026-11-06, `distill-feature`): `docs/architecture/collection-and-lots.md` (price paid in the account's currency, the `COLLECTOR_CURRENCY` default, the Currency page, the guard, the upgrade that carried the instance currency) and `docs/architecture/data-portability.md` (the export's source, `unsupported_currency`, the plan, the fingerprint, the preview, the apply and its notice, the backup, the decisions). Each doc has a Distillation log row. The index marks the spec Frozen by both, with its plan's retirement owed after the merge. Tenancy and accounts has no area doc, so the account column is described in collection and lots. CLAUDE.md is unchanged.
