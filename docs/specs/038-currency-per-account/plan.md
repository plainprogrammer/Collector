# Plan: Spec 038, Store Currency per Account

**Spec:** [spec.md](spec.md) 0.2.0 (approved 2026-11-03)
**ADR:** none. The maintainer chose no version change without an ADR (decision 6); ADR 0026 stays unused.

Four phases, each tests first (red, then green), each leaving `bin/rspec` green for the files it touched and the branch releasable, one Conventional Commit per step. Code blocks are strong drafts, not pre-run: where a run disagrees, the deviation is recorded as a ruling in the commit body.

The order is set by one fact: every reader of `Rails.configuration.x.currency` must move before the key goes, and the Coverage guard fails the moment `accounts` has a column the format document doesn't list. So the data layer lands whole (column, model, Coverage rows, export), with `x.currency` kept as a temporary alias; then every reader moves and the alias and the guard spec land in one commit; the Currency page comes last, because it is the only way an account's currency can differ from the instance's, so no half-moved reader can show a wrong value before then (plan review B1).

File overlap, for a parallel worker: phase 1 `db/`, `config/initializers/`, `app/models/account.rb`, `collection_export.rb`, the format document; phase 2 helpers, `lots/_form`, `collection_import*`, the imports controller, the preview view; phase 3 `config/routes.rb`, a new controller and views, two navigation views and their specs; phase 4 the seed and documents. Phases 2 and 3 touch different files but 3 needs 2's guard in place, so they run in order.

## Phase 1: The data layer, whole (spec FR-1, FR-3, FR-5; AC-3.x, AC-4.x, AC-5.x)

**Tests first**

1. `spec/migrations/add_currency_to_accounts_spec.rb`, modelled on `spec/migrations/add_location_to_lots_spec.rb` (`:backup, :committed`, the Migrator, no application model; `around` ends with `up` if the column is missing and `Account.reset_column_information`, as that spec does for `Lot`, because `Account` now declares and validates the column): asserts `described_class.disable_ddl_transaction` is true (required: `remove_column` copies `accounts` on SQLite, which is safe only because that flag lets Rails turn foreign keys off for the copy, `sqlite3_adapter.rb`); down then up leaves every other column and every row; the column is `NOT NULL` with default `USD`.
2. `spec/migrations/set_account_currency_from_the_instance_spec.rb`: call the object's `migrate(:up)` directly (the Migrator's `run` is a no-op in the test database, because schema load records every version) with `ENV` stubbed (`stub_const("ENV", ENV.to_h.merge("COLLECTOR_CURRENCY" => "eur"))`; `allow(ENV).to receive(:fetch).with("COLLECTOR_CURRENCY", "USD")` is the fallback if a Hash `ENV` breaks the example, and `ENV["COLLECTOR_CURRENCY"]` in the raise message must be stubbed with it): three accounts all become `EUR`; unset gives `USD`; ` eur ` gives `EUR`; `XYZ` raises naming `COLLECTOR_CURRENCY` and `"XYZ"` and leaves the accounts as they were; no account passes; `down` changes no account (AC-4.1–4.5).
3. `spec/models/account_spec.rb` gains: `Account.new.currency` is the default's code and follows a stubbed `Rails.configuration.x.default_currency` (`allow(Rails.configuration.x).to receive(:default_currency).and_return(Collector::Currency.fetch!("EUR"))`); `XYZ`, `eur`, blank are invalid with the message "Choose one of the listed currencies."; `currency_unit` answers the `Unit`; and **AC-3.3**: an account created under the stubbed default `USD`, then with the stub returning `EUR`, still reads `USD` after `reload` (AC-3.1–3.3, FR-1).
4. `spec/models/user_spec.rb` (if none, `spec/models/user/command_spec.rb`; find with `ls spec/models | grep user`): users made with `create(:user)`, `User::Command.call` and `Registration#save` each get the stubbed default (AC-3.1).
5. `spec/lib/collector/currency_spec.rb` line 14 reads `Rails.configuration.x.default_currency` (AC-3.2); add a ` eur ` normalising example for `fetch!` (AC-3.5). `fetch!`'s error example stays; it tests `fetch!`, not the boot (AC-3.4's evidence in `verification.md` says so).
6. `spec/models/collection_export_spec.rb:44`: `"currency" => account.currency`, plus an EUR account writing `EUR` with `format_version` 3, and two accounts in different currencies each exporting their own (AC-5.1, AC-5.2); plus an example that `ExportFormat::Rules::VERSIONS` is `[1, 2, 3]` and `CollectionExport::FORMAT_VERSION` is 3 (AC-5.3; the schemas and examples are untouched, so `rules_spec` and `export_format_examples_spec` staying green is the rest of the proof).
7. `spec/export_format_document_spec.rb:77`: `"accounts" => "Exported"`. Run it red first: with the column and no Coverage rows, "every column of a table that isn't left out whole" fails (AC-5.4).

**Code**

- `db/migrate/20261103100001_add_currency_to_accounts.rb`:

  ```ruby
  # Gives every account the currency its prices are shown in (spec 038 decision 1). The next migration carries the instance's
  # current currency to it; this step's default is USD on every instance, so schema.rb is the same everywhere.
  # Without a transaction: SQLite copies the table to drop a column, and with foreign keys enforced the copy's DROP TABLE would
  # run the ON DELETE actions of every table that points at accounts. Rails turns enforcement off for the copy only outside a
  # transaction (see AddLocationToLots).
  class AddCurrencyToAccounts < ActiveRecord::Migration[8.1]
    disable_ddl_transaction!

    def up
      add_column :accounts, :currency, :string, null: false, default: "USD" unless column_exists?(:accounts, :currency)
    end

    def down
      remove_column :accounts, :currency if column_exists?(:accounts, :currency)
    end
  end
  ```

  `add_column` with `null: false` and a default is a plain `ALTER TABLE .. ADD COLUMN` on SQLite (not a table copy).
- `db/migrate/20261103100002_set_account_currency_from_the_instance.rb`:

  ```ruby
  # Carries the instance's current currency to every account, so an upgrade changes nothing a collector sees (spec 038
  # decision 3). The codes are copied inline: a released migration must not change when Collector::Currency does.
  class SetAccountCurrencyFromTheInstance < ActiveRecord::Migration[8.1]
    CODES = %w[USD CAD AUD NZD EUR GBP CHF SEK NOK DKK PLN CZK JPY CNY KRW SGD HKD BRL MXN ZAR].freeze

    def up
      code = ENV.fetch("COLLECTOR_CURRENCY", "USD").strip.upcase
      raise "COLLECTOR_CURRENCY #{ENV["COLLECTOR_CURRENCY"].inspect} is not supported; use one of #{CODES.join(", ")}" unless CODES.include?(code)

      execute ActiveRecord::Base.sanitize_sql_array([ "UPDATE accounts SET currency = ?", code ])
    end

    def down
    end
  end
  ```
- `db/schema.rb`: `bin/rails db:migrate`, then restore the cable, cache and queue schema noise and keep the version line (memory: *Migrate schema noise*). Expect `t.string "currency", default: "USD", null: false` on `accounts`.
- `config/initializers/currency.rb`: set `Rails.configuration.x.default_currency = Collector::Currency.fetch!(ENV.fetch("COLLECTOR_CURRENCY", "USD"))` and, **temporarily**, `Rails.configuration.x.currency = Rails.configuration.x.default_currency` with a comment "TEMPORARY until phase 2 moves the last reader (spec 038 plan)"; the main comment says the variable is the currency a new account starts with. `lib/collector/currency.rb`'s header names the account, and must not contain the text `x.default_currency` (phase 2's guard scans `lib/`).
- `app/models/account.rb`:

  ```ruby
  attribute :currency, :string, default: -> { Rails.configuration.x.default_currency.code }
  validates :currency, inclusion: { in: Collector::Currency::SYMBOLS.keys, message: "Choose one of the listed currencies." }

  # What a price of this account is shown with: the code and the symbol (spec 038 decision 1).
  def currency_unit = Collector::Currency.fetch!(currency)
  ```
- `app/models/collection_export.rb:24`: `"currency" => @account.currency`.
- `docs/export-format/README.md`: Currency section's "The code is the currency in force for the collector…" paragraph says it is the collector's own (the account's) and that no version changed; Versions' "Two changes are already expected" sentence loses #64 (the household sentence stays); Coverage: `accounts` row "Exported", why "Its `currency`; the other columns are left out"; the column table gains `| accounts.currency | currency | |`; "`currency` comes from no table yet…" becomes "`currency` is `accounts.currency`." Schemas, `examples/` and `**Format version:** 3` are not touched.

**Commits:** `feat(accounts): add currency to accounts`, `feat(accounts): carry the instance currency to every account`, `feat(accounts): start a new account in the instance's default currency`, `feat(export): write the account's currency`, `docs(export-format): the currency is the account's, version unchanged`.

## Phase 2: Every reader moves, and the old key goes (spec FR-4, FR-6; AC-1.3–1.5, AC-6.x)

Order inside the phase: the display readers, then the import, then, in the last commit, the alias and the guard.

### 2a. Show prices in the account's currency

**Tests first**

- `spec/helpers/lots_helper_spec.rb` (new; there is no precedent for a signed-in helper spec: `Current` has only a `session` writer, so `Current.session = user.sessions.create!` in a `before`, reset by the suite's `Current` reset): `lot_price` writes `$12.50` for a USD account and `€12.50` once the account's currency is `EUR`; `—` for no price; `lot_line` of a priced lot ends in `€12.50`.
- Request examples that add an EUR case beside the USD ones that stay green (the existing `$` assertions are on default USD accounts): `spec/requests/catalog/entries_show_spec.rb:161` (Your copies table), `spec/requests/collection_table_spec.rb:23` (table; and the grid, in `spec/requests/collections_spec.rb`, shows neither `$` nor `€`), `spec/requests/lot_moves_spec.rb` (Move copies page), the location removal refusal examples in `spec/requests/locations_spec.rb`, and `spec/requests/lots_spec.rb:42` (label `Price paid per copy (EUR)`, prefix `€`). The accounts are set with `user.account.update!(currency: "EUR")` (AC-1.3, AC-1.4).

**Code**

- `app/helpers/lots_helper.rb:22`: `unit: Current.account.currency_unit.symbol`.
- `app/views/lots/_form.html.erb:26-27`: `Current.account.currency_unit.code` and `.symbol`.
- `app/helpers/import_previews_helper.rb:8-9`: `import_lot_line` gains a required `currency:` keyword (a `Collector::Currency::Unit`, never nil); a price in the format's form is written with `currency.symbol`. Callers in `app/views/collections/import_previews/show.html.erb` line 47 (a held lot) pass `currency: Current.account.currency_unit`, line 71 (a file's row) `currency: Collector::Currency.fetch!(@import.currency)` (decision 8; a file's code is one of the 20 here, because 2b refuses the rest).

**Commit:** `refactor(prices): show a price in the signed-in account's currency`.

### 2b. An import brings its currency in

**Tests first** (rewrite what decision 3 made, add the new)

- `spec/models/collection_import_spec.rb:95-96`: becomes "reads a file in another supported currency, even with no lots" (`plan.currency_change` is `from: "USD", to: "EUR"`), plus a refusal `[ "unsupported_currency", "/currency", "Collector can't show prices in XYZ." ]` for `currency: "XYZ"`; `usd` stays a schema refusal (line 87); a file in the account's own currency has no `currency_change` (AC-6.1, AC-6.6).
- The `Plan` examples (find them: `git grep -n 'nothing_to_change' spec`): `nothing_to_change?` is false when only the currency differs and true when nothing does (AC-6.4, AC-6.5); the fingerprint differs between a plan with and without the change and between `EUR instead of USD` and `EUR instead of GBP`, and is unchanged for a plan without one.
- `spec/models/collection_import/apply_spec.rb` (exists; its triggers at lines 727-735 are the pattern): applying a EUR file to a USD account sets `EUR` (AC-6.3); **AC-6.9:** a `BEFORE INSERT ON lots` trigger that raises (as lines 727-735 do) makes the apply fail after the currency write, and `account.reload.currency` is still `USD` (the assertion reloads: an account rolled back after a failed `update!` may keep the new value in memory); the account changed to GBP after the preview makes the apply `:stale` and the replanned plan says `EUR instead of GBP` (AC-6.7); the account changed to the file's own code with nothing else different answers `:nothing_to_change`; a currency-only file applies and changes only the currency (AC-6.5).
- `spec/requests/collection_import_previews_spec.rb`: line 282's refusal list swaps the EUR row for `file([], currency: "XYZ") => "Collector can't show prices in XYZ."`; lines 429-450 (empty examples "in its own currency"): the `x.currency` stubs go, the EUR examples (`empty.json`, `empty-v2.json`) are previewed, applicable, say "Your prices would be shown in EUR instead of USD. Nothing is converted.", show `EUR` in `.c-pagehead__stats` and offer the apply (AC-6.2, AC-6.4); the same with `user.account.update!(currency: "EUR")` is "nothing to change" with no apply (AC-6.1); a removed lot's price is in the account's currency and a problem row's in the file's (AC-6.8).
- The apply request spec (`ls spec/requests | grep import`): the notice for a currency-only apply is `Imported: 0 lots added, 0 changed, 0 removed; prices now shown in EUR`, and with locations the currency part comes last (AC-6.3).
- `spec/models/collection_import/round_trip_spec.rb:145`: the stub goes; the account is created at its default; a file with no lots and no locations is "nothing to change" when its currency equals the account's and otherwise a currency-only plan that applies and exports the same collection including `currency`; every other example applies and exports the same collection; versions 1, 2 and 3 are all in the loop (AC-6.10, AC-6.11).

**Code**

- `app/models/collection_import.rb`:

  ```ruby
  CurrencyChange = Data.define(:from, :to)

  # A well-formed code this instance can't show is refused as a whole (spec 038 decision 7); any of the 20 is brought in.
  def currency_refusal
    code = @data["currency"]
    return if Collector::Currency::SYMBOLS.key?(code)

    refuse("unsupported_currency", "/currency", "Collector can't show prices in #{code}.")
  end

  # What applying would do to the account's currency, nil when the file's is the account's.
  def currency_change = (CurrencyChange.new(from: @account.currency, to: currency) if currency != @account.currency)
  ```

  `plan` and `replan` build `Plan.new(outcomes, view_change, locations, currency_change)`; `replan` begins with `@account.reload` (then the existing `user.reload`), so the account's currency is read afresh inside the apply's transaction.
- `app/models/collection_import/plan.rb`: take and expose `currency_change`; `nothing_to_change?` adds `&& currency_change.nil?`; the fingerprint appends `parts << [ currency_change.from, currency_change.to ] if currency_change` after the locations part, so a plan without a change keeps its fingerprint.
- `app/models/collection_import/apply.rb` `write!`: the currency is written **first**, before the deletes: `@account.update!(currency: plan.currency_change.to) if plan.currency_change` (inside the transaction; it validates), so a failure of any later statement is what AC-6.9's test exercises. Header comments of `Apply` and `Plan` name it.
- `app/controllers/collections/imports_controller.rb` `notice_for`: `[ lots, location_sentence(plan.locations), ("prices now shown in #{plan.currency_change.to}" if plan.currency_change) ].compact.join("; ")`.
- `app/views/collections/import_previews/show.html.erb`: the Profile section's condition gains `|| @import.currency_change`, and its list starts with `<li>Your prices would be shown in <%= @import.currency_change.to %> instead of <%= @import.currency_change.from %>. Nothing is converted.</li>` when set. The stale page renders the same view from the replanned plan.

**Commits:** `feat(import): refuse a currency the instance can't show`, `feat(import): plan a currency change`, `feat(import): apply the file's currency and say so in the notice`, `test(import): the examples apply whatever currency they carry`.

### 2c. The old key goes, with its guard

**Test first:** `spec/currency_reads_spec.rb` (a source check, like `spec/footer_core_spec.rb`; the spec's decision 2). It is red while the alias remains:

```ruby
require "rails_helper"

# Spec 038 decision 2: no price code reads the instance default. A renamed key would answer empty options (a nil symbol,
# so `$`), so the reads are removed and checked here instead.
RSpec.describe "Reads of the instance currency" do
  let(:files) { Dir.glob(Rails.root.join("{app,lib,config}/**/*.{rb,erb}")).map { |path| Pathname(path).relative_path_from(Rails.root).to_s } }
  let(:allowed) { %w[app/models/account.rb config/initializers/currency.rb] }

  it "are left to Account and the initializer", :aggregate_failures do
    offenders = files.reject { |file| allowed.include?(file) }.select { |file| Rails.root.join(file).read.match?(/\bx\.(default_)?currency\b/) }
    expect(offenders).to be_empty
    expect(Rails.root.join("config/initializers/currency.rb").read).not_to match(/\bx\.currency\b/)
  end
end
```

**Code:** delete the temporary `x.currency` line from the initializer. `git grep -n 'x\.currency' -- app lib config script spec ':!.kamal/secrets'` is empty (the specs that stubbed it were rewritten in 2b).

**Commit:** `refactor(currency): remove the instance currency key and guard against its return`.

## Phase 3: The Currency page (spec decisions 4–5, FR-2; AC-1.1, AC-1.2, AC-1.6–1.8, AC-2.x)

Read `docs/design-system/README.md` and the `collector-design-system` skill before the views (CLAUDE.md).

**Tests first**

- `spec/requests/currencies_spec.rb` (`type: :request`, modelled on `spec/requests/locations_spec.rb`, `sign_in_as(user)`):
  - signed out: `get edit_currency_path` and `patch currency_path` go to sign-in and write nothing (AC-1.8);
  - `get edit_currency_path`: one select `account[currency]` with the 20 options in `Collector::Currency::SYMBOLS` order, each text `"EUR — €"` (symbol stripped; `CHF — CHF`, `SEK — kr` accepted), the account's own selected, a Save button; the sentence "Changing the currency doesn't convert…"; with 3 priced and 2 unpriced lots "3 lots have a price paid.", with one "1 lot has a price paid.", with none no count sentence (AC-1.2, AC-1.6);
  - `patch currency_path, params: { account: { currency: "EUR" } }` redirects (303) to `more_path`, notice "Prices are now shown in EUR.", `account.reload.currency == "EUR"`, every lot's `price_paid_cents` and `lot_key` unchanged (AC-1.3, AC-1.5);
  - each of `XYZ`, `eur`, `""`, `"EUR "` answers 422 with "Choose one of the listed currencies." in `#account_currency-error`, the account's own code selected and the column unchanged (AC-1.7); a request without `account` answers 400;
  - tenancy: two users; one changes to EUR; the other's currency and pages stay `$` (AC-2.1); `account: { currency: "EUR", id: other.account.id }` and `account_id:` change only the signed-in account (AC-2.2).
- `spec/routing/routes_spec.rb` (exists): `/currency/edit` and `PATCH /currency` route to `currencies#edit` and `#update`; nothing else is routed.
- Navigation: More's list and the account menu are asserted exactly or by position in several existing examples; update each, reading it first: `spec/requests/admin/navigation_spec.rb:15,16,25,26` (More and menu link lists), `spec/requests/locations_spec.rb:334` (`.c-more li a` `first(4)`), `spec/requests/number_entries_spec.rb:34` (`li:nth-child(5)`), `spec/requests/shell_spec.rb:53,60,61` (`nth-child(3)`, menu `first(2)`, `nth-child(4)`). More gets "Currency" after Locations (which shifts later positions by one); the account menu gets it after Import and before the separator, so its first two items stay Export and Import. New expectations: More lists "Currency" linking to `/currency/edit`, and the account menu does too (AC-1.1).
- `spec/requests/admin/users_spec.rb` (or the file that holds the admin user examples; `ls spec/requests/admin`): the users page lists no currency, and `post admin_users_path` with a `user[currency]` creates an account at the default (AC-2.3, AC-3.1).

**Code**

- `config/routes.rb`, after `resource :more`: `resource :currency, only: %i[edit update]`.
- `app/controllers/currencies_controller.rb`:

  ```ruby
  # Spec 038: the signed-in collector's currency. Every lookup goes through Current.account, and nothing in a request names
  # an account, so there is no other account to reach.
  class CurrenciesController < ApplicationController
    def edit
      @account = Current.account
      @priced = priced_lots
    end

    def update
      @account = Current.account
      if @account.update(params.expect(account: [ :currency ]))
        redirect_to more_path, notice: "Prices are now shown in #{@account.currency}.", status: :see_other
      else
        @messages = @account.errors.messages_for(:currency)
        @account.restore_attributes # Current.account must not keep the rejected code
        @priced = priced_lots
        render :edit, status: :unprocessable_content
      end
    end

    private
      # One COUNT for the page's second sentence (spec 038 decision 5).
      def priced_lots = @account.lots.where.not(price_paid_cents: nil).count
  end
  ```

  A missing `account` raises `ParameterMissing` (400) from `params.expect`, as in the other controllers.
- `app/helpers/currencies_helper.rb`: `currency_options` = `Collector::Currency::SYMBOLS.map { |code, symbol| [ "#{code} — #{symbol.strip}", code ] }`.
- `app/views/currencies/edit.html.erb` (shaped like `app/views/locations/edit.html.erb`): title "Currency · Collector"; `render "layouts/appbar", section: nil, detail: true, back_path: more_path` (the partial reads the bare `section` local); heading "Currency"; the two sentences (count sentence only when `@priced.positive?`); `form_with model: @account, url: currency_path, method: :patch, class: "c-form"` holding a `c-field` (`c-field--invalid` when `@messages` is set) with `form.label :currency, "Currency", class: "c-field__label"`, a bare `form.select :currency, currency_options` as the lot form's finish select is (no `c-input` wrapper there; copy that markup), `aria-describedby` from `field_error_describedby("account_currency-error", @messages || [])`, `render "shared/field_errors", messages: @messages || [], id: "account_currency-error"`; Save and Cancel (to `more_path`); the tab bar with `section: nil`.
- `app/views/mores/show.html.erb`: `<li><%= link_to "Currency", edit_currency_path %></li>` after Locations. `app/views/layouts/_appbar.html.erb`: `<%= link_to "Currency", edit_currency_path, class: "c-menu__item" %>` after Import collection.
- No new pattern doc under `docs/design-system/components/` (no new CSS); `verification.md` says so.

**Commits:** `feat(currency): add the Currency page`, `feat(currency): link the Currency page from More and the account menu`.

## Phase 4: The upgrade seed, a backup example and the documents (spec Stories 4 and 7; Documents that change)

**Tests and checks first**

- `script/upgrade/seeds/next.rb`: after `grace = User.create!(...)` add `grace.account.update!(currency: "EUR")` and say so in the comment (AC-4.7); it runs on the code under test, which has the column. `git grep -n accounts script/upgrade/seed_exceptions.yml`: add an entry only if the harness's coverage check fails without one. AC-4.6 is proved by CI's `bin/upgrade-smoke`; `spec/backup_upgrade_spec.rb` rolls back only `STEP=1`, which is now the empty data step, so whether it still proves the schema step reversible is something only a run confirms (the migration spec of phase 1 does prove it); if it is vacuous for the column, record it in `verification.md` for the maintainer, with no change to that spec.
- AC-7.1: in `spec/backup_restored_instance_spec.rb` (read it first; add to the example that round-trips accounts, else a new `:backup, :committed` example modelled on it): two accounts in USD and EUR restore with their own currencies.

**Documents** (each statement with its source inline; `.claude/rules/documentation.md`)

- `docs/architecture/collection-and-lots.md`: line 65 (price paid is shown in the account's currency, `accounts.currency`, `Account#currency_unit`; changing converts nothing; the Currency page); the constants row at line 187 (`COLLECTOR_CURRENCY` is the default a new account starts with); the #64 source line 223 and Sources; a Changes row.
- `docs/architecture/data-portability.md`: line 66 (the export's `currency`); refusal row 8 becomes `unsupported_currency`; the preview's Profile line, the plan, the fingerprint and the notice; lines 191 and 215 (the #64 statements); any sentence that says an empty example is "nothing to change" in its own currency; Sources add spec 038; a Changes row.
- `docs/north-star.md:40` and `docs/roadmap.md:144` (decision 17: "Only currency"): the breach closed by spec 038; roadmap line 78's #64 bullet marked built.
- `README.md` lines 162, 166 and 376, `compose.yaml` (lines 9 and 25), `config/deploy.yml` (lines 63-64), and `docs/backup-restore.md` if it repeats the symbol sentence: the variable is the currency a new account starts with; collectors change theirs from More → Currency; changing the variable later changes no existing account; changing a currency converts nothing.
- `docs/specs/README.md`: the 038 row's Status (Approved at this plan's approval; Shipped at merge) and the Superseded-by cells of 004, 006, 017, 022, 025, 028, 030 and 032 naming 038 (both directions; the shipped specs are not edited). `docs/specs/038-currency-per-account/verification.md`: each AC with its evidence, the review's "only a run could confirm" lists, and the `## Implementation review` heading when that review runs.
- `CLAUDE.md` names no currency text, so it does not change.

**Verification at the end:** `bin/rspec` on each phase's files as it lands; `bin/ci` once at the end of the branch (pushed in the background, memory: *Push in background*); `bin/rails zeitwerk:check`; `bin/brakeman`; `ruby script/upgrade/guard.rb` (the migrations are additions).

**Commits:** `test(upgrade): seed a non-default currency`, `test(backup): a restore keeps each account's currency`, `docs(currency): area docs, README and the format document`, `docs(specs): record spec 038's supersessions in the index`.

## What only a run can confirm

- That a Hash `ENV` stub reaches `ENV.fetch` inside the data migration and nothing else in the example breaks on it.
- That `schema.rb` dumps `t.string "currency", default: "USD", null: false`, and that the down step's table copy passes with foreign keys on.
- That the `x.default_currency` stub works on `Rails.configuration.x` (the old `:currency` stub did).
- That an account rolled back after a failed `update!` is reloaded correctly in AC-6.9's example, and that the stale page renders "EUR instead of GBP".
- That a plan without a currency change keeps its old fingerprint.
- That `spec/backup_upgrade_spec.rb` and `bin/upgrade-smoke` stay green; Brakeman and RuboCop on the new files.

## Deviations and risks

- The empty valid examples carry EUR, so for a default-USD account they now plan a currency change (spec decision 7); the specs that said "nothing to change in its own currency" change as phase 2b lists. The format document's examples are not touched.
- Stored import uploads at deploy keep valid fingerprints when the account's currency equals the file's (the common case); one whose currency differs shows as stale and is previewed again. Accepted.
