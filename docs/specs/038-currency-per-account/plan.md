# Plan: Spec 038, Store Currency per Account

**Spec:** [spec.md](spec.md) 0.2.0 (approved 2026-11-03)
**ADR:** none. The maintainer chose no version change without an ADR (decision 6); ADR 0026 stays unused.

Six phases, each tests first (red, then green), each ending in a passing `bin/rspec` of the files it touched and one Conventional Commit per step. Code blocks are strong drafts, not pre-run: where a run disagrees, the deviation is recorded as a ruling in the commit body. Phases 1 and 2 must land before 3 to 5; 3, 4 and 5 touch different files and are independent of each other; 6 is last.

Order of files touched, so a parallel worker can be told what overlaps: phases 1–2 `config/`, `db/`, `app/models/account.rb`, helpers, the lot form; phase 3 `config/routes.rb`, a new controller and views, two nav files; phase 4 `app/models/collection_export.rb` and the format document; phase 5 `app/models/collection_import*`, `app/controllers/collections/imports_controller.rb`, the preview view and helper; phase 6 documents and the upgrade seed.

## Phase 1: The column, the model and the default (spec FR-1, FR-3; AC-3.x, AC-4.x)

**Tests first**

1. `spec/migrations/add_currency_to_accounts_spec.rb` and `spec/migrations/set_account_currency_from_the_instance_spec.rb`, modelled on `spec/migrations/add_location_to_lots_spec.rb` (`:backup, :committed`, the Migrator, no application model):
   - schema step: down then up leaves every other column and row; the column is `NOT NULL` with default `USD` (`ActiveRecord::Base.connection.columns("accounts")`); existing rows read `USD` (AC-4.1's precondition);
   - data step with `ENV` stubbed (`stub_const("ENV", ENV.to_h.merge("COLLECTOR_CURRENCY" => "eur"))`; `allow(ENV).to receive(:fetch)` is the alternative if the first doesn't reach the migration): three accounts all become `EUR`; unset gives `USD`; ` eur ` gives `EUR`; `XYZ` raises naming `COLLECTOR_CURRENCY` and `"XYZ"` and leaves the accounts as they were (AC-4.1–4.3); a database with no account passes (AC-4.4); `down` changes no account (AC-4.5). These examples answer "does the migration run with the `up` guard"; they run the migration object directly (the boot check refuses first through `db:prepare`, plan review m2).
2. `spec/models/account_spec.rb` gains: `Account.new.currency` is the default's code, and follows a stubbed `Rails.configuration.x.default_currency` (`allow(Rails.configuration.x).to receive(:default_currency).and_return(Collector::Currency.fetch!("EUR"))`, the way the old specs stubbed `:currency`); an account with `XYZ`, `eur` or blank is invalid; `currency_unit` answers the `Unit` (AC-3.1, AC-3.2, FR-1).
3. `spec/models/user_spec.rb` (or a new `spec/models/user/command_spec.rb` if there is none): a user created through `create(:user)`, through `User::Command.call` and through `Registration` gets the stubbed default (AC-3.1). Admin creation goes through `User.new(...).save`, the same `build_account`, so one request example in phase 3's `spec/requests/admin/users_spec.rb` covers it.
4. `spec/lib/collector/currency_spec.rb` line 14 becomes `Rails.configuration.x.default_currency` (AC-3.2); its boot-error example stays (AC-3.4); add a `strip.upcase` example for ` eur ` (AC-3.5).

**Code**

- `db/migrate/20261103100001_add_currency_to_accounts.rb` (schema step). `accounts` is pointed at by many foreign keys, so, as `AddLocationToLots` does, the ADD COLUMN is raw SQL (no table copy), guarded, with no DDL transaction:

  ```ruby
  # Gives every account the currency its prices are shown in (spec 038 decision 1). The next migration carries the
  # instance's current currency to it; this step's default is USD on every instance, so schema.rb is the same everywhere.
  class AddCurrencyToAccounts < ActiveRecord::Migration[8.1]
    disable_ddl_transaction!

    def up
      execute "ALTER TABLE accounts ADD COLUMN currency varchar NOT NULL DEFAULT 'USD'" unless column_exists?(:accounts, :currency)
    end

    def down
      remove_column :accounts, :currency if column_exists?(:accounts, :currency)
    end
  end
  ```

  If a run shows `remove_column` copies the table and trips a foreign key (the lots migration's comment), the down step takes the same care that migration does; record the ruling.

- `db/migrate/20261103100002_set_account_currency_from_the_instance.rb` (data step):

  ```ruby
  # Carries the instance's current currency to every account, so an upgrade changes nothing a collector sees (spec 038
  # decision 3). The codes are copied inline: a released migration must not change when Collector::Currency does.
  class SetAccountCurrencyFromTheInstance < ActiveRecord::Migration[8.1]
    CODES = %w[USD CAD AUD NZD EUR GBP CHF SEK NOK DKK PLN CZK JPY CNY KRW SGD HKD BRL MXN ZAR].freeze

    def up
      code = ENV.fetch("COLLECTOR_CURRENCY", "USD").strip.upcase
      raise "COLLECTOR_CURRENCY #{ENV["COLLECTOR_CURRENCY"].inspect} is not supported; use one of #{CODES.join(", ")}" unless CODES.include?(code)

      execute "UPDATE accounts SET currency = #{connection.quote(code)}"
    end

    def down
    end
  end
  ```

- `db/schema.rb`: run `bin/rails db:migrate`, then restore the cable, cache and queue schema noise and keep the version line (memory: *Migrate schema noise*). `accounts` gains `t.string "currency", default: "USD", null: false`.
- `config/initializers/currency.rb`: `Rails.configuration.x.default_currency = Collector::Currency.fetch!(ENV.fetch("COLLECTOR_CURRENCY", "USD"))`; the comment now says "the currency a new account starts with (spec 038 decision 2)". `lib/collector/currency.rb`'s header comment names the account, not the instance (the module is unchanged otherwise).
- `app/models/account.rb`:

  ```ruby
  attribute :currency, :string, default: -> { Rails.configuration.x.default_currency.code }
  validates :currency, inclusion: { in: Collector::Currency::SYMBOLS.keys, message: "Choose one of the listed currencies." }

  # What a price of this account is shown with: the code and the symbol (spec 038 decision 1).
  def currency_unit = Collector::Currency.fetch!(currency)
  ```

  The validation message is a whole sentence, which `lot_error_messages`' rule (capitalised messages show as written) already treats as such; the Currency page reads `errors.messages_for(:currency)` directly.

**Commits:** `feat(accounts): add currency to accounts`, `feat(accounts): carry the instance currency to every account`, `feat(accounts): start a new account in the instance's default currency`.

## Phase 2: Show prices in the account's currency (spec FR-4; AC-1.3 to AC-1.5)

**Tests first**

1. `spec/helpers/lots_helper_spec.rb` (new; `Current.session`-free: set `Current.user` as `spec/helpers/application_helper_spec.rb` does, read it first): `lot_price` writes `$12.50` for a USD account and `€12.50` after the account's currency is `EUR`; `lot_price` of an unpriced lot is `—`; `lot_line` of a priced lot ends in `€12.50` (the Move copies and refusal pages use it).
2. Request specs: the card page's Your copies table and the collection table write `€12.50` for an EUR account (find the existing examples that assert `$12.50`, such as in `spec/requests/collection_spec.rb`, `spec/requests/catalog/entries_spec.rb`; add an `eur` context or a second example), the grid shows no `€` or `$`, the Move copies page (`spec/requests/lots/moves_spec.rb`) and the location removal refusal page (`spec/requests/locations_spec.rb`, the refusal examples) write `€12.50`. The lot form's label reads `Price paid per copy (EUR)` and its prefix `€` (`spec/requests/lots_spec.rb`).
3. `spec/currency_reads_spec.rb` (the guard, decision 2; a source check, not a prose check, like `spec/footer_core_spec.rb`): `git grep`-free, using `Dir.glob` over `app/`, `lib/` and `config/`, fail on any `x.currency` read, and on `x.default_currency` outside `app/models/account.rb` and `config/initializers/currency.rb`:

   ```ruby
   require "rails_helper"

   # Spec 038 decision 2: no price code reads the instance default. A renamed key would answer empty options (a nil symbol,
   # so `$`), so the reads are removed and checked here instead.
   RSpec.describe "Reads of the instance currency" do
     let(:files) { Dir.glob(Rails.root.join("{app,lib,config}/**/*.{rb,erb}")).map { |path| Pathname(path).relative_path_from(Rails.root).to_s } }
     let(:allowed) { %w[app/models/account.rb config/initializers/currency.rb] }

     it "are left to Account and the initializer", :aggregate_failures do
       offenders = files.reject { |file| allowed.include?(file) }.select { |file| Rails.root.join(file).read.match?(/x\.(default_)?currency\b/) }
       expect(offenders).to be_empty
       expect(Rails.root.join("app/models/account.rb").read).to include("default_currency")
     end
   end
   ```

**Code**

- `app/helpers/lots_helper.rb:22`: `unit: Current.account.currency_unit.symbol`.
- `app/views/lots/_form.html.erb:26-27`: `Current.account.currency_unit.code` and `.symbol`.
- `app/helpers/import_previews_helper.rb:8-9`: `import_lot_line` gains a required `currency:` keyword (a `Collector::Currency::Unit` or nil: a file's code that is not one of the 20 can't reach here, because it is refused) and uses `currency.symbol` for a price in the format's form; `ImportPreviewsHelper` callers in `collections/import_previews/show.html.erb` lines 47 and 71 pass `currency: Current.account.currency_unit` for removed lots and `currency: Collector::Currency.fetch!(@import.currency)` for problem rows (decision 8). The line-47 lot is held, so the account's current; line 71's row is the file's. (Phase 5 finishes the preview; this step only keeps `bin/rspec` green after the helper change, so make the two calls in this phase.)
- No other file reads the old key (`git grep -n 'x\.currency' -- app lib config`), so the guard passes once the three call sites change. `app/models/collection_export.rb:24` and `app/models/collection_import.rb:207` change in phases 4 and 5; until then this phase's guard example is written but excluded from the run with the two files listed in a TEMPORARY allowance that phase 5 deletes (commit message says so). Alternatively land phases 2, 4 and 5's one-line read changes together; the worker decides, and records which.

**Commits:** `refactor(prices): show a price in the signed-in account's currency`, `test(prices): fail on a read of the instance currency`.

## Phase 3: The Currency page (spec decisions 4–5, FR-2; AC-1.1, AC-1.2, AC-1.6–AC-1.8, AC-2.x)

Read `docs/design-system/README.md` and the `collector-design-system` skill before the views (CLAUDE.md). The page copies the Rename location page's markup (`app/views/locations/edit.html.erb`): `c-pagehead`, `c-form`, `c-field`, `shared/field_errors`.

**Tests first**: `spec/requests/currencies_spec.rb`, `type: :request`, modelled on `spec/requests/locations_spec.rb`:

- signed out: `get edit_currency_path` and `patch currency_path` redirect to sign-in and write nothing (AC-1.8);
- `get edit_currency_path`: one select `account[currency]` with the 20 options in `Collector::Currency::SYMBOLS` order, each text `"EUR — €"` (symbol stripped; `CHF — CHF`, `SEK — kr` accepted), the account's own selected, a Save button; the sentence "Changing the currency doesn't convert…"; with 3 priced and 2 unpriced lots "3 lots have a price paid."; with one "1 lot has a price paid."; with none no count sentence (AC-1.2, AC-1.6);
- `patch currency_path, params: { account: { currency: "EUR" } }` redirects (303) to `more_path` with notice "Prices are now shown in EUR.", `account.reload.currency == "EUR"`, every lot's `price_paid_cents` and `lot_key` unchanged (AC-1.3, AC-1.5);
- each of `XYZ`, `eur`, `""`, `"EUR "` answers 422, shows the error "Choose one of the listed currencies." in `#account_currency-error`, shows the account's own code selected, and leaves the column (AC-1.7); a request without `account` answers 400;
- tenancy: two users; one changes to EUR; the other's currency and the other's pages still `$` (AC-2.1); a request with `account: { currency: "EUR", id: other.account.id }` or `account_id:` changes only the signed-in account (AC-2.2);
- `spec/requests/mores_spec.rb` (existing) and an appbar example: More lists "Currency" linking to `/currency/edit`, and the account menu has "Currency" before the separator (AC-1.1; find the existing example that asserts the menu's items and extend it);
- `spec/requests/admin/users_spec.rb`: the users page lists no currency; `post admin_users_path, params: { user: { name:, email_address:, password:, currency: "EUR" } }` creates an account at the default (AC-2.3, AC-3.1).
- `spec/routing/currency_routing_spec.rb`: `edit` and `update` only.

**Code**

- `config/routes.rb`, next to `resource :more`: `resource :currency, only: %i[edit update]`.
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
        @priced = priced_lots
        render :edit, status: :unprocessable_content
      end
    end

    private
      # One COUNT for the page's second sentence (spec 038 decision 5).
      def priced_lots = @account.lots.where.not(price_paid_cents: nil).count
  end
  ```

  On a failed update the select must show the persisted code: the view reads `@account.currency_in_database`.
- `app/helpers/currencies_helper.rb`: `currency_options` = `Collector::Currency::SYMBOLS.map { |code, symbol| [ "#{code} — #{symbol.strip}", code ] }`.
- `app/views/currencies/edit.html.erb` (the Rename location page's shape): title "Currency · Collector"; `layouts/appbar` with `detail: true, back_path: more_path`; heading "Currency"; the two sentences (the count sentence only when `@priced.positive?`, with `pluralize`-style "lot has"/"lots have"); a `form_with model: @account, url: currency_path, method: :patch` holding a `c-field` with `form.label :currency, "Currency"`, `form.select :currency, currency_options, { selected: @account.currency_in_database }` inside `c-input` (use the markup of the lot form's finish select; copy it, don't invent a class), `aria-describedby` from `field_error_describedby("account_currency-error", messages)`, `shared/field_errors` with that id; Save and Cancel (Cancel to `more_path`). The tab bar partial as the other pages (`section: nil`).
- `app/views/mores/show.html.erb`: `<li><%= link_to "Currency", edit_currency_path %></li>` after Locations. `app/views/layouts/_appbar.html.erb`: `<%= link_to "Currency", edit_currency_path, class: "c-menu__item" %>` before Export collection.
- `docs/design-system/` needs no new pattern doc (no new CSS); say so in `verification.md`.

**Commits:** `feat(currency): add the Currency page`, `feat(currency): link the Currency page from More and the account menu`.

## Phase 4: The export carries the account's currency (spec decision 6, FR-5; AC-5.x)

**Tests first**

- `spec/models/collection_export_spec.rb:44`: `"currency" => account.currency` and an example with an EUR account writing `EUR` and `format_version` 3; two accounts in different currencies each export their own (AC-5.1, AC-5.2).
- `spec/export_format_document_spec.rb:77`: `"accounts" => "Exported"` (AC-5.4); no other expectation changes. Run it first and see it red: the Coverage guard also fails until the column table has the row (AC-3.4's "every column of a table that isn't left out whole").
- `spec/models/export_format/rules_spec.rb`, `spec/export_format_examples_spec.rb`: unchanged and still green, which is AC-5.3's proof (versions `[1, 2, 3]`, schemas and examples untouched). Add one example to `spec/export_format_document_spec.rb` or `spec/models/collection_export_spec.rb`: `ExportFormat::Rules::VERSIONS` is `[1, 2, 3]` and `CollectionExport::FORMAT_VERSION` is 3.

**Code**

- `app/models/collection_export.rb:24`: `"currency" => @account.currency`. Header comment unchanged otherwise.
- `docs/export-format/README.md` (the format's document): Currency section's "The code is the currency in force for the collector…" paragraph says it is the collector's account's currency and the version didn't change; Versions section's "Two changes are already expected" sentence loses #64 (the household sentence stays); Coverage: `accounts` row "Exported", why "Its `currency`; the other columns are left out"; the column table gains `| accounts.currency | currency | |`; the line "`currency` comes from no table yet…" becomes "`currency` is `accounts.currency`." The schemas, `examples/` and `**Format version:** 3` are not touched.

**Commits:** `feat(export): write the account's currency`, `docs(export-format): the currency is the account's, version unchanged`.

## Phase 5: An import brings its currency in (spec decision 7, FR-6; AC-6.x)

**Tests first** (all in the existing files; rewrite the ones decision 3 made, add the new)

- `spec/models/collection_import_spec.rb:95-96` ("refuses a file in another currency"): becomes "reads a file in another supported currency, even with no lots" (not refused, `plan.currency_change` is `from: "USD", to: "EUR"`), plus "refuses a well-formed unsupported code": `file([], currency: "XYZ")` refuses `[ "unsupported_currency", "/currency", "Collector can't show prices in XYZ." ]`; `currency: "usd"` still a schema refusal as line 87 has it (AC-6.6). A file in the account's own currency has `currency_change` nil (AC-6.1).
- `spec/models/collection_import/plan_spec.rb` (or where `Plan` is specced; `git grep -n 'Plan.new\|nothing_to_change' spec`): `nothing_to_change?` is false when only the currency differs and true when nothing does (AC-6.4, AC-6.5); the fingerprint differs between a plan with `currency_change` and without, and between `EUR instead of USD` and `EUR instead of GBP`, and is unchanged for a plan without one (stored fingerprints don't all go stale on deploy).
- `spec/models/collection_import/apply_spec.rb`: applying a EUR file to a USD account sets `EUR` in the same transaction as the lots (AC-6.3); an apply that fails (stub `CollectionImport::LocationChanges.write!` to raise, the way the existing rollback example does) leaves the currency (AC-6.9); the account's currency changed to GBP after the preview makes the apply `:stale` and the new plan says `EUR instead of GBP` (AC-6.7); the account changed to the file's own code with nothing else different answers `:nothing_to_change` (decision 7); a currency-only file applies and changes only the currency (AC-6.5).
- `spec/requests/collection_import_previews_spec.rb`: line 282's refusal list: replace the EUR row with `file([], currency: "XYZ") => "Collector can't show prices in XYZ."`; lines 429-450 (the empty examples "in its own currency"): the `x.currency` stubs go; assert the empty example in EUR (`empty.json`, `empty-v2.json`, `valid/empty-v3.json`) is previewed, not refused, can be applied, says "Your prices would be shown in EUR instead of USD. Nothing is converted." and offers the apply (it is no longer "nothing to change"); add the same example with the account at EUR (`user.account.update!(currency: "EUR")`): "nothing to change", no apply (AC-6.1, AC-6.2, AC-6.4); the removed-lot line is in the account's currency and a problem row's in the file's (AC-6.8).
- `spec/requests/collection_imports_spec.rb` (the apply request; find its name with `ls spec/requests | grep import`): the notice for a currency-only apply is "Imported: 0 lots added, 0 changed, 0 removed; prices now shown in EUR" (AC-6.3), and a lots-and-currency apply appends it after the locations part.
- `spec/models/collection_import/round_trip_spec.rb:145`: the stub goes; the example creates the account at its default and applies; for a file with no lots and no locations the expectation is "nothing to change" if its currency equals the account's, and otherwise a plan that has only a currency change which applies and exports the same collection including `currency` (AC-6.10); every other example applies and exports the same collection. Version 1, 2 and 3 files are all in the loop (AC-6.11).
- `spec/support/import_helpers.rb:20`, `spec/requests/collection_import_previews_spec.rb:21`, `spec/models/collection_import_spec.rb:25` and `spec/system/collection_import_preview_spec.rb:32` build files with `"currency" => "USD"`: unchanged.

**Code**

- `app/models/collection_import.rb`: replace `currency_refusal`:

  ```ruby
  # A well-formed code this instance can't show is refused as a whole (spec 038 decision 7); any of the 20 is brought in.
  def currency_refusal
    code = @data["currency"]
    return if Collector::Currency::SYMBOLS.key?(code)

    refuse("unsupported_currency", "/currency", "Collector can't show prices in #{code}.")
  end
  ```

  Add `CurrencyChange = Data.define(:from, :to)` and
  `def currency_change = (CurrencyChange.new(from: @account.currency, to: currency) if currency != @account.currency)`; `plan` and `replan` build `Plan.new(outcomes, view_change, locations, currency_change)`; `replan` starts with `@account.reload` (before `user.reload`), so the account's currency is read afresh inside the apply's transaction (plan review m4 of the spec's review).
- `app/models/collection_import/plan.rb`: take `currency_change`, `attr_reader` it; `nothing_to_change?` adds `&& currency_change.nil?`; the fingerprint appends `parts << [ currency_change.from, currency_change.to ] if currency_change` after the locations part (so a plan without a change has the fingerprint it had).
- `app/models/collection_import/apply.rb` `write!`: after `@account.user.update!(collection_view: …)` add `@account.update!(currency: plan.currency_change.to) if plan.currency_change` (inside the transaction; it validates, as the code is one of the 20). The header comment of `Apply` and `Plan` mention it.
- `app/controllers/collections/imports_controller.rb` `notice_for`: build the parts as `[ lots, location_sentence(plan.locations), (“prices now shown in #{plan.currency_change.to}” if plan.currency_change) ].compact.join("; ")`.
- `app/views/collections/import_previews/show.html.erb`: the Profile section's condition gains `|| @import.currency_change`, with `<li>Your prices would be shown in <%= @import.currency_change.to %> instead of <%= @import.currency_change.from %>. Nothing is converted.</li>` first in the list. The header line keeps showing the file's code. (This is a stateless read; the view reads no query.)
- The stale page: `preview(result, "The collection or the file changed since you looked. This is what applying would do now.", :conflict)` renders the same view from the replanned plan, so "EUR instead of GBP" appears without more code; confirm in the example above.

**Commits:** `feat(import): refuse a currency the instance can't show`, `feat(import): plan a currency change`, `feat(import): apply the file's currency and say so in the notice`, `test(import): the examples apply whatever currency they carry`.

## Phase 6: The upgrade seed, the documents and the verification (spec Story 4, 7; Documents that change)

**Tests and checks first**

- `script/upgrade/seeds/next.rb`: after `grace = User.create!(...)` add `grace.account.update!(currency: "EUR")` and name it in the comment (AC-4.7). It runs on the code under test, which has the column. Check `script/upgrade/seed_exceptions.yml` lists no `accounts` entry that the new column needs (`git grep -n accounts script/upgrade/seed_exceptions.yml`); add one only if the harness's coverage check fails on it. `spec/script/` and `spec/backup_upgrade_spec.rb` stay green: the latter rolls back only `STEP=1`, so it rolls back the data step; whether it still proves the schema step reversible is something only a run confirms (spec 038 review), and if it is now vacuous for the column, record that as a finding for the maintainer, not a change to that spec.
- `spec/backup_restored_instance_spec.rb` (or the closest backup request example): a backup of two accounts in different currencies restores to the same two currencies (AC-7.1); add it to the example that already round-trips accounts if one exists, else a new `:backup, :committed` example modelled on it.

**Documents** (each states its source inline; `.claude/rules/documentation.md`)

- `docs/architecture/collection-and-lots.md`: line 65 (price paid shown in the account's currency, `accounts.currency`, `Account#currency_unit`; any other code is refused; changing converts nothing; the Currency page); the `COLLECTOR_CURRENCY` row of its constants table (line 187) now "the default a new account starts with"; the Known limits/Sources line 223 and Sources add spec 038; a Changes row.
- `docs/architecture/data-portability.md`: the export's `currency` source (line 66); refusal table row 8 becomes `unsupported_currency` with its reason; the Profile notes, plan, fingerprint and notice parts (line 154 and the preview-page list); "Decisions not in an ADR" line 191 and Sources line 215 rewritten; Sources add spec 038; a Changes row. The empty examples are no longer "nothing to change" for a USD account: update any sentence that says so.
- `docs/north-star.md:40`: the breach sentence becomes "Currency was a collector's choice stored as an instance setting (spec 004); spec 038 stores it per account, and the setting is only the default a new account starts with."
- `docs/backup-restore.md` (only if it repeats the symbol sentence), `README.md` lines 162, 166 and 376, `compose.yaml` line 9 and 25's comment, `config/deploy.yml` lines 63-64: the variable is "the currency a new account starts with"; collectors change theirs from More → Currency; changing the variable later changes no existing account; changing the currency converts nothing.
- `docs/specs/README.md`: the 038 row's Status (Approved at the plan's approval, Shipped at merge, the distil step then Freezes it); the Superseded-by cells of 004, 006, 017, 022, 025, 028, 030, 032 name 038 (both directions, `.claude/rules/documentation.md`; the shipped specs themselves are not edited). `docs/roadmap.md`: line 78's #64 bullet marked built. `docs/specs/038-currency-per-account/verification.md`: each AC with its evidence, the review's "only a run could confirm" list, and the `## Implementation review` heading when the review runs.
- No `CLAUDE.md` text names the currency, so it does not change (spec review m7).

**Verification at the end:** `bin/rspec` on the phase files as each lands; then `bin/ci` once at the end of the branch (push in the background, memory: *Push in background*); `bin/rails zeitwerk:check`; `bin/brakeman`; `ruby script/upgrade/guard.rb` (the new migrations are additions, so it passes); and, on a machine with a container engine, `bin/upgrade-smoke auto <image>` is CI's job here.

**Commits:** `test(upgrade): seed a non-default currency`, `docs(currency): area docs, README and the format document`, `docs(specs): record spec 038's supersessions in the index`.

## What only a run can confirm

- The `ENV` stub reaches the migration object, and the `ALTER TABLE` and its `down` run without copying `accounts` (foreign keys).
- `schema.rb` dumps `default: "USD", null: false` on every machine.
- The `x.default_currency` stub works with `Rails.configuration.x` (it did for `:currency`).
- Each moved example's old assertion (`$`) is found by the grep in phase 2; one may live in a system spec.
- The stale page renders "EUR instead of GBP", and a `Plan` without a currency change fingerprints as before.
- `spec/backup_upgrade_spec.rb` and `bin/upgrade-smoke` stay green; Brakeman stays clean on the new controller; no RuboCop offence in the new files.

## Deviations and risks

- Phase 2's guard spec and phases 4 and 5's one-line reads depend on each other; the worker chooses the order and records it.
- The empty valid examples carry EUR, so for a default-USD account they now plan a currency change (spec decision 7); the specs that said "nothing to change in its own currency" change as phase 5 lists, and the format's own document isn't touched by this (the examples are unchanged).
- Stored import uploads at deploy: their fingerprints are for plans without a currency part and stay valid when the account's currency equals the file's (the common case); one whose currency differs shows as stale and is re-previewed. Accepted.
