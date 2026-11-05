# Spec 038 review

## Round 1 (2026-11-03)

Read-only review of spec 0.1.0 by a separate agent on Opus, against the code, the north star, `.claude/rules/` and the earlier specs. **Verdict: APPROVED WITH CHANGES** (no blocking finding; the four rulings of 2026-11-03 stand and nothing in the repo forces a format version bump). All findings were fixed in spec 0.2.0 unless noted.

| ID | Finding | Resolution |
|---|---|---|
| M1 | Renaming `x.currency` doesn't make a missed read fail: an unknown `Rails.configuration.x` key returns empty options, so `.symbol` is nil (a price falls back to `$`) and `.code` writes `null` | Decision 2: no price code reads the instance default; views read `Current.account.currency_unit`; a guard spec fails on `x.currency` or `x.default_currency` outside `Account` and the initializer; FR-4 |
| M2 | The grid shows no price; Move copies and the location removal refusal page do | Decision 8, AC-1.4 |
| M3 | More is reached only from the tab bar, hidden at 640 px and wider | Decision 4 and AC-1.1 add the desktop account menu link (beyond the ruled "linked from More"; flagged to the maintainer) |
| M4 | The Coverage table's `accounts` row ("Nothing to export"), `spec/export_format_document_spec.rb:77` and 017 AC-3.5 contradict an exported column | Decision 6, AC-5.4, Supersedes (017 AC-3.5) |
| M5 | Specs 030 and 032 and the north star state the opposite | Supersedes table, index row, Documents table |
| M6 | `params.expect` answers 400, not 422, for a missing parameter | AC-1.7 names `account[currency]`; a missing `account` is 400 |
| M7 | `Account#currency` can't be both the column and a `Unit` | Decision 1, FR-1: the column stays a string; `currency_unit` returns the `Unit`; AC-4.4 |
| m1 | The page can't name the target currency before submit | Decision 5 wording; AC-1.6 singular |
| m2 | The migration's refusal is unreachable through `db:prepare` (boot refuses first) | AC-4.3 tests it by running the migration with the variable stubbed |
| m3 | Notice for a currency-only apply | Decision 7 and AC-6.3: "; prices now shown in EUR" |
| m4 | `replan` must reload the account; a change to the file's own code is "nothing to change" | Decision 7 |
| m5, m6, m7 | Wrong or missing supersession and document references | Supersedes and Documents tables corrected (CLAUDE.md row dropped: it never names the currency) |
| m8 | `User::Command` also creates accounts | AC-3.1 |
| m9 | The next release's upgrade seed has no non-default currency | AC-4.7 |
| m10 | Select options repeat the code for CHF, SEK, NOK, DKK | Accepted knowingly, stated in decision 8 |

Only a run could confirm: that no `x.currency` reader is left; that `spec/backup_upgrade_spec.rb`'s `STEP=1` rollback still proves the schema step reversible; that the data step's `UPDATE` leaves `updated_at` alone for the upgrade proof; the stale page's "EUR instead of GBP"; and Brakeman on the new controller. The plan names a task for each.

Challenge raised once: the rename was the weakest claim (M1). The reviewer's alternative, adopted, is to remove the per-request config read entirely.
