# Plan 022: Export a Collection as a File

**Spec:** [spec.md](spec.md) (1.2.0, approved with changes 2026-10-14) · **Issue:** [#38](https://github.com/plainprogrammer/Collector/issues/38) · **Branch:** `022-export-collection`
**Status:** Draft, for the maintainer's approval (through a read-only Opus plan review that ran the code; its findings are applied, then updated for spec 1.2.0)
**Rulings (maintainer, 2026-10-14):** decision 1, in the request with no job (bar: 10 s or 300 MB at 50,000 lots); decision 6, the account menu plus a row on More.

## Global Constraints

- Format version 1, its schema, examples and Coverage tables are not edited. The writer's output is checked with `ExportFormatRules` (`spec/support/export_format_rules.rb`, test only).
- The writer is collectible-agnostic: it reads core columns only and never asks the catalog registry about a type.
- Tenant data is reached only through `Current.account` and its associations.
- TDD: each phase writes its failing examples first, runs them red, then the code, then green. One Conventional Commit per step, `git add` separate from `git commit`, each ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- UI follows `collector-design-system`: existing `c-menu__item` and `c-list` only, no new CSS.
- Measured in scratch before planning (prototype of Phase 1's writer, test env): 50,000 lots → 1.28 s, a 16.0 MB file, process RSS +68 MB.

## Goal

A signed-in collector downloads `collector-export-YYYY-MM-DD.json` from the account menu or More: their profile, the instance currency and every lot of their account, a well-formed format-v1 file, read in one consistent statement, with no job and nothing stored.

## Phase 0: Branch state

Branch `022-export-collection` on `origin/main` 7bf56d7; `bin/setup --skip-server` has run (OCR engine present). Spec commits `031fbba`, `bc1e173`.

## Phase 1: The writer

**Implements:** FR-1, FR-2, FR-3, FR-6, decisions 4, 5, 7, 8 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-2.1 (model half), AC-2.2, AC-2.3
**Files:** `spec/models/collection_export_spec.rb` (new), `spec/collection_export_core_spec.rb` (new), `.rubocop.yml` (`RSpec/DescribeClass` exclude gains `spec/collection_export_core_spec.rb`, beside the other `*_core_spec.rb`), `app/models/collection_export.rb` (new), `spec/support/export_format_rules.rb` (comment only)
**Interfaces:** `CollectionExport.new(account:, at:)`, `#to_h` → Hash with string keys, `#to_json` → String, `#filename` → `"collector-export-YYYY-MM-DD.json"`

### Step 1.1: Failing model examples

`spec/models/collection_export_spec.rb`:

```ruby
require "rails_helper"

# Spec 022: the collection export writes one account's collection as a format-v1 file (docs/export-format/README.md).
RSpec.describe CollectionExport, type: :model do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }
  let(:account) { user.account }
  let(:at) { Time.utc(2026, 10, 14, 12, 34, 56.789r) }
  let(:export) { described_class.new(account:, at:) }

  def printing(**attributes) = create(:mtg_printing, entry: create(:catalog_entry, **attributes)).entry

  def parsed = JSON.parse(export.to_json)

  # Every shape a lot can take (AC-1.2).
  def fixture_collection
    serra = printing(name: "Serra Angel", external_key: "00000000-0000-4000-8000-000000000001", number: "27",
      set: create(:catalog_set, code: "dmr"))
    bolt_ja = printing(name: "Lightning Bolt", localized_name: "稲妻", language: "ja")
    retired = create(:catalog_entry, :retired)
    comic = create(:catalog_entry, collectible_type: "comics") # unregistered: its lot can carry no finish or condition
    token = create(:catalog_entry, kind: "token")
    [
      create(:lot, account:, entry: serra, quantity: 4, finish: "foil", condition: "near_mint", price_paid_cents: 1250),
      create(:lot, account:, entry: serra, finish: nil, condition: nil, price_paid_cents: nil),
      create(:lot, account:, entry: serra, finish: "nonfoil", condition: "damaged", price_paid_cents: 0),
      create(:lot, account:, entry: bolt_ja, quantity: Lot::MAX_QUANTITY, price_paid_cents: 100_005),
      create(:lot, account:, entry: retired),
      create(:lot, account:, entry: comic),
      create(:lot, account:, entry: token)
    ]
  end

  it "writes a well-formed file of every shape a lot can take" do
    fixture_collection

    expect(ExportFormatRules.problems(export.to_json)).to eq([])
  end

  it "writes the header, the profile and the currency", :aggregate_failures do
    file = parsed
    expect(file.except("lots")).to eq(
      "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-14T12:34:56Z",
      "profile" => { "name" => "Grace Example", "email_address" => "grace@example.test", "collection_view" => "grid" },
      "currency" => Rails.configuration.x.currency.code)
    expect(file).not_to have_key("generator")
  end

  it "writes an empty collection as an empty list of lots", :aggregate_failures do
    expect(parsed["lots"]).to eq([])
    expect(ExportFormatRules.problems(export.to_json)).to eq([])
  end

  it "writes each lot's seven fields from the lot, its entry and its set" do
    travel_to(Time.utc(2026, 9, 30, 18, 2, 11.999r), with_usec: true) { fixture_collection }
    lot = account.lots.find_by!(price_paid_cents: 1250)
    lot.update!(quantity: 5, updated_at: Time.utc(2026, 10, 2, 9, 15, 0.5r))

    expect(parsed["lots"]).to include(
      "entry" => { "collectible_type" => "mtg", "source_id" => "00000000-0000-4000-8000-000000000001", "name" => "Serra Angel",
                   "set_code" => "dmr", "collector_number" => "27", "language" => "en" },
      "quantity" => 5, "finish" => "foil", "condition" => "near_mint", "price_paid" => "12.50",
      "added_at" => "2026-09-30T18:02:11Z", "changed_at" => "2026-10-02T09:15:00Z")
  end

  it "writes one lot per lot row, with nulls, free copies, exact prices and the catalog's name", :aggregate_failures do
    lots = fixture_collection
    written = parsed["lots"]

    expect(written.size).to eq(lots.size)
    expect(written.map { |lot| lot.values_at("finish", "condition", "price_paid") }).to include(
      [ nil, nil, nil ], [ "nonfoil", "damaged", "0.00" ], [ nil, nil, "1000.05" ])
    expect(written.find { |lot| lot["entry"]["language"] == "ja" }).to include(
      "quantity" => Lot::MAX_QUANTITY, "entry" => a_hash_including("name" => "Lightning Bolt"))
    expect(written.map { |lot| lot["entry"]["collectible_type"] }).to include("comics")
  end

  it "writes the same file twice for an unchanged collection, apart from exported_at", :aggregate_failures do
    fixture_collection
    later = described_class.new(account:, at: at + 1.hour)

    expect(JSON.parse(later.to_json).except("exported_at")).to eq(parsed.except("exported_at"))
    expect(ExportFormatRules.same_collection?(parsed, JSON.parse(later.to_json))).to be(true)
  end

  it "writes only this account's profile and lots", :aggregate_failures do
    shared = printing
    mine = create(:lot, account:, entry: shared, quantity: 2)
    other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
    create(:lot, account: other.account, entry: shared, quantity: 8_888, price_paid_cents: 77_777)

    expect(parsed["lots"].map { |lot| [ lot["entry"]["source_id"], lot["quantity"] ] }).to eq([ [ mine.entry.external_key, 2 ] ])
    expect(parsed["lots"].map { |lot| lot.values_at("quantity", "price_paid") }.flatten).not_to include(8_888, "777.77")
    expect(export.to_json).not_to include("Zebulon Otherperson", "zebulon.otherperson@example.test")
  end

  it "writes the lots a scanner sitting added, and nothing of the sitting", :aggregate_failures do
    entry = printing
    added = Scanner::Sitting.add!(account:, printing: entry, finish: "foil", reading_key: "a" * 32)

    expect(parsed["lots"].map { |lot| [ lot["entry"]["source_id"], lot["finish"] ] }).to eq([ [ entry.external_key, "foil" ] ])
    expect(export.to_json).not_to include("a" * 32, "sitting")
    expect(added.replayed).to be(false)
  end

  it "writes exactly the fields the format defines" do
    fixture_collection

    reference = JSON.parse(ExportFormatRules.directory.join("examples/valid/collection.json").read)

    expect(ExportFormatRules.field_names(parsed)).to match_array(ExportFormatRules.field_names(reference) - [ "generator" ])
  end

  it "reads the lots in one statement, whatever their number", :aggregate_failures do
    statements = lambda do
      sql = []
      counter = ->(*, payload) { sql << payload[:sql] unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.new(account: account.reload, at:).to_json }
      sql
    end
    2.times { create(:lot, account:, entry: printing) }
    few = statements.call
    28.times { create(:lot, account:, entry: printing) }
    many = statements.call

    expect(many.size).to eq(few.size)
    expect(many.grep(/FROM "lots"/).size).to eq(1)
  end

  it "writes nothing and enqueues nothing", :aggregate_failures do
    fixture_collection
    writes = []
    counter = ->(*, payload) { writes << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/i) }

    expect { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { export.to_json } }.not_to have_enqueued_job
    expect(writes).to eq([])
  end

  it "names the file by the export's UTC date" do
    expect(described_class.new(account:, at: Time.new(2026, 10, 14, 23, 30, 0, "-05:00")).filename).to eq("collector-export-2026-10-15.json")
  end
end
```

`spec/collection_export_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 022 FR-6: the export's writer and controller name no collectible type or source, and never ask the catalog's
# registry about a type, so a lot of any type, registered or not, exports.
RSpec.describe "The collection export's code" do
  let(:files) { [ Rails.root.join("app/models/collection_export.rb"), Rails.root.join("app/controllers/collections/exports_controller.rb") ] }

  it "never names a collectible type, a source or the registry" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall)\b|collecting_for|source_class|preload_extensions/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
```

(The core spec fails until both files exist; it goes green at the end of Phase 2.)

### Step 1.2: Run red

`bin/rspec spec/models/collection_export_spec.rb` → `NameError: uninitialized constant CollectionExport` for every example.

### Step 1.3: The writer

`app/models/collection_export.rb`:

```ruby
# One account's collection as a collector-export file, format version 1 (spec 022, docs/export-format/README.md).
# Collectible-agnostic: every field comes from a core column, and the registry is never asked about a type, so a lot
# of a type the instance no longer has still exports. The lots are read in one statement, one consistent snapshot,
# so a change made during the export can't put two lots of one identity in the file (decision 8).
class CollectionExport
  FORMAT = "collector-export".freeze
  FORMAT_VERSION = 1
  LOT_COLUMNS = [ "catalog_entries.collectible_type", "catalog_entries.external_key", "catalog_entries.name",
    "catalog_sets.code", "catalog_entries.number", "catalog_entries.language", "lots.quantity", "lots.finish",
    "lots.condition", "lots.price_paid_cents", "lots.created_at", "lots.updated_at" ].freeze

  def initialize(account:, at:)
    @account = account
    @at = at
  end

  def to_h
    user = @account.user
    { "format" => FORMAT, "format_version" => FORMAT_VERSION, "exported_at" => time(@at),
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => Rails.configuration.x.currency.code,
      "lots" => lots }
  end

  def to_json(*) = JSON.generate(to_h)

  def filename = "collector-export-#{@at.utc.to_date.iso8601}.json"

  private
    def lots
      @account.lots.joins(entry: :set).order(:id).pluck(*LOT_COLUMNS).map do |row|
        type, source_id, name, set_code, number, language, quantity, finish, condition, cents, added, changed = row
        { "entry" => { "collectible_type" => type, "source_id" => source_id, "name" => name, "set_code" => set_code,
                       "collector_number" => number, "language" => language },
          "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price(cents),
          "added_at" => time(added), "changed_at" => time(changed) }
      end
    end

    # As Lot#price_paid: exact through Rational, two places.
    def price(cents) = cents && format("%.2f", cents / 100r)

    # RFC 3339 in UTC with the fraction dropped, not rounded.
    def time(value) = value.utc.iso8601
end
```

`pluck` takes the qualified column names as they are (checked in the prototype: no warning, no `Arel.sql`).

`spec/support/export_format_rules.rb`: its header comment's "Test support only: the app has no export or import yet" becomes "Test support only: the app writes the format (CollectionExport, spec 022) but has no import yet".

### Step 1.4: Run green

`bin/rspec spec/models/collection_export_spec.rb` → `12 examples, 0 failures`. (`spec/collection_export_core_spec.rb` is still red: the controller file doesn't exist.)

### Step 1.5: Commit

`feat(export): write an account's collection as a format-v1 file` (spec, writer, support comment).

## Phase 2: The download

**Implements:** FR-4, FR-4a, decisions 2, 3, 9 | **Satisfies:** AC-1.1, AC-1.7, AC-1.8, AC-2.1 (request)
**Files:** `spec/requests/collection_exports_spec.rb` (new), `config/routes.rb`, `app/controllers/collections/exports_controller.rb` (new)
**Interfaces:** `GET /collection/export` → `collection_export_path`

### Step 2.1: Failing request examples

`spec/requests/collection_exports_spec.rb`:

```ruby
require "rails_helper"

# Spec 022: GET /collection/export sends the signed-in collector's collection as a file, and nobody else's.
RSpec.describe "Collection export", type: :request do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }

  def printing = create(:mtg_printing).entry

  context "when signed in" do
    before { sign_in_as(user) }

    it "sends a well-formed file as an attachment that isn't cached", :aggregate_failures do
      create(:lot, account: user.account, entry: printing, finish: "foil", price_paid_cents: 1250)
      travel_to(Time.utc(2026, 10, 14, 23, 59, 59)) { get collection_export_path }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Content-Disposition"]).to start_with('attachment; filename="collector-export-2026-10-14.json"')
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(ExportFormatRules.problems(response.body)).to eq([])
      expect(JSON.parse(response.body)["exported_at"]).to eq("2026-10-14T23:59:59Z")
    end

    it "sends only the signed-in collector's account", :aggregate_failures do
      shared = printing
      create(:lot, account: user.account, entry: shared, quantity: 2)
      other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
      create(:lot, account: other.account, entry: shared, quantity: 8_888, price_paid_cents: 77_777)
      create(:lot, account: other.account, entry: printing)

      get collection_export_path
      file = JSON.parse(response.body)

      expect(file["profile"]["email_address"]).to eq("grace@example.test")
      expect(file["lots"].map { |lot| [ lot["entry"]["source_id"], lot["quantity"] ] }).to eq([ [ shared.external_key, 2 ] ])
      expect(file["lots"].map { |lot| lot.values_at("quantity", "price_paid") }.flatten).not_to include(8_888, "777.77")
      expect(response.body).not_to include("Zebulon Otherperson", "zebulon.otherperson@example.test")
    end

    it "answers no format suffix" do
      get "/collection/export.json"

      expect(response).to have_http_status(:not_found)
    end

    it "sends an empty collection as a file with no lots" do
      get collection_export_path

      expect(JSON.parse(response.body)["lots"]).to eq([])
    end

    it "runs as many queries for 30 lots as for 2" do
      queries = lambda do
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get collection_export_path }
        count
      end
      2.times { create(:lot, account: user.account, entry: printing) }
      few = queries.call
      28.times { create(:lot, account: user.account, entry: printing) }

      expect(queries.call).to eq(few)
    end
  end

  context "when signed out" do
    it "sends the visitor to sign in, with no file, and lands them on the collection afterwards", :aggregate_failures do
      user # an instance with a user, or FirstRun sends the visitor to sign up
      get collection_export_path
      expect(response).to redirect_to(new_session_path)
      expect(response.media_type).not_to eq("application/json")

      sign_in_as(user)
      expect(response).to redirect_to(collection_path)
    end
  end
end
```

### Step 2.2: Run red

`bin/rspec spec/requests/collection_exports_spec.rb` → `NameError: undefined local variable or method 'collection_export_path'`.

### Step 2.3: Route and controller

`config/routes.rb`, inside `resource :collection … scope module: :collections do`, after `resource :selection`:

```ruby
      resource :export, only: :show, format: false
```

`app/controllers/collections/exports_controller.rb`:

```ruby
# The collector's whole collection as one file in the export format (spec 022), built and sent in the request:
# nothing is stored and no job runs (decision 1).
class Collections::ExportsController < ApplicationController
  def show
    export = CollectionExport.new(account: Current.account, at: Time.current)
    no_store
    send_data export.to_json, type: :json, disposition: :attachment, filename: export.filename
  end

  private
    # Signing in from here lands on the collection, not on this file: Turbo submits the sign-in form and can't
    # follow a redirect to an attachment (decision 9).
    def request_authentication = redirect_to(new_session_path)
end
```

### Step 2.4: Run green

`bin/rspec spec/requests/collection_exports_spec.rb spec/collection_export_core_spec.rb spec/models/collection_export_spec.rb` → `19 examples, 0 failures`.

### Step 2.5: Commit

`feat(export): download the collection at /collection/export`.

## Phase 3: The links

**Implements:** FR-5, decision 6 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5
**Files:** `spec/requests/shell_spec.rb`, `spec/requests/admin/navigation_spec.rb`, `spec/system/collection_export_spec.rb` (new), `spec/support/system.rb`, `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb`, `docs/design-system/components/MorePage.md`, `.gitignore` (if `tmp/` isn't ignored: it is, by Rails' default)
**Interfaces:** none new

Before the views: `collector-design-system` skill, `docs/design-system/README.md` (Navigation), `components/Menu.md`, `components/MorePage.md`, `components/AppHeader.md`.

### Step 3.1: Failing request examples (markup)

Added to `spec/requests/shell_spec.rb` (signed-in context, alongside its account-menu and More examples):

```ruby
  it "links the account menu and More to the export, outside Turbo and never prefetched", :aggregate_failures do
    [ collection_path, more_path ].each do |path|
      get path
      link = Nokogiri::HTML5(response.body).css("a[href='#{collection_export_path}']")
      expect(link.map(&:text)).to include("Export collection")
      expect(link.map { |a| [ a["data-turbo"], a["data-turbo-prefetch"], a["download"] ] }.uniq).to eq([ [ "false", "false", nil ] ])
    end
    expect(Nokogiri::HTML5(response.body).at_css(".c-more li:nth-child(2) a")&.text).to eq("Export collection")
  end

  it "puts the export in the account menu for a collector who isn't an admin" do
    get collection_path

    expect(Nokogiri::HTML5(response.body).at_css(".c-appbar .c-menu__list a.c-menu__item[href='#{collection_export_path}']")&.text).to eq("Export collection")
  end
```

(Appended at the top level of `shell_spec.rb`, which signs in a non-admin in a top-level `before`. The first example's last line reads the More page's body, the loop's last request.)

`spec/requests/admin/navigation_spec.rb` compares the whole link lists of More and the account menu; both examples change so that admins and members alike get the export (AC-3.1):

```ruby
  it "links Catalog and Jobs for an admin, on the More page and in the avatar menu", :aggregate_failures do
    sign_in_as(create(:admin))

    get more_path

    expected = [ [ "Export collection", collection_export_path ], [ "Users and sign-up", admin_users_path ],
      [ "Catalog", admin_catalog_path ], [ "Jobs", admin_jobs_path ] ]
    expect(links(".c-more")).to eq(expected)
    expect(links(".c-appbar .c-menu__list")).to eq(expected)
  end

  it "shows a member only the export, neither admin link", :aggregate_failures do
    sign_in_as(create(:user))

    get more_path

    expect(links(".c-more")).to eq([ [ "Export collection", collection_export_path ] ])
    expect(links(".c-appbar .c-menu__list")).to eq([ [ "Export collection", collection_export_path ] ])
  end
```

### Step 3.2: Failing system example (download)

`spec/support/system.rb` gains a download folder for the suite's Firefox (the two preferences suffice: checked on headless Firefox 157, an attachment is saved there without a dialog):

```ruby
Capybara.enable_aria_label = true

# Where the suite's Firefox saves downloads (spec 022); emptied before each example that reads it.
DOWNLOADS = Rails.root.join("tmp/downloads")

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Camera pages get Firefox's synthetic stream without a prompt; scanner specs then substitute their own
    # card in the page (ADR 0002). Downloads land in DOWNLOADS without asking.
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ] do |options|
      options.add_preference("media.navigator.permission.disabled", true)
      options.add_preference("media.navigator.streams.fake", true)
      options.add_preference("browser.download.folderList", 2)
      options.add_preference("browser.download.dir", DOWNLOADS.to_s)
    end
  end
end
```

`spec/system/collection_export_spec.rb`:

```ruby
require "rails_helper"

# Spec 022 AC-3.3: the account menu's "Export collection" downloads the file and leaves the collection page shown.
RSpec.describe "Collection export", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }

  before do
    FileUtils.rm_rf(DOWNLOADS)
    FileUtils.mkdir_p(DOWNLOADS)
  end

  # Capybara has no download matcher; its own waiting retries until the file is complete.
  def downloaded(name)
    file = DOWNLOADS.join(name)
    part = DOWNLOADS.join("#{name}.part")
    page.document.synchronize { raise Capybara::ExpectationNotMet, "no #{name}" unless file.exist? && file.size.positive? && !part.exist? }
    file
  end

  it "downloads the collection from the account menu", :aggregate_failures do
    create(:lot, account: user.account, entry: create(:mtg_printing).entry, finish: "foil")
    visit collection_path
    find(".c-avatar").click
    click_on "Export collection"

    file = downloaded("collector-export-#{Time.current.utc.to_date.iso8601}.json")
    expect(ExportFormatRules.problems(file.binread)).to eq([])
    expect(JSON.parse(file.read)["lots"].size).to eq(1)
    expect(page).to have_css("h1", text: "My collection")
  end
end
```

Run `bin/rspec spec/requests/shell_spec.rb spec/requests/admin/navigation_spec.rb spec/system/collection_export_spec.rb` → the two shell and two navigation examples fail (no link), the system example fails with `Capybara::ElementNotFound: Unable to find link or button "Export collection"`.

### Step 3.3: The views

`app/views/layouts/_appbar.html.erb`, the menu list becomes:

```erb
        <div class="c-menu__list">
          <%= link_to "Export collection", collection_export_path, class: "c-menu__item", data: { turbo: false, turbo_prefetch: false } %>
          <div class="c-menu__sep"></div>
          <% if Current.user.admin? %><%= link_to "Users and sign-up", admin_users_path, class: "c-menu__item" %><%= link_to "Catalog", admin_catalog_path, class: "c-menu__item" %><%= link_to "Jobs", admin_jobs_path, class: "c-menu__item" %><div class="c-menu__sep"></div><% end %>
          <%= button_to "Sign out", session_path, method: :delete, class: "c-menu__item", form: { class: "c-menu__form" } %>
        </div>
```

`app/views/mores/show.html.erb`, after the "Signed in as" row:

```erb
    <li><%= link_to "Export collection", collection_export_path, data: { turbo: false, turbo_prefetch: false } %></li>
```

`docs/design-system/components/MorePage.md`: the markup gains `<li><a href="/collection/export" data-turbo="false" data-turbo-prefetch="false">Export collection</a></li>` after the "Signed in as" row; its bullets gain "Export collection is a plain download link, outside Turbo and never prefetched; it is for every collector, so it comes before the admin links."

### Step 3.4: Run green

`bin/rspec spec/requests/shell_spec.rb spec/requests/admin/navigation_spec.rb spec/system/collection_export_spec.rb` → 0 failures. Then `bin/rspec spec/system` to confirm the new Firefox preferences change no other system example.

### Step 3.5: Screenshots

At 1280px with the account menu open, and the More page at 390px (in the fixed-width iframe of the headless-Firefox memory), light and dark: four PNGs in `docs/specs/022-export-collection/screenshots/`, taken with a throwaway script outside the repo (as spec 021). Checked: the item is shown in full, nothing scrolls sideways, the focus ring shows on the link.

### Step 3.6: Commit

`feat(export): link the export from the account menu and More` (views, specs, support, MorePage.md, screenshots).

## Phase 4: Cost, documents, verification

**Implements:** NFR cost, Documents that change | **Satisfies:** AC-1.9, AC-3.5 (reading), the spec's acceptance as a whole
**Files:** `docs/specs/022-export-collection/verification.md` (new), `docs/specs/022-export-collection/spec.md` (status, rulings), `docs/roadmap.md` (#38 line), `CLAUDE.md` (status line, export-format fact)
**Interfaces:** none

### Step 4.1: Measure

A throwaway `bench_spec.rb` outside the repo (the scratch prototype, pointed at `CollectionExport` and run through a request: `get collection_export_path` after inserting 50,000 entries and lots with `insert_all!`), run with `bin/rspec <path>`. Records wall time, file size and RSS growth for the request, and the method, into `verification.md`: AC-1.9 passes under 10 s and under 300 MB.

### Step 4.2: Documents

- `docs/roadmap.md` theme A item 3: `[#38](…) Export a collection as a file. **Done 2026-10-NN:** [spec 022](specs/022-export-collection/spec.md).` (the date it merges; written as the PR's date).
- `CLAUDE.md`: the status line's "export and import aren't built yet" becomes "a collector downloads their collection as an export file from the account menu or More (`CollectionExport`, `/collection/export`, spec 022); import isn't built yet"; the export-format fact's "Nothing in the app reads or writes it yet" becomes "`CollectionExport` writes it (spec 022); nothing reads it yet".
- `spec.md`: acceptance boxes ticked as `verification.md` records them.

### Step 4.3: Verification

`verification.md` lists each AC with its evidence (example names, screenshots, the measurement, documents read). `bin/ci` → green; its output summary recorded. Read-only Opus spec-alignment review (sdd-review Mode B) before asking to push.

### Step 4.4: Commit

`docs(export): verification, roadmap and status for spec 022`.

## Self-review

- FR-1 → Phase 1; FR-2 → Phase 1 (one-statement read, query-count example); FR-3 → Phase 1 (no writes, no jobs); FR-4 → Phase 2; FR-4a → Phase 2 (`answers no format suffix`); FR-5 → Phase 3; FR-6 → Phase 1 core spec (green after Phase 2).
- AC-1.1 → 2.1; AC-1.2 → 1.1; AC-1.3 → 1.1; AC-1.4 → 1.1 (`11.999` stored with `with_usec: true`, and `0.5`, both dropped); AC-1.5 → 1.1, 2.1; AC-1.6 → 1.1; AC-1.7 → 2.1; AC-1.8 → 2.1 (and 1.1); AC-1.9 → 4.1; AC-2.1 → 1.1, 2.1; AC-2.2 → 1.1; AC-2.3 → 1.1; AC-3.1 → 3.1 (shell and admin navigation examples); AC-3.2 → 3.1; AC-3.3 → 3.2; AC-3.4 → 3.5; AC-3.5 → 3.3, 4.3.
- Gates: two new components (writer, controller), no new dependency, no wrapper, no DTO (the Hash is the format).
