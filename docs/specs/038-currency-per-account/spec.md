# Feature 038: Store Currency per Account

**Status:** Approved by the maintainer (2026-11-03) after the spec review (`review.md`, round 1 APPROVED WITH CHANGES, fixed in 0.2.0). The maintainer ruled four decisions on 2026-11-03, all as recommended: no export version change (decision 6), a Currency page linked from More (decision 4), `COLLECTOR_CURRENCY` kept as the default for new accounts only (decision 2) and an import's currency becoming the account's (decision 7).
**Version:** 0.2.0
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Depends on:** [spec 004](../004-design-system-collection/spec.md) (accounts; FR-6, the instance currency), [spec 022](../022-export-collection/spec.md) (the export), [spec 025](../025-import-preview/spec.md) and [spec 028](../028-apply-import/spec.md) (the import), all merged
**Branch:** `038-currency-per-account`
**Issue:** [#64](https://github.com/plainprogrammer/Collector/issues/64) (roadmap, housekeeping lane; hosted-door rule 3)
**Frozen:** the current rules are in [`collection-and-lots.md`](../../architecture/collection-and-lots.md) (parts: each account's currency, its default, the Currency page, the upgrade that carried the instance currency) and [`data-portability.md`](../../architecture/data-portability.md) (parts: the account's currency in the export, the preview, the apply and the backup); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.2.0 | 2026-11-03 | Spec review round 1 (`review.md`) fixed: no price code reads the instance default, with a guard spec (M1); the price places corrected (M2); a desktop account-menu link (M3); the Coverage table's `accounts` mark (M4); supersessions of 030, 032 and the north star (M5); 400 for a missing parameter (M6); `currency_unit` (M7); and the minor findings m1–m10. |
| 0.1.0 | 2026-11-03 | Written from issue #64, [north star](../../north-star.md) hosted-door rule 3, specs 004, 017, 022, 025, 028 and the area docs on [data portability](../../architecture/data-portability.md) and [collection and lots](../../architecture/collection-and-lots.md), with the maintainer's four rulings. |

---

## Problem Statement

The currency a collector's prices paid are shown in is an instance setting: `COLLECTOR_CURRENCY`, read once at boot into `Rails.configuration.x.currency` (spec 004 FR-6). It is a collector's choice, so it is the one known breach of hosted-door rule 3 ("collector choices are stored per account or user", [north star](../../north-star.md)). On an instance with two collectors, one who prices in euros and one in dollars cannot both be right; and an operator who changes the setting relabels every collector's prices at once. The setting also makes an export from a euro instance impossible to restore onto a dollar one: spec 025 decision 3 refuses a file in another currency, and says #64 "revisits this".

**Outcome (issue #64):** a collector chooses the currency their prices paid are shown in.

## Goals

- Each account stores its own currency, and every place that shows or asks for a price paid uses the signed-in account's.
- A collector changes it from a Currency page linked from More.
- An instance upgraded from a release with the setting gives every existing account the instance's current currency, so nothing a collector sees changes on upgrade.
- The export carries the account's currency, and an import brings a file's currency in with its prices.

## Non-Goals

- **Converting amounts.** Prices are stored in minor units and are never converted; changing the currency relabels them, as `COLLECTOR_CURRENCY` did (spec 004 FR-6). There is no rate source, and Collector calls no price service.
- **Prices per lot in different currencies**, or a currency per location. One currency per account, as the export format says ("there is no currency per lot").
- **More currencies.** The 20 codes of `Collector::Currency::SYMBOLS` stay the only ones (the format document lists them; adding one needs no version, [format document](../../export-format/README.md) Versions).
- **Asking at sign-up.** The sign-up form is unchanged (decision 4).
- **A general settings page.** One choice, one small page.
- **Any change to the export format's schema, examples or version** (decision 6).
- **Showing currency in the admin pages.** The operator neither sees nor sets a collector's currency (rule 2).

## Decisions

### 1. The currency is a column on the account

`accounts` gains `currency`, a string of one of the 20 supported codes, `null: false`, with the database default `"USD"`. `Account#currency` stays the string column (the validation, dirty tracking and the select read it); `Account` validates inclusion in `Collector::Currency::SYMBOLS` and adds `Account#currency_unit`, the `Collector::Currency::Unit` the views already use. The account, not the user, owns it, because every other price-related fact and the lots are the account's, and because the export's `currency` sits beside the lots.

Alternative: a column on `users` beside `collection_view`. Rejected: spec 004 FR-3 keeps one user per account today, but ADR 0017 and the format document expect households to share one account, and a shared collection has one currency. Spec 017's profile holds the user's name, email and view; the currency has always been a top-level field of the file, beside the lots.

### 2. `COLLECTOR_CURRENCY` stays, as the default a new account starts with (ruled 2026-11-03)

The variable keeps its name, its 20 codes, its default `USD` and its boot check (an unsupported code stops the app, naming the setting). Its meaning changes: it is the currency a new account is created with, whether by sign-up, by an admin adding a user, or by anything else that builds an account. It is no longer read when a price is shown. Changing it later changes no existing account.

This follows rule 3 as the north star words it ("adds an instance setting or environment variable for something a collector would choose"): the variable is not new, and it no longer holds the choice, only the operator's starting point, as `COLLECTOR_MTG_LANGUAGES` holds the operator's.

A renamed config key would not catch a missed read (an unknown `Rails.configuration.x` key answers empty options, whose `.symbol` is nil, so a price would silently fall back to the locale's `$` and an export would write `null`). So no price code reads the instance default at all: it is reached only through `Account`'s attribute default and the initializer (which validates it and stores it as `Rails.configuration.x.default_currency`), views and helpers read `Current.account.currency_unit`, and a guard spec fails on any `x.currency` or `x.default_currency` in `app/`, `lib/` or `config/` outside `Account` and `config/initializers/currency.rb`.

Alternative not chosen: remove the variable. New accounts would start at USD, and a euro instance's collectors would each choose at first use. The migration would still read the variable once.

### 3. The migration carries the instance's currency to every account

Two migrations, schema then data (`.claude/rules/sqlite-and-migrations.md`):

1. `add_column :accounts, :currency, :string, null: false, default: "USD"`. The default is `"USD"` in `db/schema.rb` on every machine, whatever `COLLECTOR_CURRENCY` was when it was dumped.
2. A data step that sets every account's `currency` to the instance's current code: `COLLECTOR_CURRENCY` read from the environment as the boot check reads it (strip, upcase, default `USD`), checked against an inline copy of the 20 codes (a released migration must not change when `Collector::Currency` does), and applied in one bound `UPDATE`. A code that isn't one of the 20 stops the migration, naming the variable and value, as boot does today; it never falls back silently, because that would relabel a collector's prices. It uses no application model. Its `down` leaves the data.

An instance that never set the variable gets `USD`, which is what its prices have always been shown in. The data step is an `UPDATE` that sets the same value twice to the same result, and it runs once, recorded in `schema_migrations`.

### 4. A Currency page, linked from More (ruled 2026-11-03)

`resource :currency, only: %i[edit update]` (`CurrenciesController`, `edit` at `/currency/edit`), beside Locations in More ("Currency"), and in the desktop account menu beside Export and Import, because More is reached only from the tab bar, which is hidden at 640 px and wider. It acts on `Current.account` only and names no account in a request. The page is a form with one native select of the 20 codes, each written `EUR — €` in the order of `Collector::Currency::SYMBOLS`, the account's own selected, and a submit. A successful update redirects to More (303) with the notice "Prices are now shown in EUR."; a code outside the 20 re-renders the page (422) with a field error and changes nothing. No Stimulus: it works as plain HTML.

The sign-up form is unchanged: a new account starts with the instance's default (decision 2) and its collector changes it from More. This keeps the first-run flow and spec 004's registration criteria as they are.

### 5. Changing it converts nothing and asks no confirmation

The page says so before the collector submits, without naming a target it can't know in plain HTML: "Changing the currency doesn't convert the prices you've entered. They keep their amounts and are shown in the currency you choose." and, when the account has lots with a price, how many ("1 lot has a price paid.", "3 lots have a price paid."), from one `COUNT` of the account's lots. No confirmation step: the change is reversible by choosing the old code, nothing is lost, and the same page shows what happened. Stored `price_paid_cents` never change on a currency update.

Alternative: lock the change while priced lots exist, or convert at a rate the collector types. Rejected as scope; each needs a design of its own and neither is in the issue.

### 6. The export format keeps version 3 (ruled 2026-11-03)

`currency` is already a required, top-level field with exactly the meaning per-account storage gives it, and [the format document says](../../export-format/README.md) "When it becomes each collector's own choice, the field keeps its meaning and the version doesn't change" (spec 017 FR-4 and decision 13 say the same). A reader of version 3 reading a file this release writes misreads nothing; a version 3 reader refuses another currency than its own rather than misreading it, which loses nothing. So the version rule (spec 017 FR-8) says none is due, and no schema, example or ADR changes.

The brief for this spec asked to plan a bump to 4; the maintainer ruled against it when asked, for the reason above. The export writes `accounts.currency`. The document changes in prose only: its Currency section's "Today that is the instance's setting" sentence, the Versions section's "Two changes are already expected" sentence for #64, its Coverage table and the line "`currency` comes from no table yet". The Coverage table marks the `accounts` table "Nothing to export" because it holds only an id and dates (document line 339, asserted at `spec/export_format_document_spec.rb:77`, and spec 017 AC-3.5 says every column of `accounts` is left out). That becomes false: `accounts` is marked "Exported" (its `currency`, written as the file's `currency`), the column table gains `accounts.currency` | `currency`, the other `accounts` columns stay left out, and the example at line 77 changes with it. The Coverage guard fails the suite until the rows exist.

### 7. An import's currency becomes the account's (ruled 2026-11-03)

An import replaces the collection's lots and locations (spec 028 decision 5), and a file's prices are in the file's currency, so applying it sets the account's currency to the file's. This revisits spec 025 decision 3, which refused any file in another currency and left it to #64.

- The plan gains `currency_change`, the file's code when it differs from the account's and nil otherwise, as it has `view_change` (spec 028).
- A file whose only difference is its currency is not "nothing to change" (spec 028 decision 12): applying it changes the account's currency.
- The plan's fingerprint takes the file's code and the account's current one, so a currency changed between preview and apply (another tab, the Currency page) makes the preview stale (spec 028 decision 2). `replan` reads the account's currency afresh inside the transaction, since the apply holds the account loaded before it. If the account was changed to the file's own code and nothing else differs, the apply answers "nothing to change" (spec 028's order checks that before the fingerprint), not stale. The write is in the same transaction as the lots.
- The notice gains "; prices now shown in EUR" when the apply changes the currency, so a currency-only apply doesn't read "Imported: 0 lots added, 0 changed, 0 removed" alone (spec 028 decision 11, spec 029 AC-9.14's notice).
- The preview's Profile section says "Your prices would be shown in EUR instead of USD. Nothing is converted." for a file that changes it, and the file line shows the file's code as today.
- A file's code is well-formed with any three upper-case letters (format document), but this instance shows only the 20. A well-formed file with another code, such as `XYZ`, is refused as a whole: rule `unsupported_currency`, at `/currency`, "Collector can't show prices in XYZ." It replaces `other_currency`, which no longer exists (decision 8's Supersedes table).
- Version 1, 2 and 3 files all carry `currency`, so all behave the same.

Alternatives not chosen: refuse a file in another currency when it has prices (blocks restoring a euro export into a new account at the default); keep refusing any difference (a euro export could never move to a dollar-default instance without the collector first changing currency, even with no lots).

### 8. Where a price is shown or asked for

Every read of the instance currency becomes a read of the signed-in account's: the lot add and edit forms' price label and symbol (`lots/_form`), `LotsHelper#lot_price` (the card page's Your copies table, the collection table, and through `lot_line` the Move copies page and the location removal refusal page), and the import preview (`ImportPreviewsHelper#import_lot_line`). The grid's tiles show no price. The select's options repeat the code for a few currencies (`CHF — CHF`, `SEK — kr`, `NOK — kr`, `DKK — kr`) because `Collector::Currency::SYMBOLS` holds those symbols; that is accepted. In the preview, a held lot (the lots removed) is written in the account's current currency, and a file's row (a problem row) in the file's, because each is a price in its own file or collection. Number entry, the scanner and the quick add record no price (spec 026 FR-3, spec 009), so they are unaffected.

### 9. The operator's pages and cost

An admin's pages show no currency and edit none (rule 2): the users page lists name, email, role and a copy count, as spec 004 AC-5.1 has it, and an admin creating a user starts that account at the instance default (decision 2) with no field for it. The cost per account is one three-character column, one `COUNT` on the Currency page and no background work (rule 4).

## Terms

- **Instance default currency:** the code `COLLECTOR_CURRENCY` holds (default `USD`), the currency a new account starts with.
- **Account's currency:** `accounts.currency`, the one every price of the account is shown in and the export writes.

## Supersedes

Recorded here and in the [specs index](../README.md), never by editing the earlier spec:

| Spec | Superseded | By |
|---|---|---|
| [004](../004-design-system-collection/spec.md) | FR-6's price paid "in one instance-wide currency, set by a documented setting" and its "Currency: an instance setting" line; AC-9.1's "in the instance currency". The boot check of an unsupported code and "changing the currency converts nothing" stay | decisions 1–2, 5, 8 |
| [006](../006-collection-list-view/spec.md) | The collection table's "price paid per copy (in the instance currency …)" | decision 8 |
| [017](../017-export-format/spec.md) | FR-4's "Record the instance's currency at the moment of export, for as long as currency is an instance setting", decision 13's "today the instance's setting", Non-Goal "Per-account currency (#64)", and AC-3.5's "every column of `accounts` is left out" (one column is now exported) | decisions 1, 6 (the field and the version are unchanged, as 017 said they would be) |
| [030](../030-backup-restore/spec.md) | The decision and error-scenario row that say a restored instance with another `COLLECTOR_CURRENCY` shows the same prices with another symbol: each account's currency now restores with its row | AC-7.1 |
| [032](../032-lot-in-a-location/spec.md) | Its Out of Scope and Non-Goal line "Currency per account (#64). It extends the export after this spec; the format version after 3 is its": it extends the export without a version | decision 6 |
| [north star](../../north-star.md) | The hosted-door note "Currency is a collector's choice stored as an instance setting … the one known breach": the breach is closed | decisions 1–2 |
| [022](../022-export-collection/spec.md) | Decision 4's source for `currency` (`Rails.configuration.x.currency.code`) | decision 6 |
| [025](../025-import-preview/spec.md) | Decision 3 (a file in another currency is refused), the Goals line listing "another currency" among refusals, and decision 10's `other_currency` row | decision 7 |
| [028](../028-apply-import/spec.md) | AC-6.4's "the spec's instance currency set to the example's": an example's currency becomes the account's; decision 5's "lots and the profile only", decision 2's fingerprint list, decision 11's notice and decision 12's "nothing to change" all gain the currency | decision 7 |

## User Stories

### Story 1: Choose a currency

As a collector who prices in euros, I want my prices shown in euros however my instance is set up.

- [ ] **AC-1.1** Given a signed-in collector When More shows Then it lists "Currency" beside Locations, linking to `/currency/edit`; and the desktop account menu lists "Currency" beside Export and Import.
- [ ] **AC-1.2** Given an account in USD When the Currency page shows Then one select lists the 20 codes in the order of `Collector::Currency::SYMBOLS`, each as its code, a dash and its symbol (`EUR — €`), with USD selected, and a Save button.
- [ ] **AC-1.3** Given the collector chooses EUR and saves Then `accounts.currency` is `EUR`, they are redirected to More (303) with "Prices are now shown in EUR.", and the lot add and edit forms' price field shows `EUR` in its label and `€` in its prefix.
- [ ] **AC-1.4** Given an account in EUR with a lot priced 1250 cents When the card page, the collection grid and the collection table show it Then the card page's Your copies table and the collection table write `€12.50` and none writes `$`; the grid shows no price; and the Move copies page and the location removal refusal page, which list the lot with its price, write `€12.50` too.
- [ ] **AC-1.5** Given a lot priced 1250 cents When the currency changes Then `price_paid_cents` is still 1250 and no lot's `lot_key` changed (nothing is converted).
- [ ] **AC-1.6** Given an account with 3 priced lots and 2 unpriced When the Currency page shows Then it says changing doesn't convert prices and that 3 lots have a price paid ("1 lot has a price paid." for one); given none priced, the count sentence is left out and the first sentence stays.
- [ ] **AC-1.7** Given `account[currency]` outside the 20 codes (`XYZ`, `eur`, empty, or `EUR ` with a space) When it is submitted Then nothing changes, the page re-renders (422) with a field error "Choose one of the listed currencies.", and the select shows the account's own code. A request without the `account` parameter answers 400 (`params.expect`), as every other form here does.
- [ ] **AC-1.8** Given a signed-out visitor When `/currency/edit` or `PATCH /currency` is requested Then they are sent to sign-in and nothing is read or written.

### Story 2: Each account has its own

As a second collector on the same instance, I want my currency to be mine.

- [ ] **AC-2.1** Given accounts A (USD) and B (USD) When A chooses EUR Then B's currency is still USD and B's pages still write `$`.
- [ ] **AC-2.2** Given a submission naming `account_id`, `id` or any other account attribute Then only `currency` is read (`params.expect`) and the signed-in account is the one changed.
- [ ] **AC-2.3** Given an admin When the users pages show Then no currency is listed or editable there, and creating a user with a `currency` parameter ignores it.

### Story 3: New accounts start at the instance default

As an operator who runs a euro instance, I want my collectors to start in euros.

- [ ] **AC-3.1** Given `COLLECTOR_CURRENCY` is `EUR` at boot When a collector signs up, an admin adds a user, or the operator command creates one (`User::Command`, spec 004 AC-5.7) Then the new account's currency is `EUR`.
- [ ] **AC-3.2** Given the variable unset When an account is created Then it is `USD`.
- [ ] **AC-3.3** Given an existing account in USD When the instance is restarted with `COLLECTOR_CURRENCY=EUR` Then that account is still in USD (the variable no longer reads through to a collector).
- [ ] **AC-3.4** Given `COLLECTOR_CURRENCY=XYZ` When the app boots Then it stops, naming the setting and the value, as spec 004 FR-6 has it.
- [ ] **AC-3.5** Given the variable is `eur` or ` EUR ` Then it is read as `EUR` (the boot check's normalising is unchanged).

### Story 4: An upgrade changes nothing a collector sees

As an operator upgrading, I want every collector's prices shown as they were.

- [ ] **AC-4.1** Given a database from the previous release with three accounts and `COLLECTOR_CURRENCY=EUR` When `db:prepare` runs Then all three accounts have `currency` `EUR`.
- [ ] **AC-4.2** Given the variable unset Then all are `USD`; given `eur` Then all are `EUR`.
- [ ] **AC-4.3** Given an unsupported value When the data migration is run directly with the variable stubbed (the boot check normally refuses first, so `db:prepare` never reaches it) Then it fails, naming the variable and the value, and no account changes; the schema step stays applied and the next run does the data step.
- [ ] **AC-4.4** Given a database with no account Then both migrations pass and `Account.new.currency` is the instance default's code.
- [ ] **AC-4.5** Given a rollback of the data step Then it changes no account; a rollback of the schema step removes the column and leaves every other column as it was.
- [ ] **AC-4.6** Given the upgrade proof (`bin/upgrade-smoke`, spec 031) When it compares the previous release's database with the upgraded one Then every difference is the new column; none is a change of existing data (no entry in `script/upgrade/expected_changes.yml` is needed: the column is new).
- [ ] **AC-4.7** Given the upgrade proof's seed for the next release (`script/upgrade/seeds/next.rb`) Then it gives one account a non-default currency, so the next release's proof shows that the column's data survives an upgrade.

### Story 5: The export carries the account's currency

- [ ] **AC-5.1** Given an account in EUR When it is exported Then the file's `currency` is `EUR` and `format_version` is still `3`; given an account in USD, `USD`.
- [ ] **AC-5.2** Given two accounts in different currencies When each exports Then each file carries its own, and neither's lots or locations appear in the other's.
- [ ] **AC-5.3** Given the schemas, the valid and invalid examples and `ExportFormat::Rules::VERSIONS` Then they are byte-for-byte as before (`[1, 2, 3]`, schemas v1–v3, no new example).
- [ ] **AC-5.4** Given the format document When it is read Then its Coverage table marks `accounts` "Exported" and lists `accounts.currency` as `currency` (the other `accounts` columns stay left out, and `spec/export_format_document_spec.rb:77` changes to match), the sentence "`currency` comes from no table yet" is replaced, and the Currency and Versions sections say the field comes from the account and no version change was made (read; the suite checks the Coverage row).

### Story 6: An import brings its currency in

As a collector restoring a euro export onto an instance whose default is dollars, I want the prices to arrive as euros.

- [ ] **AC-6.1** Given a file in the account's own currency When it is previewed Then it behaves as before this spec: no currency line, no refusal.
- [ ] **AC-6.2** Given a USD account and a file in EUR with lots When it is previewed Then it is not refused, the Profile section says "Your prices would be shown in EUR instead of USD. Nothing is converted.", and the file line shows EUR.
- [ ] **AC-6.3** Given that file When it is applied Then the account's currency is `EUR`, the lots are written as spec 028 says, and the notice reads as before with "; prices now shown in EUR" added (decision 7).
- [ ] **AC-6.4** Given a file in EUR with no lots and an account in USD with no lots When it is previewed Then it is not "nothing to change" and applies, setting EUR.
- [ ] **AC-6.5** Given a file that matches the collection in every lot and location and differs only in currency When it is previewed Then it can be applied and applying changes only the currency; given the same currency it is "nothing to change" as spec 028 decision 12 has it.
- [ ] **AC-6.6** Given a well-formed file whose currency is `XYZ` Then it is refused as a whole with "Collector can't show prices in XYZ.", rule `unsupported_currency`, at `/currency`, with no rows shown; a file with `xyz` or `EURO` is "not a well-formed export" as before (the schema's pattern).
- [ ] **AC-6.7** Given a preview of a EUR file and the account's currency then changed to GBP on the Currency page When the apply is submitted Then it is refused as stale and shows the new plan (the fingerprint holds both codes); the stored plan was `EUR instead of USD`, and now says `EUR instead of GBP`.
- [ ] **AC-6.8** Given a preview whose lots removed and problem rows are listed When it shows Then a removed lot's price is written in the account's current currency and a problem row's in the file's.
- [ ] **AC-6.9** Given an apply that fails in its transaction (any reason that leaves lots unwritten) Then the account's currency is unchanged.
- [ ] **AC-6.10** Given each valid example in `docs/export-format/examples/valid/` applied to an empty account Then exporting the result holds the same collection as the example including its currency (the profile's name and email aside), whatever currency the example carries (spec 028 AC-6.4, rewritten).
- [ ] **AC-6.11** Given a version 1, 2 or 3 file Then each of the above holds.

### Story 7: Backup and restore keep it

- [ ] **AC-7.1** Given a backup of an instance with accounts in two currencies When it is restored onto a fresh volume Then each account has its own currency (the column is in the primary database, which the backup holds in full; spec 030).

## Functional Requirements

### FR-1: The column and the model
**Must:** `accounts.currency` as in decision 1 (`null: false`, default `"USD"`); `Account` validates inclusion in the 20 codes and answers `currency` as a `Collector::Currency::Unit`; a new account starts with `Rails.configuration.x.default_currency`'s code; no collectible type is named.
**Must not:** accept a code outside the 20; read the environment per request.

### FR-2: The Currency page
**Must:** decisions 4 and 5; `Current.account` only; `params.expect`; 422 with a field error for a bad code; plain HTML.
**Must not:** name an account in a request; convert or touch a lot; need scripting.

### FR-3: The migrations
**Must:** decision 3, as two migrations, with no application model, an inline list of codes and one bound `UPDATE`.
**Must not:** edit a released migration; fall back on an unsupported code; run from a model.

### FR-4: Showing a price
**Must:** every price paid shown or asked for uses the signed-in account's `currency_unit` (decision 8); `Rails.configuration.x.currency` is no longer defined, and a guard spec fails on a read of it or of `x.default_currency` outside `Account` and the initializer (decision 2).
**Must not:** call the instance default when showing a price; show a lot's price in another account's currency.

### FR-5: The export
**Must:** write `accounts.currency` as `currency`, format version 3; update the format document's prose and Coverage table (decision 6).
**Must not:** change the schemas, the examples or `VERSIONS`; write a currency the account doesn't have.

### FR-6: The import
**Must:** decision 7: `currency_change` in the plan, the fingerprint and the preview; the write in the apply's transaction; `unsupported_currency` for a well-formed code the instance can't show; the table of refusals and the document updated; the notice gains the currency part.
**Must not:** apply a currency without the lots' transaction; refuse a supported code; use the instance default as the account's.

## Non-Functional Requirements

- **Upgrade safety:** both migrations are safe to run unattended from any prior version and never edit a released one (`script/upgrade/guard.rb`); the data step touches only `accounts.currency`.
- **Performance:** a price's symbol comes from the already loaded account; no query per row. The Currency page's count is one `COUNT` on `lots` with an index-backed `account_id`.
- **Security:** no mass assignment beyond `currency`; the tenant is `Current.account`; Brakeman stays clean.
- **Design system:** the page uses the design system's form, select, field-error and page-head patterns and copy rules (`docs/design-system/`, the `collector-design-system` skill, read before the view); no new component or CSS is expected. The label is a `<label>` for the select and the error is tied to it with `aria-describedby`.
- **Hosted-door rules:** rule 3 is met, because the choice is per account and the variable is only a default (decision 2); rule 2, because no admin page shows or edits it (decision 9); rule 4, because the cost is one column and one `COUNT` (decision 9); rule 1 is not touched.
- **Documents:** the area docs [data portability](../../architecture/data-portability.md) and [collection and lots](../../architecture/collection-and-lots.md) and the format document are updated in this pull request (`.claude/rules/documentation.md`).

## Error Scenarios

| Situation | Behaviour |
|---|---|
| Currency code outside the 20, lower-case, padded or missing | Page re-renders (422), field error, nothing changes (AC-1.7) |
| Signed out | Sent to sign-in (AC-1.8) |
| `COLLECTOR_CURRENCY` unsupported at boot | The app stops, naming the setting and value (AC-3.4) |
| `COLLECTOR_CURRENCY` unsupported when the data migration runs | The migration fails, naming it; no account changes (AC-4.3) |
| An import in a well-formed but unsupported currency | Refused as a whole, `unsupported_currency` (AC-6.6) |
| The currency changes between preview and apply | Stale, the new plan shown (AC-6.7) |
| An apply fails | The currency is unchanged with the lots (AC-6.9) |

## Open Questions

None. The four decisions that the issue left open were ruled on 2026-11-03.

## Out of Scope (Future Considerations)

- Converting prices between currencies, or storing a currency per lot.
- Asking for the currency at sign-up (decision 4).
- Showing a collection's total value (no price service exists; the roadmap has no such item).
- Supporting more currencies (adding one is a code list change and needs no version).

## Documents that change

| Document | Change |
|---|---|
| [`docs/export-format/README.md`](../../export-format/README.md) | Currency and Versions prose; Coverage table row for `accounts.currency`; "`currency` comes from no table yet" replaced. No schema, example or version change |
| [`docs/architecture/data-portability.md`](../../architecture/data-portability.md) | Export source of `currency`; refusal row 8 becomes `unsupported_currency`; the plan, fingerprint, preview and notice gain the currency; the #64 lines under "Decisions not in an ADR" and in Sources rewritten; Sources add spec 038 |
| [`docs/north-star.md`](../../north-star.md) | The hosted-door note on currency as the one known breach is rewritten: closed by spec 038 |
| [`docs/backup-restore.md`](../../backup-restore.md) | Only if it repeats the sentence that a restore with another `COLLECTOR_CURRENCY` shows another symbol |
| [`docs/architecture/collection-and-lots.md`](../../architecture/collection-and-lots.md) | "Price paid … shown in the one instance currency" and the `COLLECTOR_CURRENCY` row rewritten for the account's currency and the default; #64 source line |
| `README.md` | The `COLLECTOR_CURRENCY` row and the sentence after the table (default for new accounts; collectors change it from More; changing converts nothing); the backup paragraph that says a restored instance with another currency shows the same prices with another symbol |
| `compose.yaml`, `config/deploy.yml` | Comment on `COLLECTOR_CURRENCY`: the default for new accounts |
| `docs/specs/README.md`, `docs/roadmap.md` | A row for 038 and the supersession columns of 004, 006, 017, 022, 025 and 028; the roadmap's #64 line marked built |
