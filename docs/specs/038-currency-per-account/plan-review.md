# Plan 038 review

## Round 1 (2026-11-03)

Read-only review of the first plan by a separate agent on Opus: every code block traced against the files it edits, every AC walked by hand, nothing run. **Verdict: NEEDS REVISION** (mechanical; the design held). All findings fixed in the rewritten plan.

| ID | Finding | Resolution |
|---|---|---|
| B1 | Phase 1 turned the suite red until phases 4 and 5: the initializer stopped setting `x.currency` while five readers remained (a nil symbol, a `null` currency in the export, every import refused), and the new column failed the Coverage guard until the format document listed it | Phases reordered: data layer whole (column, model, Coverage rows, export) with a temporary `x.currency` alias; then every reader, the import included, with the alias and the guard spec removed in the last commit; the Currency page last |
| M1 | More and menu additions break exact-list and position assertions in `admin/navigation_spec`, `locations_spec:334`, `number_entries_spec:34`, `shell_spec:53,60,61` | Listed in phase 3; the menu item goes after Import so its first two stay Export and Import |
| M2 | Several spec files named in the plan don't exist | Corrected to `lot_moves_spec`, `collection_table_spec`, `catalog/entries_show_spec`, `routing/routes_spec`; the nav assertions live in the files of M1 |
| M3 | AC-6.9's example couldn't fail (the stubbed call ran before the currency write) | The currency is written first in `Apply#write!`, and the example fails a later statement with a `BEFORE INSERT ON lots` trigger and reloads the account |
| m1 | Typographic quotes in the `notice_for` draft | Fixed |
| m2 | The appbar partial needs `section:` | `section: nil` passed |
| m3 | `c-input` wrapper contradicts the lot form's select | Dropped |
| m4 | No `Current.user` writer for the helper spec | `Current.session = user.sessions.create!` |
| m5 | A failed update leaves the rejected code on `Current.account` | The controller keeps the messages and calls `restore_attributes` |
| m6 | The data step interpolated instead of binding | `sanitize_sql_array` |
| m7 | Migration spec details: `reset_column_information`; `remove_column` copies the table so `disable_ddl_transaction!` is required; plain `add_column`; the Migrator's `run` is a no-op for the data step | Phase 1 follows all four |
| m8 | The guard regex was unanchored; `lib/collector/currency.rb`'s comment must not trip it | `\b` anchor; the comment rule stated |
| m9 | `import_lot_line`'s `currency:` is never nil | Stated |
| m10 | `docs/roadmap.md:144` and the index row's Status | In phase 4; the index row and spec Status now say Approved |
| m11 | `currency_spec` has no boot example | AC-3.4's evidence will say it tests `fetch!` |

ACs the review found with no test or no step: AC-3.3 (test added), AC-6.9 (M3), AC-6.2's "the file line shows EUR" (asserted in 2b), AC-4.6 (CI's `bin/upgrade-smoke` only, as the plan says).

Only a run could confirm: a Hash `ENV` stub reaching the migration; the `schema.rb` dump; the `x.default_currency` stub; an account's in-memory state after a rolled-back `update!`; the stale page's "EUR instead of GBP"; `spec/backup_upgrade_spec.rb`'s `STEP=1` now rolling back only the empty data step; Brakeman and RuboCop on the new files.

Challenge raised once: the plan's weakest point was its phase order, splitting one cross-cutting rename across four phases. The reviewer's alternative, adopted: change the data layer first, then move every reader and delete the old key together, and ship the Currency page last.
