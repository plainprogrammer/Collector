# Implementation Plan: Collection Table View and Bulk Editing

**Spec:** docs/specs/006-collection-list-view/spec.md (v4.0.0, Approved)
**Decisions:** none (no ADRs; the plan decisions below trace to the spec)
**Supporting docs:** [data-model.md](data-model.md) (its content is the "Data model" section below, written to disk with this plan)
**Created:** 2026-09-30

## Context

Feature 004 left the collection as an image grid with a name filter. Spec 006 adds four things:
- A per-lot **table**, with sortable columns.
- A **grid/table switch** whose choice is remembered per user.
- **Bulk mode**, where the collector selects lots one by one, across pages, or as every lot matching the filter.
- Two **bulk actions**: Set condition, and Remove with a single Undo.

Everything must work without scripting. Three Fable spec reviews shaped the spec; the third review's plan-level notes are carried into the decisions below.

**Plan decisions (each traced to the spec):**
- **Shared filter (FR-2):** the grid and the table share a `CollectionFilter` module, extracted from `CollectionGrid`, for the name filter and the counts.
  - `CollectionTable` lists lots.
  - `CollectionTable::Sort` holds the allowlisted column and direction and builds Arel order nodes. No request value reaches SQL.
  - The condition and finish orders come from each collectible's vocabulary through a `CASE` (FR-2, FR-3).
- **Saving the view (FR-1, AC-1.3):** `users.collection_view` (default `grid`). `CollectionsController#show` saves `params[:view]` when it's valid, the page isn't in bulk mode, and the request isn't a prefetch (`Sec-Purpose`/`X-Sec-Purpose` contains `prefetch`; AC-1.10).
- **View switch and Edit many (FR-1, AC-4.1):**
  - The view switch is `<button form="view-switch" name="view">`. It submits a hidden GET form that sits *inside* the `results` frame, so the form is re-rendered with every in-place filter and always carries the current filter and sort. The form targets `_top`, so the whole page, header and switch state included, changes (review note: target `_top`).
  - `Edit many` works the same way: `<button form="edit-many">` submits a hidden POST form in the frame.
  - Buttons are never prefetched.
- **Where the selection lives (FR-4):** server-side.
  - `bulk_selections` holds one row per session with `query`, `sort_key` and `all_matching`.
  - `bulk_selection_marks` lists the marked lot ids: the selected lots, or the exceptions in "all matching" mode.
  - Foreign keys to `sessions`, `lots` and `accounts` use `ON DELETE CASCADE`, because sessions also end through `delete_all`, which skips callbacks (review note).
- **The bulk form (FR-4):**
  - Bulk mode renders one `PATCH /collection/selection` form (`id="bulk"`). The filter input and a visually hidden `Filter` button sit in the filter bar outside that form and join it through `form="bulk"`. The view switch is outside the form and inert, and `url-sync` isn't attached (review note).
  - The `Filter` button comes first in tree order, so pressing Enter applies the filter.
  - The sort headers, pager, actions and `Done` are `<button name="go">`. Their value is a keyword (`filter`, `done`, `set_condition`, `remove`) or a local collection URL.
  - `Collections::SelectionsController#update` records the ticks, then redirects (303) where `go` says.
- **The action pages (Stories 6–7):** a page for Set condition (`Collections::ConditionChangesController`) and one for the removal confirmation (`Collections::BulkRemovalsController`). Both read the session's selection.
  - Success redirects (303) to the bulk table, keeping the page number through `page`.
  - A refusal re-renders the action page at 422 (FR-5).
- **Undo (FR-6):** `bulk_removals` (session, account, copies, JSON `lots_data`).
  - A used or superseded record keeps the row with `lots_data = NULL`, so a replayed Undo answers 422.
  - A partial unique index keeps at most one undoable record per session.
  - The status message's Undo is a `button_to` carrying `return_to: request.fullpath`. `Collections::BulkRemovals::UndosController` finds the record through `Current.session.bulk_removals`, so another session's or an unknown id gets 404.
- **Live count (AC-5.8, AC-4.6):** a Stimulus `bulk-selection` controller.
  - Count = the server's "selected copies not on this page" plus the quantities of the ticked rows.
  - The header checkbox goes `indeterminate` once something is unticked.
  - Esc calls `requestSubmit(Done)`. Its listener runs in the capture phase, so an open `<details>` menu is seen before the menu controller closes it.
- **Merges (AC-6.3, AC-7.5):** `Lot::ConditionChange` groups the selected lots by target identity and checks the cap for every group before writing anything, so it's all or nothing. It names the first over-cap lot in the table's order. `BulkRemoval#undo!` does the same against existing lots, then calls `Lot.add!`.
- **Row actions (AC-2.6):** the row menus link `edit_lot_path` and `new_lot_removal_path` with `from=collection&return_to=<table URL>`. `CardContext#lot_return_path` follows `return_to` only when `url_from` accepts it, and otherwise goes to the card page (004 AC-7.3).
- **Migrations:** they're numbered `20260930100001`–`…003`, clear of the parallel 005 branch's numbering. Every one is additive and reversible.

## Global Constraints

- Ruby 4.0.7, Rails 8.1.4, SQLite, Propshaft + importmap, Hotwire. No new gems or JS packages.
- UI is built only from design-system tokens and `c-*` classes. New patterns go in `app/assets/stylesheets/collector/additions.css`, each with a doc under `docs/design-system/components/` (FR-7). The exported files are never changed.
- Copy is sentence case with no "we", no emoji and no exclamation marks; numbers are exact, digit-grouped and pluralised ("1 item", "2 items", "1 lot"). Messages are verbatim from the spec:
  - "Select at least one item."
  - "None of the selected items are in your collection any more."
  - "That isn't a known condition."
  - "This removal can no longer be undone."
  - "Set the condition of <n> items to <label>." / "Cleared the condition of <n> items."
  - "Removed <n> items from your collection." / "Restored <n> items to your collection."
  - "Nothing changed. <card> (<SET> · <number>) would have more than 9,999 copies in one lot." / "Nothing restored. …"
- Tenant data carries `account_id` with a foreign key and an index. Every query goes through `Current.account` or `Current.session`, and ids from a request are always re-checked against the account (AC-8.1).
- No GET request changes a selection or an Undo record. A GET changes only the view preference, and never on a prefetch.
- Scripting only enhances: the live count, the header's mixed state, in-place filter results, status updates and Esc.
- Magic numbers:

  | Setting | Value |
  |---|---|
  | Table page size | 120 rows (`CollectionTable::PER_PAGE`) |
  | Lot cap | 9,999 (`Lot::MAX_QUANTITY`) |
  | Undoable removals per session | 1 |
  | Table under 5,000 lots | < 500 ms (server) |
  | Bulk action on 5,000 lots | < 2 s (server) |
- Migrations are reversible, never edited after release, and never reference app models. Specs tag their `type:`, multi-expectation examples use `:aggregate_failures`, and system specs never `sleep`.
- One Conventional Commit per step (`docs/git-convention.md`), with RSpec green at every commit. Branch: `006-collection-list-view`.

---

## Goal

The collection can be shown as a sortable per-lot table or as the grid, and the view is remembered per user. In bulk mode a collector selects lots across pages, or every lot matching the filter, then sets their condition, or removes them with a one-time Undo. All of it works without scripting and on a phone.

**Components (Simplicity Gate: 3):**
1. Listing: `CollectionFilter`, `CollectionGrid`, `CollectionTable`, `CollectionTable::Sort` and the view preference.
2. Selection: `BulkSelection`, `BulkSelection::Mark`, `CollectionTable::SelectionState`, `Collections::SelectionsController` and the Stimulus count.
3. Bulk actions: `Lot::ConditionChange`, `BulkRemoval` and their controllers and pages.

**Anti-Abstraction:** ActiveRecord, Arel, `url_from`, `button_to` and Stimulus are used directly. The POROs, each with one job, are `CollectionTable`, `CollectionTable::Sort`, `CollectionTable::SelectionState` and `Lot::ConditionChange`, and there are no parallel view models. **Integration-First:** each phase adds its routes behind a failing routing example, and its request specs (the HTML contract) come before the code.

---

## Data model

(Written to `docs/specs/006-collection-list-view/data-model.md`.)

### User (changed)
| Field | Type | Constraints | Description |
|---|---|---|---|
| collection_view | string | not null, default `"grid"`, model inclusion `grid`/`table` | Saved collection view |
**Spec requirement:** FR-1, AC-1.2, AC-1.3, AC-8.5.

### BulkSelection
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| session_id | integer | not null, FK `sessions` ON DELETE CASCADE, unique index | One per session |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| query | string | not null, default `""` | Filter it was made under |
| sort_key | string | not null, default `""` | Sort it was made under (`"price-desc"`, `""` = default) |
| all_matching | boolean | not null, default false | Every matching lot is selected; marks are exceptions |
| created_at/updated_at | datetime | not null | |
**Relationships:** belongs_to session and account; has_many marks. **Spec requirement:** FR-4, Story 5.

### BulkSelection::Mark (`bulk_selection_marks`)
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | |
| bulk_selection_id | integer | not null, FK ON DELETE CASCADE | |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| lot_id | integer | not null, FK `lots` ON DELETE CASCADE, index | A selected lot, or an exception |
**Indexes:** unique `[bulk_selection_id, lot_id]`. **Spec requirement:** FR-4, AC-5.3, AC-5.5.

### BulkRemoval
| Field | Type | Constraints | Description |
|---|---|---|---|
| id | integer | PK | Undo addresses it |
| session_id | integer | not null, FK `sessions` ON DELETE CASCADE, index | Owner |
| account_id | integer | not null, FK `accounts` ON DELETE CASCADE, index | Tenant |
| copies | integer | not null | Copies removed, for the messages |
| lots_data | json | nullable | `[{catalog_entry_id, finish, condition, price_paid_cents, quantity}]`; NULL once used or superseded |
| created_at/updated_at | datetime | not null | |
**Indexes:** partial unique `session_id WHERE lots_data IS NOT NULL` (one undoable per session). **Spec requirement:** FR-6, Story 7.

---

## Phase 0: Doc-first commit

**Implements:** — | **Satisfies:** — (enables all)
**Files:** `docs/specs/006-collection-list-view/{plan.md,data-model.md}`
**Interfaces:** Consumes: nothing. Produces: the plan the later phases follow.

- [ ] Confirm the branch is `006-collection-list-view` (it already holds the spec commits).
- [ ] Write `plan.md` and `data-model.md` (this document and its Data model section).
- [ ] Commit: `docs(specs): add plan and data model for 006 collection table and bulk editing`

---

## Phase 1: The table's model: shared filter, rows and sort

**Implements:** FR-2 (model), FR-3 | **Satisfies:** AC-2.1 (rows), AC-2.4, AC-2.7, AC-3.1, AC-3.2 (order), AC-3.3, AC-3.4, AC-3.5, AC-3.7
**Files:** `app/models/collection_filter.rb`, `app/models/collection_grid.rb`, `app/models/collection_table.rb`, `app/models/collection_table/sort.rb`, `app/models/mtg/collecting.rb`, `spec/support/collection_helpers.rb`, `spec/models/collection_table_spec.rb`, `spec/models/collection_table/sort_spec.rb`, `spec/models/mtg/collecting_spec.rb`
**Interfaces:** Consumes: `Catalog::Pagination.for`, `Catalog::Entry.named_like`, `Catalog.collecting`. Produces:
- `CollectionFilter.normalize(query) → String`
- `CollectionFilter.lots(account, query) → Lot relation (joins :entry)`
- instance methods `#query #filtered? #empty_collection? #total_quantity #matching_quantity #unique_cards`
- `CollectionTable.new(account:, query:, page:, sort:)` with `#lots #pagination #sort` and `PER_PAGE = 120`
- `CollectionTable::Sort.parse(column, direction)`, `.from_key(key)`, `#column #direction #default? #key #to_params #aria_sort(header) #toward(header) #apply(scope)`
- `MTG::Collecting.finish_order`
- the spec helper `owned_printing(name, account:, set:, number:, language:, localized_name:, released_on:, finishes:, **lot) → Lot`

- [ ] Write the spec helper `spec/support/collection_helpers.rb`:
  ```ruby
  # Owned printings for collection specs (spec 006): each call makes a new printing and a lot of it.
  module CollectionHelpers
    def owned_printing(name = "Lightning Bolt", account:, set: nil, number: nil, language: "en", localized_name: nil,
      released_on: nil, finishes: %w[nonfoil foil etched], **lot)
      identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
      set ||= create(:catalog_set, **{ released_on: }.compact)
      entry = create(:catalog_entry, identity:, name:, set:, language:, localized_name:, **{ number:, released_on: }.compact)
      create(:mtg_printing, entry:, finishes:)
      create(:lot, account:, entry:, **lot)
    end
  end

  RSpec.configure do |config|
    %i[model request system].each { |type| config.include CollectionHelpers, type: }
  end
  ```
- [ ] Write `spec/models/collection_table/sort_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe CollectionTable::Sort, type: :model do
    it "reads the default order as Name ascending, so the first Name activation goes descending", :aggregate_failures do
      sort = described_class.parse(nil, nil)
      expect([ sort.default?, sort.key, sort.to_params ]).to eq([ true, "", {} ])
      expect(%w[name set condition quantity price].map { |column| sort.aria_sort(column) }).to eq(%w[ascending none none none none])
      expect(sort.toward("name").to_params).to eq(sort: "name", dir: "desc")
      expect(sort.toward("price").to_params).to eq(sort: "price", dir: "asc")
    end

    it "reverses the sorted column on each activation", :aggregate_failures do
      sort = described_class.parse("price", "desc")
      expect(sort.aria_sort("price")).to eq("descending")
      expect(sort.toward("price").to_params).to eq(sort: "price", dir: "asc")
      expect(sort.toward("price").toward("price").to_params).to eq(sort: "price", dir: "desc")
    end

    it "ignores unknown columns and directions", :aggregate_failures do
      expect(described_class.parse("bogus", "desc")).to be_default
      expect(described_class.parse("price", "sideways").direction).to eq("asc")
      expect(described_class.parse([ "price" ], { "x" => 1 })).to be_default
    end

    it "round-trips through its key", :aggregate_failures do
      expect(described_class.from_key("condition-desc").to_params).to eq(sort: "condition", dir: "desc")
      expect(described_class.from_key("")).to be_default
    end
  end
  ```
- [ ] Write `spec/models/collection_table_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe CollectionTable, type: :model do
    let(:account) { create(:user).account }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)

    def table(sort: nil, dir: nil, query: nil, page: nil)
      described_class.new(account:, query:, page:, sort: CollectionTable::Sort.parse(sort, dir))
    end

    it "pages at 120 rows" do
      expect(described_class::PER_PAGE).to eq(120)
    end

    it "lists one row per lot in the grid's order, then finish, condition and price paid" do
      first = own("Lightning Bolt")
      lot = ->(**attributes) { create(:lot, account:, entry: first.entry, **attributes) }
      foil = lot.call(finish: "foil")
      played = lot.call(finish: "nonfoil", condition: "lightly_played")
      nm_dear = lot.call(finish: "nonfoil", condition: "near_mint", price_paid_cents: 200)
      nm_unpriced = lot.call(finish: "nonfoil", condition: "near_mint")
      nm_cheap = lot.call(finish: "nonfoil", condition: "near_mint", price_paid_cents: 100)
      opt = own("Opt")
      expect(table.lots).to eq([ nm_cheap, nm_dear, nm_unpriced, played, foil, first, opt ])
    end

    it "puts the newest printing of a card first" do
      old = own("Lightning Bolt", released_on: Date.new(1993, 8, 5))
      new = own("Lightning Bolt", released_on: Date.new(2021, 1, 1))
      expect(table.lots).to eq([ new, old ])
    end

    it "sorts by card name, not the printed name", :aggregate_failures do
      bolt = own("Lightning Bolt", language: "ja", localized_name: "稲妻")
      opt = own("Opt")
      expect(table(sort: "name", dir: "asc").lots).to eq([ bolt, opt ])
      expect(table(sort: "name", dir: "desc").lots).to eq([ opt, bolt ])
    end

    it "sorts by set and collector number, reversing both when descending", :aggregate_failures do
      aaa = create(:catalog_set, code: "aaa")
      bbb = create(:catalog_set, code: "bbb")
      a1 = own("Opt", set: aaa, number: "1")
      a2 = own("Bolt", set: aaa, number: "2")
      b1 = own("Shock", set: bbb, number: "1")
      expect(table(sort: "set", dir: "asc").lots).to eq([ a1, a2, b1 ])
      expect(table(sort: "set", dir: "desc").lots).to eq([ b1, a2, a1 ])
    end

    it "sorts condition by the collectible's scale with unspecified last both ways", :aggregate_failures do
      damaged = own("Card A", condition: "damaged")
      near_mint = own("Card B", condition: "near_mint")
      none = own("Card C")
      expect(table(sort: "condition", dir: "asc").lots).to eq([ near_mint, damaged, none ])
      expect(table(sort: "condition", dir: "desc").lots).to eq([ damaged, near_mint, none ])
    end

    it "sorts quantity and price paid numerically, unspecified price last both ways", :aggregate_failures do
      nine = own("Card A", quantity: 9, price_paid_cents: 900)
      ten = own("Card B", quantity: 10, price_paid_cents: 10_000)
      unpriced = own("Card C", quantity: 1)
      expect(table(sort: "quantity", dir: "asc").lots).to eq([ unpriced, nine, ten ])
      expect(table(sort: "price", dir: "asc").lots).to eq([ nine, ten, unpriced ])
      expect(table(sort: "price", dir: "desc").lots).to eq([ ten, nine, unpriced ])
    end

    it "breaks ties with the default order" do
      opt = own("Opt", quantity: 2)
      bolt = own("Lightning Bolt", quantity: 2)
      expect(table(sort: "quantity", dir: "desc").lots).to eq([ bolt, opt ])
    end

    it "filters by name, counts like the grid and pages", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      own("Lightning Bolt", quantity: 3)
      own("Bolt of Lightning", quantity: 1)
      own("Opt", quantity: 2)
      bolts = table(query: " bolt ", page: "99")
      expect([ bolts.query, bolts.matching_quantity, bolts.total_quantity, bolts.unique_cards ]).to eq([ "bolt", 4, 6, 3 ])
      expect([ bolts.pagination.page, bolts.pagination.total_pages, bolts.lots.size ]).to eq([ 2, 2, 1 ])
    end

    it "keeps rows of retired printings" do
      lot = own
      lot.entry.update!(retired_at: 1.day.ago)
      expect(table.lots).to eq([ lot ])
    end

    it "lists only the account's lots" do
      owned_printing(account: create(:user).account)
      expect(table.lots).to be_empty
    end
  end
  ```
- [ ] Add to `spec/models/mtg/collecting_spec.rb`, inside its top-level `describe` (create the file with `require "rails_helper"` and `RSpec.describe MTG::Collecting, type: :model do … end` if it doesn't exist):
  ```ruby
  it "orders finishes nonfoil, foil, etched" do
    expect(described_class.finish_order).to eq(%w[nonfoil foil etched])
  end
  ```
- [ ] Run: `bin/rspec spec/models/collection_table_spec.rb spec/models/collection_table/sort_spec.rb spec/models/mtg/collecting_spec.rb` — expect FAIL (uninitialized constant `CollectionTable`, undefined method `finish_order`).
- [ ] Add to `app/models/mtg/collecting.rb`, after `def self.special_finishes`:
  ```ruby
  def self.finish_order = FINISH_ORDER
  ```
- [ ] Write `app/models/collection_filter.rb`:
  ```ruby
  # The name filter and counts the collection's grid and table share (spec 004 AC-11.1, AC-11.4;
  # spec 006 AC-2.2, AC-2.3). Includers set @account and @query.
  module CollectionFilter
    def self.normalize(query) = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)

    # An account's lots whose printing matches the filter.
    def self.lots(account, query)
      scope = account.lots.joins(:entry)
      query.present? ? scope.merge(Catalog::Entry.named_like(query)) : scope
    end

    attr_reader :query

    def filtered? = query.present?
    def empty_collection? = total_quantity.zero?
    def total_quantity = @total_quantity ||= @account.lots.sum(:quantity)
    def matching_quantity = @matching_quantity ||= matching_lots.sum(:quantity)

    def unique_cards
      @unique_cards ||= @account.lots.joins(:entry).distinct.count("catalog_entries.catalog_identity_id")
    end

    private
      def matching_lots = CollectionFilter.lots(@account, query)
  end
  ```
- [ ] Replace `app/models/collection_grid.rb` with (the counts move to `CollectionFilter`, and tiles don't change):
  ```ruby
  # One page of an account's collection as image tiles: one per owned printing (spec 004 Story 11).
  class CollectionGrid
    include CollectionFilter

    PER_PAGE = 120
    Tile = Data.define(:entry, :quantity, :special_finishes)

    def initialize(account:, query:, page:)
      @account = account
      @query = CollectionFilter.normalize(query)
      @requested_page = page
    end

    def pagination
      @pagination ||= Catalog::Pagination.for(total_count: matching_lots.distinct.count(:catalog_entry_id),
        requested_page: @requested_page, per_page: PER_PAGE)
    end

    def tiles
      @tiles ||= begin
        rows = matching_lots.group(:catalog_entry_id)
          .order(Catalog::Entry.arel_table[:name].asc).merge(Catalog::Entry.newest_first)
          .offset(pagination.offset).limit(PER_PAGE)
          .pluck(:catalog_entry_id, Arel.sql("SUM(lots.quantity)"), Arel.sql("GROUP_CONCAT(DISTINCT lots.finish)"))
        entries = Catalog::Entry.includes(:set).where(id: rows.map(&:first)).index_by(&:id)
        rows.map do |entry_id, quantity, finishes|
          entry = entries.fetch(entry_id)
          special = Catalog.collecting_for(entry.collectible_type).special_finishes & finishes.to_s.split(",")
          Tile.new(entry:, quantity:, special_finishes: special)
        end
      end
    end
  end
  ```
- [ ] Write `app/models/collection_table/sort.rb`:
  ```ruby
  # The collection table's order (spec 006 Story 3, FR-3): one allowlisted column and direction, applied
  # in SQL before paging. The default order (the grid's, then finish, condition and price paid) breaks
  # every tie, so the order is stable across pages. Only Arel nodes reach the query.
  class CollectionTable::Sort
    COLUMNS = %w[name set condition quantity price].freeze
    DIRECTIONS = %w[asc desc].freeze

    attr_reader :column, :direction

    def self.parse(column, direction)
      return new(nil, "asc") unless COLUMNS.include?(column)

      new(column, DIRECTIONS.include?(direction) ? direction : "asc")
    end

    # The form a bulk selection stores: "condition-desc", or "" for the default order.
    def self.from_key(key) = parse(*key.to_s.split("-", 2))

    def self.default_order
      [ asc(entries[:name]), desc(entries[:released_on]), asc(sets[:code]), asc(entries[:number]), asc(entries[:language]),
        asc(lots[:finish].eq(nil)), asc(rank(lots[:finish], &:finish_order)), asc(lots[:finish]),
        asc(lots[:condition].eq(nil)), asc(rank(lots[:condition]) { |vocabulary| vocabulary.conditions.keys }),
        asc(lots[:price_paid_cents].eq(nil)), asc(lots[:price_paid_cents]), asc(lots[:id]) ]
    end

    # Each collectible's own order for a column (its condition scale, its finishes); unknown values last.
    def self.rank(column)
      orders = Catalog.collecting.keys.index_with { |type| yield Catalog.collecting_for(type) }
      orders.each_with_object(Arel::Nodes::Case.new) do |(type, values), node|
        values.each_with_index { |value, index| node.when(entries[:collectible_type].eq(type).and(column.eq(value))).then(index) }
      end.else(orders.values.map(&:size).max.to_i)
    end

    def self.asc(node) = Arel::Nodes::Ascending.new(node)
    def self.desc(node) = Arel::Nodes::Descending.new(node)
    def self.lots = Lot.arel_table
    def self.entries = Catalog::Entry.arel_table
    def self.sets = Catalog::Set.arel_table

    def initialize(column, direction)
      @column, @direction = column, direction
    end

    def default? = column.nil?
    def key = default? ? "" : "#{column}-#{direction}"
    def to_params = default? ? {} : { sort: column, dir: direction }

    # How a header states the order; the default order reads as Name ascending (AC-3.1, AC-3.2).
    def aria_sort(header)
      return "none" unless header == (column || "name")

      direction == "asc" ? "ascending" : "descending"
    end

    # Where activating a header leads: its column ascending, or the sorted column reversed (AC-3.2).
    def toward(header) = self.class.new(header, aria_sort(header) == "ascending" ? "desc" : "asc")

    # Orders a lots relation that joins entry and set.
    def apply(scope) = scope.reorder(*leading, *self.class.default_order)

    private
      def leading
        klass = self.class
        case column
        when "name" then [ by(klass.entries[:name]) ]
        when "set" then [ by(klass.sets[:code]), by(klass.entries[:number]) ]
        when "condition"
          [ klass.asc(klass.lots[:condition].eq(nil)), by(klass.rank(klass.lots[:condition]) { |vocabulary| vocabulary.conditions.keys }) ]
        when "quantity" then [ by(klass.lots[:quantity]) ]
        when "price" then [ klass.asc(klass.lots[:price_paid_cents].eq(nil)), by(klass.lots[:price_paid_cents]) ]
        else []
        end
      end

      def by(node) = direction == "asc" ? self.class.asc(node) : self.class.desc(node)
  end
  ```
- [ ] Write `app/models/collection_table.rb`:
  ```ruby
  # One page of an account's collection as table rows, one per lot (spec 006 Story 2), in the chosen
  # sort (Story 3).
  class CollectionTable
    include CollectionFilter

    PER_PAGE = 120

    attr_reader :sort

    def initialize(account:, query:, page:, sort:)
      @account = account
      @query = CollectionFilter.normalize(query)
      @requested_page = page
      @sort = sort
    end

    def pagination
      @pagination ||= Catalog::Pagination.for(total_count: matching_lots.count, requested_page: @requested_page, per_page: PER_PAGE)
    end

    def lots
      @lots ||= sort.apply(matching_lots.joins(entry: :set)).preload(entry: :set)
        .offset(pagination.offset).limit(PER_PAGE).to_a
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/collection_table_spec.rb spec/models/collection_table/sort_spec.rb spec/models/mtg/collecting_spec.rb spec/models/collection_grid_spec.rb && bin/rails zeitwerk:check` — expect PASS, and "All is good!".
- [ ] Commit: `feat(collection): add the per-lot collection table model and its sort`

---

## Phase 2: The table view and its sortable headers

**Implements:** FR-2, FR-3 (UI) | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.5, AC-2.7, AC-3.2, AC-3.6 (paging, filter), AC-3.7, AC-3.8
**Files:** `app/controllers/concerns/collection_listing.rb`, `app/controllers/collections_controller.rb`, `app/helpers/collections_helper.rb`, `app/helpers/lots_helper.rb`, `app/views/collections/{show,_filter_bar,_table,_lot_cells}.html.erb`, `app/views/catalog/entries/_copies.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/collection_table_spec.rb`
**Interfaces:** Consumes: Phase 1. Produces:
- `CollectionListing#prepare_collection(query:, sort:, page:, view:, bulk:, path: request.fullpath)`, which sets `@listing @view @bulk @sort @listing_path`
- `collection_listing_path(query:, sort:, page:, bulk:, view:)`
- `sort_header(table, column, label, **html)`
- `lot_finish(lot)`, `lot_condition(lot)`, `lot_price(lot)`, `lot_label(lot)`, `lot_summary(lot)`
- the partials `collections/_table` (locals `table:, return_to:`) and `collections/_lot_cells` (`lot:`)

In this phase the table is reached with `?view=table`; Phase 3 adds the switch and the saved preference.

- [ ] Write `spec/requests/collection_table_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection table", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
    def page_html = Nokogiri::HTML5(response.body)
    def rows = page_html.css("table.c-table tbody tr")
    def cells(row) = row.css("td").map { |cell| cell.text.squish }
    def header(label) = page_html.css("table.c-table thead th").find { |th| th.text.strip == label }

    it "shows one row per lot with printing, language, finish, condition, quantity and price paid", :aggregate_failures do
      foil = own("Lightning Bolt", number: "146", quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
      create(:lot, account: user.account, entry: foil.entry, finish: "nonfoil")
      opt = own("Opt", language: "ja", localized_name: "選択")
      get collection_path(view: "table")
      bolt_set = "#{foil.entry.set.code.upcase} · 146"
      expect(rows.map { |row| row.at_css("td a")&.text }).to eq([ "Lightning Bolt", "Lightning Bolt", "選択" ])
      expect(rows.map { |row| cells(row)[1..6] }).to eq([
        [ bolt_set, "EN", "Nonfoil", "—", "1", "—" ],
        [ bolt_set, "EN", "Foil", "NM", "2", "$1.25" ],
        [ "#{opt.entry.set.code.upcase} · #{opt.entry.number}", "JA", "—", "—", "1", "—" ]
      ])
      expect(rows[0].at_css("td:nth-child(4) span.is-muted")&.text).to eq("Nonfoil")
      expect(rows[1].at_css("td:nth-child(4) .is-muted")).to be_nil
      expect(rows[1].at_css("td a")["href"]).to eq(catalog_entry_path(foil.entry, from: "collection"))
      expect(rows[1].at_css(".c-table__sub").text).to eq("#{bolt_set} · Foil · NM · EN")
    end

    it "keeps the grid's page head, Add items and count", :aggregate_failures do
      own("Lightning Bolt", quantity: 3)
      own("Opt", quantity: 2)
      get collection_path(view: "table", q: "bolt")
      expect(response.body).to include("5 items · 2 unique", "3 of 5 items")
      expect(page_html.at_css(".c-pagehead__actions a")["href"]).to eq(catalog_entries_path)
      expect(rows.size).to eq(1)
    end

    it "says when the filter matches nothing" do
      own
      get collection_path(view: "table", q: "zzz")
      expect([ response.body.include?(%(No cards in your collection match "zzz".)), response.body.include?("0 of 1 item<"), rows.size ])
        .to eq([ true, true, 0 ])
    end

    it "pages and falls back to the nearest real page", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 2)
      3.times { |n| own("Card #{n}") }
      get collection_path(view: "table")
      expect(rows.size).to eq(2)
      expect(page_html.at_css(".c-pager__position").text).to eq("Page 1 of 2")
      expect(page_html.at_css("a[rel=next]")["href"]).to eq(collection_path(page: 2, view: "table"))
      get collection_path(view: "table", page: "99")
      expect([ response.status, rows.size ]).to eq([ 200, 1 ])
    end

    it "gives each row an actions menu named after the lot", :aggregate_failures do
      lot = own("Lightning Bolt", number: "146", finish: "foil", condition: "near_mint")
      get collection_path(view: "table")
      menu = rows.sole.at_css("td.c-table__actions details.c-menu")
      expect(menu.at_css("summary")["aria-label"]).to eq("Actions for Lightning Bolt #{lot.entry.set.code.upcase} · 146 Foil NM")
      expect(menu.css(".c-menu__item").map(&:text)).to eq([ "Edit copy", "Remove" ])
      return_to = collection_path(view: "table")
      expect(menu.css("a").map { |link| link["href"] }).to eq([
        edit_lot_path(lot, from: "collection", return_to:), new_lot_removal_path(lot, from: "collection", return_to:)
      ])
    end

    it "keeps rows of retired printings" do
      own.entry.update!(retired_at: 1.day.ago)
      get collection_path(view: "table")
      expect(rows.size).to eq(1)
    end

    it "shows the empty state and no table for an empty collection", :aggregate_failures do
      get collection_path(view: "table")
      expect(response.body).to include("No cards in your collection yet.")
      expect(response.body).not_to include("c-table")
    end

    describe "sorting" do
      it "links every sortable header and marks Name ascending by default", :aggregate_failures do
        own
        get collection_path(view: "table")
        sortable = page_html.css("table.c-table thead th").select { |th| th.at_css("a.c-table__sort") }
        expect(sortable.map { |th| [ th.text.strip, th["aria-sort"], th.at_css("a")["href"] ] }).to eq([
          [ "Name", "ascending", collection_path(view: "table", sort: "name", dir: "desc") ],
          [ "Set", "none", collection_path(view: "table", sort: "set", dir: "asc") ],
          [ "Condition", "none", collection_path(view: "table", sort: "condition", dir: "asc") ],
          [ "Qty", "none", collection_path(view: "table", sort: "quantity", dir: "asc") ],
          [ "Paid", "none", collection_path(view: "table", sort: "price", dir: "asc") ]
        ])
      end

      it "states the chosen column's direction and reverses it, keeping the filter but not the page", :aggregate_failures do
        own
        get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc", page: 1)
        expect([ header("Paid")["aria-sort"], header("Paid").at_css("a")["href"] ])
          .to eq([ "descending", collection_path(view: "table", q: "bolt", sort: "price", dir: "asc") ])
        expect(header("Name")["aria-sort"]).to eq("none")
      end

      it "keeps the sort when paging and filtering", :aggregate_failures do
        stub_const("CollectionTable::PER_PAGE", 1)
        2.times { |n| own("Card #{n}") }
        get collection_path(view: "table", sort: "quantity", dir: "desc", page: 2)
        expect(page_html.at_css("a[rel=prev]")["href"]).to eq(collection_path(view: "table", sort: "quantity", dir: "desc", page: 1))
        hidden = page_html.css("form.c-filterbar input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
        expect(hidden).to eq("sort" => "quantity", "dir" => "desc")
      end

      it "uses the default order for an unknown sort" do
        own
        get collection_path(view: "table", sort: "bogus", dir: "up")
        expect([ response.status, header("Name")["aria-sort"] ]).to eq([ 200, "ascending" ])
      end

      it "leaves the grid in its own order", :aggregate_failures do
        own("Opt", quantity: 9)
        own("Lightning Bolt", quantity: 1)
        get collection_path(sort: "quantity", dir: "desc")
        expect(page_html.css(".c-grid .c-tile__name").map(&:text)).to eq([ "Lightning Bolt", "Opt" ])
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/collection_table_spec.rb` — expect FAIL (no `table.c-table` rows).
- [ ] Write `app/controllers/concerns/collection_listing.rb`:
  ```ruby
  # Builds the collection page in its views (spec 004 Story 11, spec 006): the grid or the table.
  module CollectionListing
    extend ActiveSupport::Concern

    private
      def prepare_collection(query:, sort:, page:, view:, bulk:, path: request.fullpath)
        @bulk, @sort, @listing_path = bulk, sort, path
        @view = bulk ? "table" : view
        @listing = if @view == "table"
          CollectionTable.new(account: Current.account, query:, page:, sort:)
        else
          CollectionGrid.new(account: Current.account, query:, page:)
        end
      end
  end
  ```
- [ ] Replace `app/controllers/collections_controller.rb`:
  ```ruby
  # The collection page (spec 004 Story 11, spec 006 Story 2): the grid, or the table with ?view=table.
  class CollectionsController < ApplicationController
    include CollectionListing

    def root
      redirect_to collection_path
    end

    def show
      prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
        view: params[:view] == "table" ? "table" : "grid", bulk: false)
    end
  end
  ```
- [ ] Write `app/helpers/collections_helper.rb`:
  ```ruby
  module CollectionsHelper
    # A collection URL with its params in one form (spec 006): the view or bulk mode, the filter, the
    # table's sort and the page (left out on page 1).
    def collection_listing_path(query: nil, sort: nil, page: nil, bulk: nil, view: nil)
      collection_path({ bulk:, view:, q: query.presence, page: (page if page.to_i > 1) }.merge(sort&.to_params || {}).compact)
    end

    # A sortable column header (spec 006 AC-3.2): it states the order, and links to the next one.
    def sort_header(table, column, label, **html)
      url = collection_listing_path(query: table.query, sort: table.sort.toward(column), view: "table")
      tag.th(link_to(label, url, class: "c-table__sort"), "aria-sort": table.sort.aria_sort(column), **html)
    end
  end
  ```
- [ ] Replace `app/helpers/lots_helper.rb`:
  ```ruby
  module LotsHelper
    def lot_error_messages(form, field)
      form.errors.where(field).map { |error| error.message.match?(/\A[A-Z]/) ? error.message : error.full_message }
    end

    # A lot's finish (spec 004 AC-8.5): a special finish as the one badge, any other as muted text, "—" if unspecified.
    def lot_finish(lot)
      return "—" unless lot.finish

      label = lot.vocabulary.finish_label(lot.finish)
      lot.vocabulary.special_finishes.include?(lot.finish) ? render("catalog/entries/finish_badge", label:) : tag.span(label, class: "is-muted")
    end

    def lot_condition(lot) = lot.condition ? lot.vocabulary.conditions.fetch(lot.condition).last : "—"

    def lot_price(lot) = lot.price_paid ? number_to_currency(lot.price_paid, unit: Rails.configuration.x.currency.symbol) : "—"

    # Names a lot for assistive technology: "Lightning Bolt M10 · 146 Foil NM" (spec 006 AC-2.5).
    def lot_label(lot)
      vocabulary = lot.vocabulary
      [ lot.entry.name, set_number(lot.entry), (vocabulary.finish_label(lot.finish) if lot.finish),
        (vocabulary.conditions.fetch(lot.condition).last if lot.condition) ].compact.join(" ")
    end

    # The phone line under a row's name (spec 006 AC-2.8): set · number, finish, condition, language.
    def lot_summary(lot)
      [ set_number(lot.entry), (lot.vocabulary.finish_label(lot.finish) if lot.finish),
        (lot.vocabulary.conditions.fetch(lot.condition).last if lot.condition), lot.entry.language.upcase ].compact.join(" · ")
    end
  end
  ```
- [ ] In `app/views/catalog/entries/_copies.html.erb`, replace the three computed cells with the helpers. Delete the `finish =` and `condition =` ERB lines. The sub line becomes `<%= safe_join([ (lot.finish ? overview.vocabulary.finish_label(lot.finish) : nil), lot_condition(lot), lot.entry.language.upcase ].compact, " · ") %>`, and the cells become:
  ```erb
  <td class="is-opt"><%= lot_finish(lot) %></td>
  <td class="is-data is-opt"><%= lot_condition(lot) %></td>
  <td class="is-data is-opt"><%= lot.entry.language.upcase %></td>
  <td class="is-num"><%= lot.quantity %></td>
  <td class="is-num is-opt"><%= lot_price(lot) %></td>
  ```
  The actions summary becomes `aria-label="Actions for <%= set_number(lot.entry) %> <%= lot_condition(lot) %>"` (unchanged text).
- [ ] Write `app/views/collections/_lot_cells.html.erb`:
  ```erb
  <%# locals: (lot:) %>
  <% entry = lot.entry %>
  <td>
    <div class="c-table__item">
      <% if (image = catalog_url(entry.image_url)) %>
        <%= image_tag image, alt: "", class: "c-table__thumb", loading: "lazy", width: 24, height: 34 %>
      <% else %>
        <span class="c-table__thumb" aria-hidden="true"></span>
      <% end %>
      <div><%= link_to entry.display_name, catalog_entry_path(entry, from: "collection") %><span class="c-table__sub"><%= lot_summary(lot) %></span></div>
    </div>
  </td>
  <td class="is-data is-opt"><%= set_number(entry) %></td>
  <td class="is-data is-opt"><%= entry.language.upcase %></td>
  <td class="is-opt"><%= lot_finish(lot) %></td>
  <td class="is-data is-opt"><%= lot_condition(lot) %></td>
  <td class="is-num"><%= number_with_delimiter(lot.quantity) %></td>
  <td class="is-num is-opt"><%= lot_price(lot) %></td>
  ```
- [ ] Write `app/views/collections/_table.html.erb`:
  ```erb
  <%# locals: (table:, return_to:) %>
  <table class="c-table">
    <thead>
      <tr>
        <%= sort_header table, "name", "Name" %>
        <%= sort_header table, "set", "Set", class: "is-opt" %>
        <th class="is-opt">Language</th>
        <th class="is-opt">Finish</th>
        <%= sort_header table, "condition", "Condition", class: "is-opt" %>
        <%= sort_header table, "quantity", "Qty", class: "is-num" %>
        <%= sort_header table, "price", "Paid", class: "is-num is-opt" %>
        <th><span class="c-sr">Actions</span></th>
      </tr>
    </thead>
    <tbody>
      <% table.lots.each do |lot| %>
        <tr>
          <%= render "collections/lot_cells", lot: %>
          <td class="c-table__actions">
            <details class="c-menu" data-controller="menu">
              <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= lot_label(lot) %>"><%= render "icons/more" %></summary>
              <div class="c-menu__list">
                <%= link_to "Edit copy", edit_lot_path(lot, from: "collection", return_to:), class: "c-menu__item" %>
                <div class="c-menu__sep"></div>
                <%= link_to "Remove", new_lot_removal_path(lot, from: "collection", return_to:), class: "c-menu__item c-menu__item--danger" %>
              </div>
            </details>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
  ```
- [ ] Write `app/views/collections/_filter_bar.html.erb`:
  ```erb
  <%# locals: (listing:, sort:, view:) %>
  <%= form_with url: collection_path, method: :get, class: "c-filterbar", role: "search", data: { controller: "url-sync", turbo_frame: "results", turbo_action: "advance" } do |form| %>
    <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: listing.query, placeholder: "Search your collection", "aria-label": "Search your collection",
          data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
  <% end %>
  ```
- [ ] Replace `app/views/collections/show.html.erb`:
  ```erb
  <% content_for :title, "My collection · Collector" %>
  <%= render "layouts/appbar", section: :collection %>
  <main class="c-main">
    <div class="c-pagehead">
      <div>
        <h1 class="c-pagehead__title">My collection</h1>
        <p class="c-pagehead__stats"><%= number_with_delimiter(@listing.total_quantity) %> <%= "item".pluralize(@listing.total_quantity) %> · <%= number_with_delimiter(@listing.unique_cards) %> unique</p>
      </div>
      <div class="c-pagehead__actions"><%= link_to catalog_entries_path, class: "c-btn c-btn--primary" do %><%= render "icons/plus" %>Add items<% end %></div>
    </div>
    <% if @listing.empty_collection? %>
      <p class="c-empty">No cards in your collection yet. Search for a card to start adding. <%= link_to "Search cards", catalog_entries_path %></p>
    <% else %>
      <div class="c-collection" data-controller="search-shortcut">
        <%= render "collections/filter_bar", listing: @listing, sort: @sort, view: @view %>
        <turbo-frame id="results" target="_top" data-turbo-action="advance">
          <div class="c-results__meta">
            <span class="c-filterbar__count"><%= "#{number_with_delimiter(@listing.matching_quantity)} of " if @listing.filtered? %><%= number_with_delimiter(@listing.total_quantity) %> <%= "item".pluralize(@listing.total_quantity) %></span>
          </div>
          <% if @listing.matching_quantity.zero? %>
            <p class="c-empty">No cards in your collection match "<%= @listing.query %>".</p>
          <% elsif @view == "table" %>
            <%= render "collections/table", table: @listing, return_to: @listing_path %>
            <%= render "catalog/pagination", pagination: @listing.pagination, link_params: { view: "table", q: @listing.query.presence, **@sort.to_params }, frame: "results" %>
          <% else %>
            <div class="c-grid"><%= render partial: "collections/tile", collection: @listing.tiles, as: :tile %></div>
            <%= render "catalog/pagination", pagination: @listing.pagination, link_params: { q: @listing.query.presence, **@sort.to_params }, frame: "results" %>
          <% end %>
        </turbo-frame>
      </div>
    <% end %>
  </main>
  <%= render "layouts/tabbar", section: :collection %>
  ```
- [ ] Append to `app/assets/stylesheets/collector/additions.css`:
  ```css
  /* ---------- Sortable table header (spec 006): a link, or a bulk-form button, with the order's arrow ---------- */
  .c-table__sort { display:inline-flex; align-items:center; gap:var(--space-1); padding:0; border:0; background:none;
    color:inherit; font:inherit; text-decoration:none; cursor:pointer; }
  .c-table__sort:hover { color:var(--brand); }
  .c-table__sort:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
  .c-table th[aria-sort="ascending"] .c-table__sort::after { content:"↑" / ""; }
  .c-table th[aria-sort="descending"] .c-table__sort::after { content:"↓" / ""; }
  .c-table th.is-num .c-table__sort { flex-direction:row-reverse; }
  ```
- [ ] Run: `bin/rspec spec/requests/collection_table_spec.rb spec/requests/collections_spec.rb spec/requests/catalog spec/requests/lots_spec.rb` — expect PASS.
- [ ] Commit: `feat(collection): show the collection as a sortable table of lots`

---

## Phase 3: The view switch and the saved view

**Implements:** FR-1 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5 (non-bulk), AC-1.6, AC-1.7 (AC-11.7 superseded), AC-1.8, AC-1.9, AC-1.10, AC-3.6 (switch), AC-8.5
**Files:** `db/migrate/20260930100001_add_collection_view_to_users.rb`, `app/models/user.rb`, `app/controllers/collections_controller.rb`, `app/views/collections/{show,_filter_bar,_view_switch,_view_forms}.html.erb`, `app/views/icons/{_grid,_table}.html.erb`, `spec/requests/collection_views_spec.rb`, `spec/requests/collections_spec.rb`, `spec/system/collection_views_spec.rb`
**Interfaces:** Consumes: Phase 2. Produces:
- `User::COLLECTION_VIEWS`, `User#collection_view`
- the hidden `form#view-switch` inside `turbo-frame#results`
- `collections/_view_switch` (locals `view:`)
- `collections/_view_forms` (locals `listing:, sort:`)

- [ ] Write `spec/requests/collection_views_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection views", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
    def page_html = Nokogiri::HTML5(response.body)
    def switch = page_html.at_css(".c-filterbar .c-seg[role=group][aria-label=View]")

    it "offers Grid and Table as buttons of the view-switch form, marking the one shown", :aggregate_failures do
      own
      get collection_path
      expect(switch.css("button").map { |b| [ b.text.strip, b["aria-pressed"], b["type"], b["form"], b["name"], b["value"] ] }).to eq([
        [ "Grid", "true", "submit", "view-switch", "view", "grid" ], [ "Table", "false", "submit", "view-switch", "view", "table" ]
      ])
      get collection_path(view: "table")
      expect(switch.css("button[aria-pressed=true]").map { |b| b.text.strip }).to eq([ "Table" ])
    end

    it "submits the switch to the whole page with the current filter and sort", :aggregate_failures do
      own
      get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc")
      form = page_html.at_css("turbo-frame#results form#view-switch")
      expect([ form["method"], form["action"], form["data-turbo-frame"], form.key?("hidden") ]).to eq([ "get", collection_path, "_top", true ])
      expect(form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }).to eq("q" => "bolt", "sort" => "price", "dir" => "desc")
    end

    it "shows the grid to a collector who never chose", :aggregate_failures do
      own
      get collection_path
      expect([ user.reload.collection_view, response.body.include?('class="c-grid"') ]).to eq([ "grid", true ])
    end

    it "saves a chosen view and shows it on later visits, after signing in again", :aggregate_failures do
      own
      get collection_path(view: "table")
      expect(user.reload.collection_view).to eq("table")
      delete session_path
      sign_in_as(user)
      get collection_path
      expect(response.body).to include('<table class="c-table">')
    end

    it "shows the saved view for an unknown view and keeps it", :aggregate_failures do
      own
      user.update!(collection_view: "table")
      get collection_path(view: "carousel")
      expect([ response.status, response.body.include?('<table class="c-table">'), user.reload.collection_view ]).to eq([ 200, true, "table" ])
    end

    it "keeps each collector's choice their own" do
      other = create(:user)
      own
      get collection_path(view: "table")
      expect(other.reload.collection_view).to eq("grid")
    end

    it "never saves a view from a prefetch", :aggregate_failures do
      own
      get collection_path(view: "table"), headers: { "X-Sec-Purpose" => "prefetch" }
      expect(response.body).to include('<table class="c-table">')
      get collection_path(view: "table"), headers: { "Sec-Purpose" => "prefetch;prerender" }
      expect(user.reload.collection_view).to eq("grid")
    end

    it "has no switch and no table on an empty collection, whatever the saved view", :aggregate_failures do
      user.update!(collection_view: "table")
      get collection_path
      expect(response.body).not_to include("c-seg", "c-table")
    end
  end
  ```
- [ ] In `spec/requests/collections_spec.rb`, example "shows stats, tiles and the Add items action", change the last expectation, because spec 006 AC-1.7 supersedes 004 AC-11.7:
  ```ruby
  expect(response.body).not_to include('type="checkbox"')
  ```
- [ ] Write `spec/system/collection_views_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection views", type: :system do
    let(:user) { system_sign_in_as(create(:user)) }

    def prefetches_after_half_a_second
      page.evaluate_async_script("const done = arguments[0]; setTimeout(() => done(window.__prefetches), 500)")
    end

    it "switches to the table, remembers it, and goes back to the grid", :aggregate_failures do
      owned_printing(account: user.account)
      visit collection_path
      click_on "Table"
      expect(page).to have_css("table.c-table")
      expect(page).to have_current_path(collection_path(view: "table"))
      expect(page).to have_css(".c-seg button[aria-pressed=true]", text: "Table")
      wait_for_turbo_idle
      page.go_back
      expect(page).to have_current_path(collection_path)
      visit collection_path
      expect(page).to have_css("table.c-table")
    end

    it "doesn't save a view the collector only points at", :aggregate_failures do
      owned_printing(account: user.account)
      visit collection_path
      page.execute_script("window.__prefetches = 0; document.addEventListener('turbo:before-prefetch', () => window.__prefetches++)")
      find(".c-appbar__nav a", text: "Search").hover
      expect(prefetches_after_half_a_second).to be > 0
      page.execute_script("window.__prefetches = 0")
      find(".c-seg button", text: "Table").hover
      expect(prefetches_after_half_a_second).to eq(0)
      expect(user.reload.collection_view).to eq("grid")
    end

    it "shows the switch as icons with names on a phone", :aggregate_failures do
      owned_printing(account: user.account)
      visit collection_path
      expect(open_in_narrow_frame(collection_path, width: 390, height: 844, ready: ".c-seg")).to eq([ 390, true ])
      within_narrow_frame do
        widths = page.evaluate_script("[...document.querySelectorAll('.c-seg__label')].map((label) => label.getBoundingClientRect().width)")
        expect(widths).to all(be <= 1)
        expect(page).to have_button("Grid")
        expect(page).to have_button("Table")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/collection_views_spec.rb spec/system/collection_views_spec.rb` — expect FAIL (no `.c-seg`).
- [ ] Write the migration `db/migrate/20260930100001_add_collection_view_to_users.rb`:
  ```ruby
  class AddCollectionViewToUsers < ActiveRecord::Migration[8.1]
    def change
      add_column :users, :collection_view, :string, null: false, default: "grid"
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate` — expect `db/schema.rb` to gain `t.string "collection_view", default: "grid", null: false` on `users`.
- [ ] In `app/models/user.rb`, add after `EMAIL_FORMAT`:
  ```ruby
  COLLECTION_VIEWS = %w[grid table].freeze
  ```
  and after the password validation:
  ```ruby
  validates :collection_view, inclusion: { in: COLLECTION_VIEWS }
  ```
- [ ] Replace `app/controllers/collections_controller.rb`:
  ```ruby
  # The collection page (spec 004 Story 11, spec 006): the grid or the table, by the URL's view or the
  # collector's saved one.
  class CollectionsController < ApplicationController
    include CollectionListing

    def root
      redirect_to collection_path
    end

    def show
      remember_view
      prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
        view: requested_view || Current.user.collection_view, bulk: false)
    end

    private
      def requested_view = params[:view].presence_in(User::COLLECTION_VIEWS)

      # A page naming a view saves it as the collector's choice (spec 006 AC-1.3), unless the browser
      # only prefetched it: nobody chose that (AC-1.10, FR-1).
      def remember_view
        return if requested_view.nil? || prefetch? || Current.user.collection_view == requested_view

        Current.user.update!(collection_view: requested_view)
      end

      def prefetch?
        [ request.headers["Sec-Purpose"], request.headers["X-Sec-Purpose"] ].compact.any? { |purpose| purpose.include?("prefetch") }
      end
  end
  ```
- [ ] Write `app/views/icons/_grid.html.erb`:
  ```erb
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>
  ```
  and `app/views/icons/_table.html.erb`:
  ```erb
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="1"/><path d="M3 9h18M3 14.5h18M9 9v11"/></svg>
  ```
- [ ] Write `app/views/collections/_view_switch.html.erb`:
  ```erb
  <%# locals: (view:) %>
  <div class="c-seg" role="group" aria-label="View">
    <% { "grid" => "Grid", "table" => "Table" }.each do |value, label| %>
      <%= button_tag type: "submit", form: "view-switch", name: "view", value:, "aria-pressed": (value == view).to_s do %><%= render "icons/#{value}" %><span class="c-seg__label"><%= label %></span><% end %>
    <% end %>
  </div>
  ```
- [ ] Write `app/views/collections/_view_forms.html.erb`:
  ```erb
  <%# locals: (listing:, sort:) %>
  <%# The form the filter bar's view switch submits (spec 006 FR-1). It sits in the results frame, so it always carries the current filter. %>
  <%= tag.form id: "view-switch", action: collection_path, method: "get", hidden: true, data: { turbo_frame: "_top" } do %>
    <% if listing.query.present? %><%= hidden_field_tag :q, listing.query, id: nil %><% end %>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
  <% end %>
  ```
- [ ] Replace `app/views/collections/_filter_bar.html.erb`:
  ```erb
  <%# locals: (listing:, sort:, view:) %>
  <%= form_with url: collection_path, method: :get, class: "c-filterbar", role: "search", data: { controller: "url-sync", turbo_frame: "results", turbo_action: "advance" } do |form| %>
    <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: listing.query, placeholder: "Search your collection", "aria-label": "Search your collection",
          data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
    <div class="c-filterbar__end"><%= render "collections/view_switch", view: %></div>
  <% end %>
  ```
- [ ] In `app/views/collections/show.html.erb`, add as the first line inside `<turbo-frame id="results" …>`:
  ```erb
  <%= render "collections/view_forms", listing: @listing, sort: @sort %>
  ```
- [ ] Run: `bin/rspec spec/requests/collection_views_spec.rb spec/requests/collections_spec.rb spec/requests/collection_table_spec.rb spec/system/collection_views_spec.rb spec/system/collection_spec.rb` — expect PASS.
- [ ] Commit: `feat(collection): switch between grid and table and remember the choice`

---

## Phase 4: Row actions return to the table

**Implements:** FR-2 (row actions) | **Satisfies:** AC-2.6, AC-1.7 (return target), Error Scenarios (return path off-instance)
**Files:** `app/controllers/concerns/card_context.rb`, `app/controllers/lots_controller.rb`, `app/views/lots/{edit,_form}.html.erb`, `app/views/lots/removals/new.html.erb`, `spec/requests/lots_spec.rb`
**Interfaces:** Consumes: Phase 2's row-menu links (`return_to:`). Produces: `CardContext#lot_return_path(entry)` and `#lot_return_params` (helper methods).

- [ ] Append to `spec/requests/lots_spec.rb`, inside the top-level `describe`:
  ```ruby
  describe "from the collection table" do
    let(:table) { collection_path(view: "table", q: "bolt", sort: "price", dir: "desc", page: 2) }
    let(:lot) { create(:lot, account: user.account, entry:) }

    it "returns to the table after saving, or from Cancel and Back", :aggregate_failures do
      get edit_lot_path(lot, from: "collection", return_to: table)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css('header a[aria-label="Back"]')["href"]).to eq(table)
      expect(page.at_css("form.c-form")["action"]).to eq(lot_path(lot, from: "collection", return_to: table))
      expect(page.at_css(".c-form__actions a")["href"]).to eq(table)
      patch lot_path(lot, from: "collection", return_to: table), params: { lot: { quantity: 2 } }
      expect(response).to redirect_to(table)
      follow_redirect!
      expect(response.body).to include("Saved.")
    end

    it "returns to the table after removing, or from Cancel and Back", :aggregate_failures do
      get new_lot_removal_path(lot, from: "collection", return_to: table)
      page = Nokogiri::HTML5(response.body)
      expect(page.at_css('header a[aria-label="Back"]')["href"]).to eq(table)
      expect(page.at_css(".c-confirm a.c-btn--secondary")["href"]).to eq(table)
      expect(page.at_css(".c-confirm form")["action"]).to eq(lot_path(lot, from: "collection", return_to: table))
      delete lot_path(lot, from: "collection", return_to: table)
      expect(response).to redirect_to(table)
      expect(flash[:notice]).to eq("Removed 1 × Lightning Bolt (#{entry.set.code.upcase} · 146) from your collection.")
    end

    it "ignores a return path off this instance", :aggregate_failures do
      patch lot_path(lot, return_to: "https://elsewhere.example/collection"), params: { lot: { quantity: 2 } }
      expect(response).to redirect_to(catalog_entry_path(entry))
      get edit_lot_path(lot, return_to: "https://elsewhere.example/collection")
      expect(Nokogiri::HTML5(response.body).at_css("form.c-form")["action"]).to eq(lot_path(lot))
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/lots_spec.rb` — expect FAIL (Back still goes to the card page).
- [ ] Replace `app/controllers/concerns/card_context.rb`:
  ```ruby
  # Where the collector came from (spec 004 AC-8.9, FR-13): collection links carry from=collection;
  # everything else is Search. Return paths are followed only when they're on this instance (AC-7.3).
  module CardContext
    extend ActiveSupport::Concern

    included { helper_method :card_context, :card_params, :lot_return_path, :lot_return_params }

    private
      def card_context = params[:from] == "collection" ? :collection : :search

      def card_params = card_context == :collection ? { from: "collection" } : {}

      def safe_return_to(fallback) = url_from(params[:return_to]) || fallback

      # Where a lot's edit and removal pages go back to: the collection table they came from (spec 006
      # AC-2.6), or the card page.
      def lot_return_path(entry) = safe_return_to(catalog_entry_path(entry, **card_params))

      # The return path, for a lot page's forms to carry on, when it's one to follow.
      def lot_return_params = url_from(params[:return_to]) ? { return_to: params[:return_to] } : {}
  end
  ```
- [ ] In `app/controllers/lots_controller.rb`, change the redirect target of `update` to `lot_return_path(@lot.entry)`, and of `destroy` to `lot_return_path(@lot.entry)`. Both keep `status: :see_other` and their notices.
- [ ] Replace `app/views/lots/edit.html.erb`:
  ```erb
  <% content_for :title, "Edit #{@lot.entry.name} · Collector" %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: lot_return_path(@lot.entry) %>
  <main class="c-main c-page">
    <div class="c-pagehead">
      <div>
        <h1 class="c-pagehead__title">Edit copy</h1>
        <p class="c-pagehead__stats"><%= @lot.entry.name %> · <%= set_number(@lot.entry) %> · <%= @lot.entry.language.upcase %></p>
      </div>
    </div>
    <%= render "lots/form", form_model: @form, url: lot_path(@lot, **card_params, **lot_return_params), method: :patch, submit: "Save" %>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
- [ ] In `app/views/lots/_form.html.erb`, change the Cancel link to `<%= link_to "Cancel", lot_return_path(entry), class: "c-btn c-btn--secondary" %>`.
- [ ] Replace `app/views/lots/removals/new.html.erb`:
  ```erb
  <% content_for :title, "Remove copies · Collector" %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: lot_return_path(@lot.entry) %>
  <main class="c-main c-page">
    <section class="c-confirm">
      <h1 class="c-pagehead__title">Remove <%= @lot.quantity %> × <%= @lot.entry.name %>?</h1>
      <p><%= set_number(@lot.entry) %> · <%= @lot.entry.language.upcase %>. This removes the whole lot from your collection.</p>
      <div class="c-form__actions">
        <%= button_to "Remove", lot_path(@lot, **card_params, **lot_return_params), method: :delete, class: "c-btn c-btn--danger" %>
        <%= link_to "Cancel", lot_return_path(@lot.entry), class: "c-btn c-btn--secondary" %>
      </div>
    </section>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
- [ ] Run: `bin/rspec spec/requests/lots_spec.rb spec/requests/catalog` — expect PASS.
- [ ] Commit: `feat(lots): return to the collection table from a row's edit and removal`

---

## Phase 5: The bulk selection model

**Implements:** FR-4 (storage) | **Satisfies:** AC-5.3 (storage), AC-5.4, AC-5.5, AC-5.6 (restart), AC-8.1 (record), AC-8.2, Reliability (cascade)
**Files:** `db/migrate/20260930100002_create_bulk_selections.rb`, `app/models/bulk_selection.rb`, `app/models/bulk_selection/mark.rb`, `app/models/session.rb`, `spec/models/bulk_selection_spec.rb`
**Interfaces:** Consumes: `CollectionFilter.lots`, `CollectionTable::Sort`. Produces:
- `BulkSelection.for(session)`
- `#sort #context?(query, sort) #lots #copies #everything? #restart!(query:, sort:) #record!(shown_ids:, ticked_ids:, header_rendered:, header_ticked:)`
- `BulkSelection::NOTHING_SELECTED`, `::NONE_LEFT`
- `Session#bulk_selection`

- [ ] Write `spec/models/bulk_selection_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe BulkSelection, type: :model do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:default_sort) { CollectionTable::Sort.parse(nil, nil) }
    let(:selection) { described_class.for(user.sessions.create!) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)

    def tick(shown, ticked, header_rendered: false, header_ticked: false)
      selection.record!(shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id), header_rendered:, header_ticked:)
    end

    it "starts empty under the default filter and sort", :aggregate_failures do
      own
      expect([ selection.lots.to_a, selection.copies, selection.context?("", default_sort) ]).to eq([ [], 0, true ])
    end

    it "selects shown-and-ticked lots and unselects shown-and-unticked ones, across pages" do
      a, b, c = [ "Card A", "Card B", "Card C" ].map { |name| own(name) }
      tick([ a, b ], [ a, b ])
      tick([ b, c ], [ c ])
      expect(selection.lots).to contain_exactly(a, c)
    end

    it "selects every matching lot from the header, keeps unticks as exceptions and clears from the header", :aggregate_failures do
      a = own("Bolt A", quantity: 2)
      b = own("Bolt B", quantity: 3)
      own("Opt")
      selection.restart!(query: "bolt", sort: default_sort)
      tick([ a ], [], header_ticked: true)
      expect(selection.lots).to contain_exactly(a, b)
      expect([ selection.copies, selection.everything? ]).to eq([ 5, true ])
      tick([ a ], [], header_rendered: true, header_ticked: true)
      expect([ selection.lots.to_a, selection.copies, selection.everything? ]).to eq([ [ b ], 3, false ])
      tick([ a, b ], [ a, b ], header_rendered: true, header_ticked: false)
      expect(selection.lots).to be_empty
    end

    it "ignores ids that aren't the account's matching lots" do
      mine = own
      theirs = owned_printing(account: create(:user).account)
      tick([ mine, theirs ], [ mine, theirs ])
      expect(selection.marks.pluck(:lot_id)).to eq([ mine.id ])
    end

    it "starts over under a new filter and sort", :aggregate_failures do
      lot = own
      tick([ lot ], [ lot ])
      by_price = CollectionTable::Sort.parse("price", "desc")
      selection.restart!(query: "bolt", sort: by_price)
      expect([ selection.lots.to_a, selection.context?("bolt", by_price), selection.context?("", default_sort) ]).to eq([ [], true, false ])
      expect(selection.sort.to_params).to eq(sort: "price", dir: "desc")
    end

    it "drops a mark when its lot is removed" do
      lot = own
      tick([ lot ], [ lot ])
      lot.destroy!
      expect(selection.marks).to be_empty
    end

    it "goes with its session however the session ends", :aggregate_failures do
      lot = own
      tick([ lot ], [ lot ])
      user.end_sessions!
      expect([ described_class.count, BulkSelection::Mark.count ]).to eq([ 0, 0 ])
    end

    it "keeps an indexed account key on its tables and cascades from sessions", :aggregate_failures do
      connection = described_class.connection
      %w[bulk_selections bulk_selection_marks].each do |table|
        expect(connection.columns(table).find { |column| column.name == "account_id" }.null).to be(false)
        expect(connection.foreign_keys(table).map(&:to_table)).to include("accounts")
        expect(connection.indexes(table).map(&:columns)).to include(a_collection_starting_with("account_id"))
      end
      expect(connection.foreign_keys("bulk_selections").find { |key| key.to_table == "sessions" }.on_delete).to eq(:cascade)
      expect(connection.foreign_keys("bulk_selection_marks").find { |key| key.to_table == "lots" }.on_delete).to eq(:cascade)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/bulk_selection_spec.rb` — expect FAIL (uninitialized constant `BulkSelection`).
- [ ] Write `db/migrate/20260930100002_create_bulk_selections.rb`:
  ```ruby
  class CreateBulkSelections < ActiveRecord::Migration[8.1]
    def change
      create_table :bulk_selections do |t|
        t.references :session, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
        t.references :account, null: false, foreign_key: { on_delete: :cascade }
        t.string :query, null: false, default: ""
        t.string :sort_key, null: false, default: ""
        t.boolean :all_matching, null: false, default: false
        t.timestamps
      end

      create_table :bulk_selection_marks do |t|
        t.references :bulk_selection, null: false, foreign_key: { on_delete: :cascade }, index: false
        t.references :account, null: false, foreign_key: { on_delete: :cascade }
        t.references :lot, null: false, foreign_key: { on_delete: :cascade }
        t.index %i[bulk_selection_id lot_id], unique: true
      end
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate` — expect both tables in `db/schema.rb`, with `add_foreign_key … on_delete: :cascade` lines.
- [ ] Write `app/models/bulk_selection/mark.rb`:
  ```ruby
  # One lot marked in a bulk selection: selected, or excepted from "every matching lot" (spec 006 FR-4).
  class BulkSelection::Mark < ApplicationRecord
    belongs_to :bulk_selection
    belongs_to :account
    belongs_to :lot
  end
  ```
- [ ] Write `app/models/bulk_selection.rb`:
  ```ruby
  # The lots a collector has ticked in bulk mode (spec 006 FR-4), kept for their session and tied to the
  # filter and sort they were ticked under. Normally the marks are the selected lots; once "Select all"
  # is ticked, every matching lot is selected and the marks are the exceptions.
  class BulkSelection < ApplicationRecord
    NOTHING_SELECTED = "Select at least one item.".freeze
    NONE_LEFT = "None of the selected items are in your collection any more.".freeze

    belongs_to :session
    belongs_to :account
    has_many :marks, class_name: "BulkSelection::Mark", dependent: :delete_all

    def self.for(session) = find_or_create_by!(session:) { |selection| selection.account = session.user.account }

    def sort = CollectionTable::Sort.from_key(sort_key)
    def context?(query, sort) = self.query == query && sort_key == sort.key

    # The selected lots, always within the account and the filter (AC-8.1, AC-8.2).
    def lots
      matching = CollectionFilter.lots(account, query)
      all_matching? ? matching.where.not(id: marks.select(:lot_id)) : matching.where(id: marks.select(:lot_id))
    end

    def copies = lots.sum(:quantity)
    def everything? = all_matching? && marks.none?

    # Empty again, under a filter and sort: Edit many, a changed filter or sort, a removal (FR-4, AC-7.3).
    # The marks are this selection's own rows, so deleting them in SQL skips nothing.
    def restart!(query:, sort:)
      transaction do
        marks.delete_all
        update!(query:, sort_key: sort.key, all_matching: false)
      end
    end

    # Records one page's ticks (FR-4). The header acts only when it changed from how it was rendered:
    # ticked, it selects every matching lot; unticked, it clears. Otherwise the shown rows decide.
    # Shown ids outside the account's matching lots are ignored (AC-8.1).
    def record!(shown_ids:, ticked_ids:, header_rendered:, header_ticked:)
      transaction do
        if header_ticked != header_rendered
          marks.delete_all
          update!(all_matching: header_ticked)
        else
          shown = CollectionFilter.lots(account, query).where(id: shown_ids).pluck(:id)
          marks.where(lot_id: shown).delete_all
          mark!(all_matching? ? shown - ticked_ids : shown & ticked_ids)
        end
      end
    end

    private
      def mark!(lot_ids)
        marks.insert_all(lot_ids.map { |lot_id| { lot_id:, account_id: } }) if lot_ids.any?
      end
  end
  ```
- [ ] Replace `app/models/session.rb`:
  ```ruby
  class Session < ApplicationRecord
    belongs_to :user
    # The database removes this with the session (ON DELETE CASCADE): sessions also end through
    # delete_all (User#end_sessions!, user deletion), which runs no callbacks (spec 006 FR-4).
    has_one :bulk_selection
  end
  ```
- [ ] Run: `bin/rspec spec/models/bulk_selection_spec.rb spec/models/user_spec.rb spec/models/lot_spec.rb && bin/rails zeitwerk:check` — expect PASS.
- [ ] Commit: `feat(collection): store bulk selections per session`

---

## Phase 6: Bulk mode: Edit many, the bulk form, selecting and Done

**Implements:** FR-4, FR-5 (nothing selected) | **Satisfies:** AC-1.5 (bulk URL), AC-1.9 (Edit many), AC-3.6 (bulk), AC-4.1, AC-4.2, AC-4.3, AC-4.4 (markup), AC-4.5, AC-4.7, AC-4.8, AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.5, AC-5.6, AC-5.7, AC-5.9, AC-8.1, AC-8.4
**Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`, `app/controllers/concerns/collection_listing.rb`, `app/controllers/collections_controller.rb`, `app/controllers/collections/selections_controller.rb`, `app/models/collection_table/selection_state.rb`, `app/helpers/collections_helper.rb`, `app/views/collections/{show,_filter_bar,_view_switch,_view_forms,_table,_bulk,_bulk_pager}.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/bulk_mode_spec.rb`, `spec/models/collection_table/selection_state_spec.rb`
**Interfaces:** Consumes: Phases 1–5. Produces:
- routes `collection_selection_path` (POST create = Edit many; PATCH update = the bulk form), `new_collection_condition_change_path`, `collection_condition_change_path`, `new_collection_bulk_removal_path`, `collection_bulk_removals_path`, `collection_bulk_removal_undo_path(id)` (their controllers come in Phases 8–9)
- `CollectionListing#prepare_collection_at(path)` and `#render_collection_refusal(message)`
- `CollectionTable::SelectionState.new(table:, selection:)` with `#all? #everything? #copies #selected?(lot) #copies_off_page`
- `items_count(n)` and `selection_count(state, matching)`
- the bulk form's fields: `q` (filter), `rendered_q`, `sort`, `dir`, `page`, `all_rendered`, `all`, `shown_ids[]`, `ticked_ids[]`, `go`

- [ ] Add to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes bulk mode's selection", :aggregate_failures do
    expect(post: "/collection/selection").to route_to("collections/selections#create")
    expect(patch: "/collection/selection").to route_to("collections/selections#update")
  end
  ```
- [ ] Write `spec/models/collection_table/selection_state_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe CollectionTable::SelectionState, type: :model do
    let(:user) { create(:user) }
    let(:selection) { BulkSelection.for(user.sessions.create!) }

    def table(query: "", page: nil)
      CollectionTable.new(account: user.account, query:, page:, sort: CollectionTable::Sort.parse(nil, nil))
    end

    it "reports ticked rows and the copies selected off this page", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      first = owned_printing("Card A", account: user.account, quantity: 2)
      second = owned_printing("Card B", account: user.account, quantity: 5)
      selection.record!(shown_ids: [ first.id, second.id ], ticked_ids: [ first.id, second.id ], header_rendered: false, header_ticked: false)
      state = described_class.new(table: table, selection:)
      expect([ state.selected?(first), state.copies, state.copies_off_page, state.all? ]).to eq([ true, 7, 5, false ])
    end

    it "shows a selection made under another filter as nothing", :aggregate_failures do
      lot = owned_printing(account: user.account)
      selection.record!(shown_ids: [ lot.id ], ticked_ids: [ lot.id ], header_rendered: false, header_ticked: false)
      state = described_class.new(table: table(query: "bolt"), selection:)
      expect([ state.selected?(lot), state.copies, state.copies_off_page ]).to eq([ false, 0, 0 ])
    end
  end
  ```
- [ ] Write `spec/requests/bulk_mode_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Bulk mode", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
    def page_html = Nokogiri::HTML5(response.body)
    def count_text = page_html.at_css(".c-bulkbar__count").text
    def ticked = page_html.css("tbody input[name='ticked_ids[]'][checked]").map { |box| box["value"].to_i }

    def start_bulk(**params)
      post collection_selection_path, params: params.compact
      follow_redirect!
    end

    def submit_bulk(go:, shown: [], ticked: [], all: false, all_rendered: false, q: "", rendered_q: q, sort: nil, dir: nil, page: nil)
      params = { go:, shown_ids: shown.map(&:id), ticked_ids: ticked.map(&:id), q:, rendered_q:, sort:, dir:, page:,
        all_rendered: all_rendered ? "1" : "0" }
      params[:all] = "1" if all
      patch collection_selection_path, params: params.compact
    end

    describe "entering" do
      it "offers Edit many in the filter bar and its narrow menu, from the grid and the table", :aggregate_failures do
        own
        [ collection_path, collection_path(view: "table") ].each do |path|
          get path
          expect(page_html.css(".c-filterbar button[form=edit-many]").map { |button| [ button.text, button["class"] ] }).to eq([
            [ "Edit many", "c-btn c-btn--secondary c-btn--sm c-filterbar__bulk" ], [ "Edit many", "c-menu__item" ]
          ])
          form = page_html.at_css("turbo-frame#results form#edit-many")
          expect([ form["method"], form["action"], form["data-turbo-frame"] ]).to eq([ "post", collection_selection_path, "_top" ])
        end
      end

      it "carries the filter and sort into Edit many", :aggregate_failures do
        own
        get collection_path(view: "table", q: "bolt", sort: "price", dir: "desc")
        fields = page_html.css("form#edit-many input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
        expect(fields.except("authenticity_token")).to eq("q" => "bolt", "sort" => "price", "dir" => "desc")
      end

      it "opens the table in bulk mode with the same filter and sort and nothing selected", :aggregate_failures do
        bolt = own("Lightning Bolt", quantity: 3)
        own("Opt")
        post collection_selection_path, params: { q: "bolt", sort: "price", dir: "desc" }
        expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt", sort: "price", dir: "desc"))
        follow_redirect!
        expect(page_html.css("tbody input[name='ticked_ids[]']").map { |box| [ box["value"].to_i, box["checked"] ] }).to eq([ [ bolt.id, nil ] ])
        expect(page_html.at_css("thead input[name=all]")["aria-label"]).to eq("Select all")
        expect(count_text).to eq("0 of 3 selected")
        expect(page_html.css(".c-bulkbar__extra button").map { |button| [ button.text, button["value"], button["class"] ] }).to eq([
          [ "Set condition…", "set_condition", "c-btn c-btn--secondary c-btn--sm" ], [ "Remove", "remove", "c-btn c-btn--danger c-btn--sm" ]
        ])
        expect(page_html.css(".c-bulkbar__more .c-menu__item").map { |button| button["value"] }).to eq(%w[set_condition remove])
        expect(page_html.at_css(".c-bulkbar > button[value=done]")["class"]).to eq("c-btn c-btn--primary c-btn--sm")
        expect(page_html.css("td.c-table__actions")).to be_empty
      end

      it "clears an earlier selection" do
        lot = own
        start_bulk
        submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
        start_bulk
        expect(count_text).to eq("0 of 1 selected")
      end

      it "shows the table in bulk mode even when the URL names the grid" do
        own
        get collection_path(bulk: 1, view: "grid")
        expect(response.body).to include('<table class="c-table">')
      end

      it "shows the empty state, with no bulk bar, on an empty collection" do
        get collection_path(bulk: 1)
        expect([ response.body.include?("No cards in your collection yet."), response.body.include?("c-bulkbar") ]).to eq([ true, false ])
      end
    end

    describe "the bulk page" do
      it "makes the view switch inert and keeps it out of the bulk form", :aggregate_failures do
        own
        start_bulk
        seg = page_html.at_css(".c-seg")
        expect(seg.css("button").map { |b| [ b.text.strip, b["type"], b["aria-pressed"], b.key?("disabled"), b["form"] ] }).to eq([
          [ "Grid", "button", "false", true, nil ], [ "Table", "button", "true", false, nil ]
        ])
        expect(seg.ancestors("form")).to be_empty
      end

      it "makes Filter the form's default submit, and keeps url-sync off it", :aggregate_failures do
        own
        start_bulk
        submitters = page_html.css("button[form=bulk], form#bulk button[type=submit]")
        expect([ submitters.first["value"], submitters.first["tabindex"] ]).to eq([ "filter", "-1" ])
        expect(page_html.at_css("input[name=q]")["form"]).to eq("bulk")
        expect(page_html.at_css("form#bulk")["data-controller"]).to be_nil
      end

      it "sorts with buttons of the bulk form that keep bulk mode", :aggregate_failures do
        own
        start_bulk
        name = page_html.css("thead th").find { |th| th.text.strip == "Name" }
        expect([ name.at_css("button")["name"], name.at_css("button")["value"] ]).to eq([ "go", collection_path(bulk: 1, sort: "name", dir: "desc") ])
      end

      it "has no checkboxes or bulk bar outside bulk mode" do
        own
        get collection_path(view: "table")
        expect([ page_html.css("input[type=checkbox]").size, page_html.css(".c-bulkbar").size ]).to eq([ 0, 0 ])
      end

      it "counts nothing when the filter matches nothing", :aggregate_failures do
        own
        start_bulk(q: "zzz")
        expect(response.body).to include(%(No cards in your collection match "zzz".))
        expect([ count_text, page_html.css("thead input[name=all]").size ]).to eq([ "0 of 0 selected", 0 ])
      end
    end

    describe "selecting" do
      it "counts the selected copies against the filter's, with digit grouping", :aggregate_failures do
        big = own("Lightning Bolt", quantity: 1_200)
        small = own("Opt", quantity: 3)
        start_bulk
        submit_bulk(go: "filter", shown: [ big, small ], ticked: [ big ])
        follow_redirect!
        expect([ count_text, ticked ]).to eq([ "1,200 of 1,203 selected", [ big.id ] ])
        expect(page_html.at_css("tr:has(input[value='#{big.id}'])")["aria-selected"]).to eq("true")
      end

      it "keeps ticks across pages and after a reload", :aggregate_failures do
        stub_const("CollectionTable::PER_PAGE", 1)
        first = own("Card A")
        second = own("Card B", quantity: 2)
        start_bulk
        submit_bulk(go: collection_path(bulk: 1, page: 2), shown: [ first ], ticked: [ first ], page: 1)
        expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
        follow_redirect!
        expect([ count_text, ticked ]).to eq([ "1 of 3 selected", [] ])
        submit_bulk(go: collection_path(bulk: 1), shown: [ second ], ticked: [ second ], page: 2)
        follow_redirect!
        expect([ count_text, ticked ]).to eq([ "3 of 3 selected", [ first.id ] ])
        get collection_path(bulk: 1)
        expect(ticked).to eq([ first.id ])
      end

      it "selects every matching lot from the header and keeps an untick as an exception", :aggregate_failures do
        stub_const("CollectionTable::PER_PAGE", 1)
        first = own("Bolt A", quantity: 2)
        second = own("Bolt B", quantity: 3)
        own("Opt")
        start_bulk(q: "bolt")
        submit_bulk(go: "filter", q: "bolt", shown: [ first ], all: true)
        follow_redirect!
        expect([ count_text, ticked, page_html.at_css("thead input[name=all]").key?("checked") ]).to eq([ "All 5 items selected", [ first.id ], true ])
        submit_bulk(go: "filter", q: "bolt", shown: [ first ], all: true, all_rendered: true)
        follow_redirect!
        expect([ count_text, ticked, page_html.at_css("input[name=all_rendered]")["value"] ]).to eq([ "3 of 5 selected", [], "1" ])
        submit_bulk(go: collection_path(bulk: 1, q: "bolt", page: 2), q: "bolt", shown: [ first ], all: true, all_rendered: true)
        follow_redirect!
        expect(ticked).to eq([ second.id ])
        submit_bulk(go: "filter", q: "bolt", shown: [ second ], ticked: [ second ], all_rendered: true, page: 2)
        follow_redirect!
        expect(count_text).to eq("0 of 5 selected")
      end

      it "clears the selection when the filter or sort changes", :aggregate_failures do
        lot = own
        start_bulk
        submit_bulk(go: "filter", q: "light", rendered_q: "", shown: [ lot ], ticked: [ lot ])
        expect(response).to redirect_to(collection_path(bulk: 1, q: "light"))
        follow_redirect!
        expect(count_text).to eq("0 of 1 selected")
        submit_bulk(go: "filter", q: "light", shown: [ lot ], ticked: [ lot ])
        submit_bulk(go: collection_path(bulk: 1, q: "light", sort: "price", dir: "asc"), q: "light", shown: [ lot ], ticked: [ lot ])
        follow_redirect!
        expect(count_text).to eq("0 of 1 selected")
      end

      it "reloads the same page for an unchanged filter, keeping the ticks", :aggregate_failures do
        stub_const("CollectionTable::PER_PAGE", 1)
        own("Card A")
        second = own("Card B")
        start_bulk
        submit_bulk(go: "filter", shown: [ second ], ticked: [ second ], page: 2)
        expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
      end

      it "never changes the selection on a page load, and shows a selection from another filter as nothing", :aggregate_failures do
        lot = own
        start_bulk
        submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
        get collection_path(bulk: 1, q: "bolt")
        expect(count_text).to eq("0 of 1 selected")
        get collection_path(bulk: 1)
        expect(ticked).to eq([ lot.id ])
      end

      it "ignores another account's lots and account or user values", :aggregate_failures do
        mine = own
        theirs = owned_printing(account: create(:user).account)
        start_bulk
        patch collection_selection_path, params: { go: "filter", q: "", rendered_q: "", all_rendered: "0",
          shown_ids: [ mine.id, theirs.id ], ticked_ids: [ mine.id, theirs.id ], account_id: theirs.account_id, user_id: 1 }
        follow_redirect!
        expect(count_text).to eq("1 of 1 selected")
        expect(BulkSelection.sole.account).to eq(user.account)
      end
    end

    describe "actions and Done" do
      it "refuses an action with nothing selected, re-rendering the bulk table", :aggregate_failures do
        lot = own
        start_bulk
        submit_bulk(go: "remove", shown: [ lot ])
        expect(response).to have_http_status(:unprocessable_content)
        expect(page_html.at_css(".c-status__message--alert").text).to eq("Select at least one item.")
        expect(page_html.at_css("form#bulk")).to be_present
      end

      it "refuses an action whose ticks are all gone or not the account's" do
        theirs = owned_printing(account: create(:user).account)
        own
        start_bulk
        submit_bulk(go: "set_condition", shown: [ theirs ], ticked: [ theirs ])
        expect(page_html.at_css(".c-status__message--alert").text).to eq("None of the selected items are in your collection any more.")
      end

      it "goes to the action's page with the page number", :aggregate_failures do
        lot = own
        start_bulk
        submit_bulk(go: "set_condition", shown: [ lot ], ticked: [ lot ], page: 1)
        expect(response).to redirect_to(new_collection_condition_change_path(page: 1))
        submit_bulk(go: "remove", shown: [ lot ], ticked: [ lot ], page: 1)
        expect(response).to redirect_to(new_collection_bulk_removal_path(page: 1))
      end

      it "leaves bulk mode on Done for the saved view, with the filter and sort, discarding the selection", :aggregate_failures do
        lot = own
        user.update!(collection_view: "grid")
        start_bulk(q: "bolt", sort: "price", dir: "asc")
        submit_bulk(go: "done", q: "bolt", sort: "price", dir: "asc", shown: [ lot ], ticked: [ lot ])
        expect(response).to redirect_to(collection_path(q: "bolt", sort: "price", dir: "asc"))
        expect([ BulkSelection.count, user.reload.collection_view ]).to eq([ 0, "grid" ])
        follow_redirect!
        expect(response.body).to include('class="c-grid"')
      end

      it "keeps the selection when bulk mode is left any other way, until the next Edit many", :aggregate_failures do
        lot = own
        start_bulk
        submit_bulk(go: "filter", shown: [ lot ], ticked: [ lot ])
        get collection_path
        get collection_path(bulk: 1)
        expect(ticked).to eq([ lot.id ])
        start_bulk
        expect(ticked).to eq([])
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/collection_table/selection_state_spec.rb spec/requests/bulk_mode_spec.rb` — expect FAIL (no route `/collection/selection`).
- [ ] In `config/routes.rb`, replace `resource :collection, only: :show` with:
  ```ruby
  resource :collection, only: :show do
    scope module: :collections do
      resource :selection, only: %i[create update]
      resource :condition_change, only: %i[new create]
      resources :bulk_removals, only: %i[new create] do
        resource :undo, only: :create, module: :bulk_removals
      end
    end
  end
  ```
- [ ] Write `app/models/collection_table/selection_state.rb`:
  ```ruby
  # How a bulk-mode page shows the session's selection (spec 006 Story 5): which rows are ticked, the
  # header and the count. A selection made under another filter or sort shows as nothing (FR-4).
  class CollectionTable::SelectionState
    def initialize(table:, selection:)
      @table = table
      @selection = selection if selection&.context?(table.query, table.sort)
    end

    def all? = @selection&.all_matching? || false
    def everything? = @selection&.everything? || false
    def copies = @selection ? @selection.copies : 0
    def selected?(lot) = selected_ids.include?(lot.id)

    # Selected copies not on this page: the live count adds this page's ticks to it (AC-5.8).
    def copies_off_page = @selection ? @selection.lots.where.not(id: lot_ids).sum(:quantity) : 0

    private
      def lot_ids = @table.lots.map(&:id)
      def selected_ids = @selected_ids ||= @selection ? @selection.lots.where(id: lot_ids).pluck(:id).to_set : Set.new
  end
  ```
- [ ] Replace `app/controllers/concerns/collection_listing.rb`:
  ```ruby
  # Builds the collection page in its views (spec 004 Story 11, spec 006): the grid, the table, or the
  # table in bulk mode. The page uses it, and so do refused actions that re-render a collection URL (FR-5).
  module CollectionListing
    extend ActiveSupport::Concern

    private
      def prepare_collection(query:, sort:, page:, view:, bulk:, path: request.fullpath)
        @bulk, @sort, @listing_path = bulk, sort, path
        @view = bulk ? "table" : view
        @listing = if @view == "table"
          CollectionTable.new(account: Current.account, query:, page:, sort:)
        else
          CollectionGrid.new(account: Current.account, query:, page:)
        end
        @selection_state = CollectionTable::SelectionState.new(table: @listing, selection: Current.session.bulk_selection) if bulk
      end

      # The page a collection URL names, e.g. the bulk table to re-render with a refusal.
      def prepare_collection_at(path)
        values = Rack::Utils.parse_query(URI.parse(path).query)
        prepare_collection(query: values["q"], sort: CollectionTable::Sort.parse(values["sort"], values["dir"]), page: values["page"],
          view: values["view"].presence_in(User::COLLECTION_VIEWS) || Current.user.collection_view, bulk: values["bulk"] == "1", path:)
      end

      def render_collection_refusal(message)
        flash.now[:alert] = message
        render "collections/show", status: :unprocessable_content
      end
  end
  ```
- [ ] Replace `app/controllers/collections_controller.rb`:
  ```ruby
  # The collection page (spec 004 Story 11, spec 006): the grid or the table, by the URL's view or the
  # collector's saved one, or the table in bulk mode.
  class CollectionsController < ApplicationController
    include CollectionListing

    def root
      redirect_to collection_path
    end

    def show
      bulk = params[:bulk] == "1"
      remember_view unless bulk
      prepare_collection(query: params[:q], sort: CollectionTable::Sort.parse(params[:sort], params[:dir]), page: params[:page],
        view: requested_view || Current.user.collection_view, bulk:)
    end

    private
      def requested_view = params[:view].presence_in(User::COLLECTION_VIEWS)

      # A page naming a view saves it as the collector's choice (spec 006 AC-1.3), unless the browser
      # only prefetched it: nobody chose that (AC-1.10, FR-1). Bulk mode never saves one (AC-4.5).
      def remember_view
        return if requested_view.nil? || prefetch? || Current.user.collection_view == requested_view

        Current.user.update!(collection_view: requested_view)
      end

      def prefetch?
        [ request.headers["Sec-Purpose"], request.headers["X-Sec-Purpose"] ].compact.any? { |purpose| purpose.include?("prefetch") }
      end
  end
  ```
- [ ] Write `app/controllers/collections/selections_controller.rb`:
  ```ruby
  # Bulk mode's selection (spec 006 Stories 4–5, FR-4). Edit many starts an empty one. The bulk form
  # records a page's ticks and then goes where the pressed control says: Done, the filter, a page or
  # sort, or an action's page. Nothing here answers a GET, so a prefetch can't change a selection.
  class Collections::SelectionsController < ApplicationController
    include CollectionListing

    ACTIONS = %w[set_condition remove].freeze

    def create
      query = CollectionFilter.normalize(params[:q])
      sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
      BulkSelection.for(Current.session).restart!(query:, sort:)
      redirect_to helpers.collection_listing_path(bulk: 1, query:, sort:), status: :see_other
    end

    def update
      query = CollectionFilter.normalize(params[:rendered_q])
      sort = CollectionTable::Sort.parse(params[:sort], params[:dir])
      selection = BulkSelection.for(Current.session)
      return done(selection, query, sort) if params[:go] == "done"

      selection.restart!(query:, sort:) unless selection.context?(query, sort)
      selection.record!(shown_ids: ids(:shown_ids), ticked_ids: ids(:ticked_ids),
        header_rendered: params[:all_rendered] == "1", header_ticked: params[:all] == "1")
      ACTIONS.include?(params[:go]) ? act(selection, query, sort) : navigate(selection, *destination(query, sort))
    end

    private
      def ids(key) = Array(params[key]).map(&:to_i)

      # Back to the saved view with the same filter and sort; the ticks are discarded (AC-4.5).
      def done(selection, query, sort)
        selection.destroy!
        redirect_to helpers.collection_listing_path(query:, sort:), status: :see_other
      end

      def act(selection, query, sort)
        page = params[:page].presence
        if selection.lots.exists?
          path = params[:go] == "remove" ? new_collection_bulk_removal_path(page:) : new_collection_condition_change_path(page:)
          redirect_to path, status: :see_other
        else
          prepare_collection_at(helpers.collection_listing_path(bulk: 1, query:, sort:, page:))
          gone = ids(:ticked_ids).any? || params[:all] == "1"
          render_collection_refusal(gone ? BulkSelection::NONE_LEFT : BulkSelection::NOTHING_SELECTED)
        end
      end

      def navigate(selection, query, sort, page)
        selection.restart!(query:, sort:) unless selection.context?(query, sort)
        redirect_to helpers.collection_listing_path(bulk: 1, query:, sort:, page:), status: :see_other
      end

      # Where the filter (the form's default submit), a sort header or a pager button leads (FR-4).
      # An unchanged filter reloads the same page.
      def destination(query, sort)
        if params[:go] == "filter"
          filter = CollectionFilter.normalize(params[:q])
          [ filter, sort, (params[:page] if filter == query) ]
        elsif (values = collection_values(params[:go]))
          [ CollectionFilter.normalize(values["q"]), CollectionTable::Sort.parse(values["sort"], values["dir"]), values["page"] ]
        else
          [ query, sort, params[:page] ]
        end
      end

      # The params of a collection URL on this instance; nil for anything else.
      def collection_values(url)
        uri = URI.parse(url_from(url).to_s)
        Rack::Utils.parse_query(uri.query) if uri.path == collection_path
      rescue URI::InvalidURIError
        nil
      end
  end
  ```
- [ ] Replace `app/helpers/collections_helper.rb`:
  ```ruby
  module CollectionsHelper
    # A collection URL with its params in one form (spec 006): bulk mode or the view, the filter, the
    # table's sort and the page (left out on page 1).
    def collection_listing_path(query: nil, sort: nil, page: nil, bulk: nil, view: nil)
      collection_path({ bulk:, view:, q: query.presence, page: (page if page.to_i > 1) }.merge(sort&.to_params || {}).compact)
    end

    # A sortable column header (spec 006 AC-3.2): it states the order and leads to the next one. Outside
    # bulk mode it's a link; in bulk mode a button of the bulk form, so the ticks go along (FR-4).
    def sort_header(table, column, label, bulk: false, **html)
      url = collection_listing_path(query: table.query, sort: table.sort.toward(column), **(bulk ? { bulk: 1 } : { view: "table" }))
      control = bulk ? button_tag(label, type: "submit", name: "go", value: url, class: "c-table__sort") : link_to(label, url, class: "c-table__sort")
      tag.th(control, "aria-sort": table.sort.aria_sort(column), **html)
    end

    def items_count(count) = pluralize(number_with_delimiter(count), "item")

    # The bulk bar's count (spec 006 AC-5.1–5.5): selected copies against the filter's copies.
    def selection_count(state, matching)
      if state.everything? && matching.positive?
        safe_join([ "All ", tag.span(number_with_delimiter(matching)), " #{"item".pluralize(matching)} selected" ])
      else
        safe_join([ tag.span(number_with_delimiter(state.copies)), " of #{number_with_delimiter(matching)} selected" ])
      end
    end
  end
  ```
- [ ] Replace `app/views/collections/_view_switch.html.erb`:
  ```erb
  <%# locals: (view:, bulk: false) %>
  <%# In bulk mode the switch is inert: Table is pressed, Grid is disabled, and neither submits (spec 006 AC-4.3). %>
  <div class="c-seg" role="group" aria-label="View">
    <% { "grid" => "Grid", "table" => "Table" }.each do |value, label| %>
      <% if bulk %>
        <%= button_tag type: "button", "aria-pressed": (value == "table").to_s, disabled: value == "grid" do %><%= render "icons/#{value}" %><span class="c-seg__label"><%= label %></span><% end %>
      <% else %>
        <%= button_tag type: "submit", form: "view-switch", name: "view", value:, "aria-pressed": (value == view).to_s do %><%= render "icons/#{value}" %><span class="c-seg__label"><%= label %></span><% end %>
      <% end %>
    <% end %>
  </div>
  ```
- [ ] Replace `app/views/collections/_view_forms.html.erb`:
  ```erb
  <%# locals: (listing:, sort:) %>
  <%# The forms the filter bar's view switch and Edit many submit (spec 006 FR-1, AC-4.2). They sit in the results frame, so they always carry the current filter. %>
  <%= tag.form id: "view-switch", action: collection_path, method: "get", hidden: true, data: { turbo_frame: "_top" } do %>
    <% if listing.query.present? %><%= hidden_field_tag :q, listing.query, id: nil %><% end %>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
  <% end %>
  <%= form_with url: collection_selection_path, method: :post, id: "edit-many", hidden: true, data: { turbo_frame: "_top" } do %>
    <% if listing.query.present? %><%= hidden_field_tag :q, listing.query, id: nil %><% end %>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
  <% end %>
  ```
- [ ] Replace `app/views/collections/_filter_bar.html.erb`:
  ```erb
  <%# locals: (listing:, sort:, view:) %>
  <%= form_with url: collection_path, method: :get, class: "c-filterbar", role: "search", data: { controller: "url-sync", turbo_frame: "results", turbo_action: "advance" } do |form| %>
    <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: listing.query, placeholder: "Search your collection", "aria-label": "Search your collection",
          data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
    <% sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
    <div class="c-filterbar__end">
      <%= button_tag "Edit many", type: "submit", form: "edit-many", class: "c-btn c-btn--secondary c-btn--sm c-filterbar__bulk" %>
      <%= render "collections/view_switch", view: %>
      <details class="c-menu c-filterbar__more" data-controller="menu">
        <summary class="c-btn c-btn--secondary c-btn--sm c-btn--icon" aria-label="More actions"><%= render "icons/more" %></summary>
        <div class="c-menu__list"><%= button_tag "Edit many", type: "submit", form: "edit-many", class: "c-menu__item" %></div>
      </details>
    </div>
  <% end %>
  ```
- [ ] Replace `app/views/collections/_table.html.erb`:
  ```erb
  <%# locals: (table:, return_to: nil, state: nil) %>
  <%# Outside bulk mode, rows have an actions menu; in bulk mode (state given) a checkbox instead (spec 006 AC-2.5, AC-4.2). %>
  <% bulk = !state.nil? %>
  <table class="c-table">
    <thead>
      <tr>
        <% if bulk %>
          <th class="c-table__select">
            <% if table.lots.any? %>
              <%= check_box_tag :all, "1", state.all?, id: nil, "aria-label": "Select all", data: { bulk_selection_target: "header", action: "bulk-selection#toggleAll" } %>
            <% end %>
          </th>
        <% end %>
        <%= sort_header table, "name", "Name", bulk: %>
        <%= sort_header table, "set", "Set", bulk:, class: "is-opt" %>
        <th class="is-opt">Language</th>
        <th class="is-opt">Finish</th>
        <%= sort_header table, "condition", "Condition", bulk:, class: "is-opt" %>
        <%= sort_header table, "quantity", "Qty", bulk:, class: "is-num" %>
        <%= sort_header table, "price", "Paid", bulk:, class: "is-num is-opt" %>
        <% unless bulk %><th><span class="c-sr">Actions</span></th><% end %>
      </tr>
    </thead>
    <tbody>
      <% table.lots.each do |lot| %>
        <%= tag.tr "aria-selected": (state.selected?(lot).to_s if bulk) do %>
          <% if bulk %>
            <td class="c-table__select">
              <%= hidden_field_tag "shown_ids[]", lot.id, id: nil %>
              <%= check_box_tag "ticked_ids[]", lot.id, state.selected?(lot), id: nil, "aria-label": "Select #{lot_label(lot)}",
                    data: { quantity: lot.quantity, bulk_selection_target: "row", action: "bulk-selection#toggle" } %>
            </td>
          <% end %>
          <%= render "collections/lot_cells", lot: %>
          <% unless bulk %>
            <td class="c-table__actions">
              <details class="c-menu" data-controller="menu">
                <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= lot_label(lot) %>"><%= render "icons/more" %></summary>
                <div class="c-menu__list">
                  <%= link_to "Edit copy", edit_lot_path(lot, from: "collection", return_to:), class: "c-menu__item" %>
                  <div class="c-menu__sep"></div>
                  <%= link_to "Remove", new_lot_removal_path(lot, from: "collection", return_to:), class: "c-menu__item c-menu__item--danger" %>
                </div>
              </details>
            </td>
          <% end %>
        <% end %>
      <% end %>
    </tbody>
  </table>
  ```
- [ ] Write `app/views/collections/_bulk_pager.html.erb`:
  ```erb
  <%# locals: (table:) %>
  <%# The pager in bulk mode: buttons of the bulk form, so the ticks go along (spec 006 FR-4). %>
  <% pagination = table.pagination %>
  <% if pagination.total_pages > 1 %>
    <nav class="c-pager" aria-label="Pagination">
      <% if pagination.previous_page %>
        <%= button_tag "Previous", type: "submit", name: "go", value: collection_listing_path(bulk: 1, query: table.query, sort: table.sort, page: pagination.previous_page), class: "c-btn c-btn--secondary c-btn--sm" %>
      <% end %>
      <span class="c-pager__position">Page <%= pagination.page %> of <%= pagination.total_pages %></span>
      <% if pagination.next_page %>
        <%= button_tag "Next", type: "submit", name: "go", value: collection_listing_path(bulk: 1, query: table.query, sort: table.sort, page: pagination.next_page), class: "c-btn c-btn--secondary c-btn--sm" %>
      <% end %>
    </nav>
  <% end %>
  ```
- [ ] Write `app/views/collections/_bulk.html.erb`:
  ```erb
  <%# locals: (table:, state:) %>
  <%# Bulk mode (spec 006 Stories 4–5, FR-4): one PATCH form. The filter input and its Filter button sit in the filter bar and join the form by its id; Filter comes first, so Enter filters. The view switch stays outside the form. %>
  <div class="c-collection" data-controller="search-shortcut bulk-selection"
       data-bulk-selection-matching-value="<%= table.matching_quantity %>" data-bulk-selection-base-value="<%= state.copies_off_page %>">
    <div class="c-filterbar" role="search">
      <label class="c-input"><%= render "icons/search" %><%= search_field_tag :q, table.query, form: "bulk", id: nil, placeholder: "Search your collection",
            "aria-label": "Search your collection", data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
      <%= button_tag "Filter", type: "submit", form: "bulk", name: "go", value: "filter", class: "c-sr", tabindex: -1 %>
      <div class="c-filterbar__end"><%= render "collections/view_switch", view: "table", bulk: true %></div>
    </div>
    <%= form_with url: collection_selection_path, method: :patch, id: "bulk" do %>
      <%= hidden_field_tag :rendered_q, table.query, id: nil %>
      <% table.sort.to_params.each do |name, value| %><%= hidden_field_tag name, value, id: nil %><% end %>
      <%= hidden_field_tag :page, table.pagination.page, id: nil %>
      <%= hidden_field_tag :all_rendered, state.all? ? "1" : "0", id: nil %>
      <div class="c-bulkbar" role="region" aria-label="Bulk actions">
        <div class="c-bulkbar__count" data-bulk-selection-target="count"><%= selection_count(state, table.matching_quantity) %></div>
        <div class="c-bulkbar__extra">
          <%= button_tag "Set condition…", type: "submit", name: "go", value: "set_condition", class: "c-btn c-btn--secondary c-btn--sm" %>
          <%= button_tag "Remove", type: "submit", name: "go", value: "remove", class: "c-btn c-btn--danger c-btn--sm" %>
        </div>
        <details class="c-menu c-bulkbar__more" data-controller="menu">
          <summary class="c-btn c-btn--secondary c-btn--sm c-btn--icon" aria-label="More bulk actions"><%= render "icons/more" %></summary>
          <div class="c-menu__list">
            <%= button_tag "Set condition…", type: "submit", name: "go", value: "set_condition", class: "c-menu__item" %>
            <div class="c-menu__sep"></div>
            <%= button_tag "Remove", type: "submit", name: "go", value: "remove", class: "c-menu__item c-menu__item--danger" %>
          </div>
        </details>
        <%= button_tag "Done", type: "submit", name: "go", value: "done", class: "c-btn c-btn--primary c-btn--sm", data: { bulk_selection_target: "done" } %>
      </div>
      <div class="c-results__meta">
        <span class="c-filterbar__count"><%= "#{number_with_delimiter(table.matching_quantity)} of " if table.filtered? %><%= number_with_delimiter(table.total_quantity) %> <%= "item".pluralize(table.total_quantity) %></span>
      </div>
      <% if table.lots.empty? %>
        <p class="c-empty">No cards in your collection match "<%= table.query %>".</p>
      <% else %>
        <%= render "collections/table", table:, state: %>
        <%= render "collections/bulk_pager", table: %>
      <% end %>
    <% end %>
  </div>
  ```
- [ ] In `app/views/collections/show.html.erb`, replace `<% else %>` (the one before `<div class="c-collection" data-controller="search-shortcut">`) with:
  ```erb
  <% elsif @bulk %>
    <%= render "collections/bulk", table: @listing, state: @selection_state %>
  <% else %>
  ```
- [ ] Append to `app/assets/stylesheets/collector/additions.css`:
  ```css
  /* ---------- Bulk mode (spec 006): the checkbox column, as narrow as its box ---------- */
  .c-table th.c-table__select, .c-table td.c-table__select { width:1%; }
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/collection_table/selection_state_spec.rb spec/requests/bulk_mode_spec.rb spec/requests/collection_views_spec.rb spec/requests/collection_table_spec.rb spec/requests/collections_spec.rb` — expect PASS.
- [ ] Commit: `feat(collection): select lots in bulk mode, across pages and all matching`

---

## Phase 7: Live count, mixed header and Esc

**Implements:** FR-4 (scripting enhancements), FR-12 of 004 | **Satisfies:** AC-4.4 (phone), AC-4.6, AC-5.8, AC-2.8
**Files:** `app/javascript/controllers/bulk_selection_controller.js`, `spec/system/bulk_mode_spec.rb`, `spec/system/collection_table_spec.rb`
**Interfaces:** Consumes: Phase 6's markup (`data-bulk-selection-*` values and targets; `data-quantity` on row boxes). Produces: the `bulk-selection` Stimulus controller.

- [ ] Write `spec/system/bulk_mode_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Bulk mode", type: :system do
    let(:user) { system_sign_in_as(create(:user)) }

    def own(name, **options) = owned_printing(name, account: user.account, **options)
    def row_box(name) = find("tbody tr", text: name).find("input[type=checkbox]")

    it "counts ticks live, selects everything from the header and shows a mixed header", :aggregate_failures do
      own("Lightning Bolt", quantity: 3)
      own("Opt", quantity: 2)
      visit collection_path
      click_on "Edit many"
      expect(page).to have_css(".c-bulkbar__count", exact_text: "0 of 5 selected")
      page.execute_script("window.__marker = 'still here'")
      row_box("Lightning Bolt").check
      expect(page).to have_css(".c-bulkbar__count", exact_text: "3 of 5 selected")
      expect(page).to have_css("tr[aria-selected=true]", text: "Lightning Bolt")
      check "Select all"
      expect(page).to have_css(".c-bulkbar__count", exact_text: "All 5 items selected")
      row_box("Opt").uncheck
      expect(page).to have_css(".c-bulkbar__count", exact_text: "3 of 5 selected")
      expect(page.evaluate_script("document.querySelector('thead input[type=checkbox]').indeterminate")).to be(true)
      expect(page.evaluate_script("window.__marker")).to eq("still here")
    end

    it "keeps ticks when paging", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      own("Card A")
      own("Card B")
      visit collection_path
      click_on "Edit many"
      row_box("Card A").check
      click_on "Next"
      expect(page).to have_css(".c-bulkbar__count", exact_text: "1 of 2 selected")
      click_on "Previous"
      expect(row_box("Card A")).to be_checked
    end

    it "leaves bulk mode on Esc, but Esc with a menu open only closes the menu", :aggregate_failures do
      own("Lightning Bolt")
      visit collection_path
      click_on "Edit many"
      expect(page).to have_css(".c-bulkbar")
      find("summary.c-avatar").click
      expect(page).to have_css("details[open]")
      find("body").send_keys(:escape)
      expect(page).to have_no_css("details[open]")
      expect(page).to have_css(".c-bulkbar")
      find("body").send_keys(:escape)
      expect(page).to have_no_css(".c-bulkbar")
      expect(page).to have_css(".c-grid")
      expect(page).to have_current_path(collection_path)
    end

    it "keeps the count and Done in view on a phone, with the actions in a menu", :aggregate_failures do
      own("Lightning Bolt")
      visit collection_path(bulk: 1)
      expect(open_in_narrow_frame(collection_path(bulk: 1), width: 390, height: 844, ready: ".c-bulkbar")).to eq([ 390, true ])
      within_narrow_frame do
        expect(page).to have_css(".c-bulkbar__count", visible: :visible)
        expect(page).to have_button("Done", visible: :visible)
        expect(page).to have_no_css(".c-bulkbar__extra .c-btn", visible: :visible)
        expect(page).to have_css("thead th", visible: :visible, count: 3)
        find(".c-bulkbar__more summary").click
        expect(page).to have_button("Set condition…", visible: :visible)
      end
    end
  end
  ```
- [ ] Write `spec/system/collection_table_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection table on a phone", type: :system do
    it "shows only name, quantity and actions, with the key facts under the name", :aggregate_failures do
      user = system_sign_in_as(create(:user))
      owned_printing("Lightning Bolt", account: user.account, number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
      visit collection_path
      expect(open_in_narrow_frame(collection_path(view: "table"), width: 360, ready: "table.c-table")).to eq([ 360, true ])
      within_narrow_frame do
        headers = page.all("thead th", visible: :visible)
        expect(headers.size).to eq(3)
        expect(headers.first(2).map { |th| th.text.strip }).to eq([ "Name", "Qty" ])
        expect(page).to have_css(".c-table__sub", visible: :visible, text: "· 146 · Foil · NM · EN")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/bulk_mode_spec.rb spec/system/collection_table_spec.rb` — expect FAIL: the count stays "0 of 5 selected" after a tick, and Esc does nothing.
- [ ] Write `app/javascript/controllers/bulk_selection_controller.js`:
  ```js
  import { Controller } from "@hotwired/stimulus"

  // Bulk mode's live count, mixed header and Esc (spec 006 AC-5.8, AC-4.6). Nothing is submitted here:
  // the bulk form carries the ticks with the next control the collector presses (FR-4).
  // base = the server's selected copies not on this page; the count adds this page's ticked rows.
  export default class extends Controller {
    static targets = ["count", "header", "row", "done"]
    static values = { matching: Number, base: Number }

    connect() {
      this.onKeydown = this.onKeydown.bind(this)
      // Capture phase: an open menu is still open here, before the menu controller closes it on Esc.
      document.addEventListener("keydown", this.onKeydown, true)
      this.render()
    }

    disconnect() {
      document.removeEventListener("keydown", this.onKeydown, true)
    }

    toggle(event) {
      event.target.closest("tr")?.setAttribute("aria-selected", String(event.target.checked))
      this.render()
    }

    toggleAll() {
      const checked = this.headerTarget.checked
      this.rowTargets.forEach((row) => {
        row.checked = checked
        row.closest("tr")?.setAttribute("aria-selected", String(checked))
      })
      this.baseValue = checked ? this.matchingValue - this.sum(this.rowTargets) : 0
      this.render()
    }

    render() {
      const count = this.baseValue + this.sum(this.rowTargets.filter((row) => row.checked))
      const all = this.hasHeaderTarget && this.headerTarget.checked
      if (this.hasHeaderTarget) this.headerTarget.indeterminate = all && count < this.matchingValue
      const format = (value) => new Intl.NumberFormat("en").format(value)
      const parts = all && count === this.matchingValue && count > 0
        ? [ "All ", this.number(format(count)), ` ${count === 1 ? "item" : "items"} selected` ]
        : [ this.number(format(count)), ` of ${format(this.matchingValue)} selected` ]
      this.countTarget.replaceChildren(...parts)
    }

    onKeydown(event) {
      if (event.key !== "Escape" || document.querySelector("details[open], dialog[open]")) return
      this.doneTarget.form.requestSubmit(this.doneTarget)
    }

    sum(rows) {
      return rows.reduce((total, row) => total + Number(row.dataset.quantity), 0)
    }

    number(text) {
      const span = document.createElement("span")
      span.textContent = text
      return span
    }
  }
  ```
- [ ] Run: `bin/rspec spec/system/bulk_mode_spec.rb spec/system/collection_table_spec.rb && bin/importmap audit` — expect PASS, and no vulnerable packages.
- [ ] Commit: `feat(collection): count bulk selections live and leave bulk mode on Esc`

---

## Phase 8: Set condition on the selection

**Implements:** FR-5 (Set condition), FR-2 (vocabulary) | **Satisfies:** AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-6.6, AC-7.9 (Set condition page), AC-8.1 (action time), Error Scenarios (unknown condition, all gone)
**Files:** `spec/routing/routes_spec.rb`, `app/models/lot/cap_exceeded.rb`, `app/models/lot/condition_change.rb`, `app/models/bulk_selection.rb`, `app/controllers/concerns/bulk_selected.rb`, `app/controllers/collections/condition_changes_controller.rb`, `app/views/collections/condition_changes/new.html.erb`, `app/helpers/collections_helper.rb`, `app/assets/stylesheets/collector/additions.css`, `spec/models/lot/condition_change_spec.rb`, `spec/models/bulk_selection_spec.rb`, `spec/requests/bulk_condition_spec.rb`
**Interfaces:** Consumes: Phase 6's routes and selection. Produces:
- `Lot::CapExceeded#lot`
- `Lot::ConditionChange.new(account:, lots:, condition:, sort:).apply! → [lot ids]`
- `BulkSelection#include!(lot_ids)` and `#vocabulary`
- the `BulkSelected` concern, which sets `@selection` and `@bulk_path` and provides `#selection?`
- `over_cap_message(prefix, lot)`

- [ ] Add to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes Set condition", :aggregate_failures do
    expect(get: "/collection/condition_change/new").to route_to("collections/condition_changes#new")
    expect(post: "/collection/condition_change").to route_to("collections/condition_changes#create")
  end
  ```
- [ ] Write `spec/models/lot/condition_change_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Lot::ConditionChange, type: :model do
    let(:account) { create(:user).account }
    let!(:first) { owned_printing(account:, finish: "foil") }
    let(:sort) { CollectionTable::Sort.parse(nil, nil) }

    def lot(**attributes) = create(:lot, account:, entry: first.entry, **attributes)
    def change(lots, condition) = described_class.new(account:, lots: account.lots.where(id: lots.map(&:id)), condition:, sort:)

    it "sets the condition on each lot and leaves others alone", :aggregate_failures do
      other = lot(finish: "nonfoil", condition: "damaged")
      ids = change([ first ], "lightly_played").apply!
      expect([ first.reload.condition, other.reload.condition, ids ]).to eq([ "lightly_played", "damaged", [ first.id ] ])
    end

    it "merges into a lot that already has the identity, selected or not", :aggregate_failures do
      played = lot(finish: "foil", condition: "lightly_played", quantity: 4)
      ids = change([ first ], "lightly_played").apply!
      expect([ Lot.count, played.reload.quantity, ids ]).to eq([ 1, 5, [ played.id ] ])
    end

    it "merges selected lots that become identical" do
      lot(finish: "foil", condition: "damaged", quantity: 2)
      change(Lot.all.to_a, nil).apply!
      expect(Lot.pluck(:condition, :quantity)).to eq([ [ nil, 3 ] ])
    end

    it "changes nothing when a merge would pass 9,999 copies, naming the first such lot in order", :aggregate_failures do
      lot(finish: "foil", condition: "near_mint", quantity: 9_999)
      expect { change([ first ], "near_mint").apply! }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(first) }
      expect(Lot.order(:id).pluck(:condition, :quantity)).to eq([ [ nil, 1 ], [ "near_mint", 9_999 ] ])
    end
  end
  ```
- [ ] Add to `spec/models/bulk_selection_spec.rb`:
  ```ruby
  it "selects lots added later, in either mode", :aggregate_failures do
    a = own("Card A")
    b = own("Card B")
    selection.include!([ a.id ])
    expect(selection.lots).to eq([ a ])
    tick([ a ], [], header_ticked: true)
    tick([ a, b ], [], header_rendered: true, header_ticked: true)
    selection.include!([ b.id ])
    expect(selection.lots).to eq([ b ])
  end

  it "uses the vocabulary of its lots' collectible" do
    own
    selection.include!(Lot.ids)
    expect(selection.vocabulary).to eq(MTG::Collecting)
  end
  ```
- [ ] Write `spec/requests/bulk_condition_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Bulk Set condition", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
    def page_html = Nokogiri::HTML5(response.body)

    def select_lots(*lots, page: nil)
      post collection_selection_path
      patch collection_selection_path, params: { go: "set_condition", q: "", rendered_q: "", all_rendered: "0", page:,
        shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }.compact
    end

    it "asks for one condition on its own page, with Cancel and Back to the bulk table", :aggregate_failures do
      select_lots(own(quantity: 2), own("Opt"), page: 1)
      get new_collection_condition_change_path(page: 1)
      expect(page_html.at_css("h1").text).to eq("Set the condition of 3 items")
      expect(page_html.css("input[type=radio][name=condition]").map { |radio| radio["value"] })
        .to eq(%w[near_mint lightly_played moderately_played heavily_played damaged] + [ "" ])
      expect(page_html.css(".c-choices label").map { |label| label.text.squish }).to eq([
        "Near mint (NM)", "Lightly played (LP)", "Moderately played (MP)", "Heavily played (HP)", "Damaged (DMG)", "Not specified"
      ])
      expect(page_html.at_css("input[type=submit]")["value"]).to eq("Apply")
      expect(page_html.at_css(".c-form__actions a")["href"]).to eq(collection_path(bulk: 1))
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1))
      expect(page_html.at_css('.c-tabbar a[aria-current="page"]').text).to include("Collection")
    end

    it "sends the collector back to the bulk table when nothing is selected" do
      get new_collection_condition_change_path
      expect([ response.location, flash[:alert] ]).to eq([ "http://www.example.com#{collection_path(bulk: 1)}", "Select at least one item." ])
    end

    it "sets the condition and returns to the bulk table with the selection kept", :aggregate_failures do
      first = own(quantity: 2)
      second = own("Opt")
      select_lots(first, second)
      post collection_condition_change_path, params: { condition: "lightly_played" }
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:notice]).to eq("Set the condition of 3 items to Lightly played.")
      expect([ first.reload.condition, second.reload.condition ]).to eq(%w[lightly_played lightly_played])
      follow_redirect!
      expect(page_html.at_css(".c-bulkbar__count").text).to eq("3 of 3 selected")
    end

    it "clears the condition for Not specified" do
      lot = own(condition: "damaged")
      select_lots(lot)
      post collection_condition_change_path, params: { condition: "" }
      expect([ flash[:notice], lot.reload.condition ]).to eq([ "Cleared the condition of 1 item.", nil ])
    end

    it "merges lots that become identical, keeping the merged lot selected", :aggregate_failures do
      played = own(quantity: 2, finish: "foil", condition: "lightly_played")
      unknown = create(:lot, account: user.account, entry: played.entry, finish: "foil", quantity: 3)
      select_lots(unknown)
      post collection_condition_change_path, params: { condition: "lightly_played" }
      follow_redirect!
      expect(page_html.css("tbody tr").size).to eq(1)
      expect(page_html.at_css("tbody input[name='ticked_ids[]']").key?("checked")).to be(true)
      expect(played.reload.quantity).to eq(5)
    end

    it "changes nothing past 9,999 copies, keeping the selection", :aggregate_failures do
      full = own(number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
      one = create(:lot, account: user.account, entry: full.entry, finish: "foil")
      select_lots(one)
      post collection_condition_change_path, params: { condition: "near_mint" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css(".c-status__message--alert").text)
        .to eq("Nothing changed. Lightning Bolt (#{full.entry.set.code.upcase} · 146) would have more than 9,999 copies in one lot.")
      expect([ one.reload.condition, BulkSelection.sole.lots.to_a ]).to eq([ nil, [ one ] ])
    end

    it "refuses an unknown condition", :aggregate_failures do
      select_lots(own)
      post collection_condition_change_path, params: { condition: "mint" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css(".c-status__message--alert").text).to eq("That isn't a known condition.")
    end

    it "refuses when every selected lot is gone", :aggregate_failures do
      lot = own
      select_lots(lot)
      lot.destroy!
      post collection_condition_change_path, params: { condition: "near_mint" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css(".c-status__message--alert").text).to eq("None of the selected items are in your collection any more.")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/lot/condition_change_spec.rb spec/models/bulk_selection_spec.rb spec/requests/bulk_condition_spec.rb` — expect FAIL (uninitialized constant `Lot::ConditionChange`).
- [ ] Write `app/models/lot/cap_exceeded.rb`:
  ```ruby
  # A change that would put more than 9,999 copies in one lot (spec 004 FR-6). It names the lot that
  # would overflow, first in the table's order (spec 006 AC-6.4, AC-7.5).
  class Lot::CapExceeded < StandardError
    attr_reader :lot

    def initialize(lot)
      @lot = lot
      super("#{lot.entry.name} would have more than #{Lot::MAX_QUANTITY} copies in one lot")
    end
  end
  ```
- [ ] Write `app/models/lot/condition_change.rb`:
  ```ruby
  # Sets one condition on many lots of an account (spec 006 Story 6). Lots that become identical to
  # another lot of the account merge into it, as a single edit does (004 AC-10.2). All or nothing: the
  # cap is checked for every merge before anything is written (AC-6.4).
  class Lot::ConditionChange
    def initialize(account:, lots:, condition:, sort:)
      @account, @lots, @condition, @sort = account, lots, condition, sort
    end

    # Returns the ids of the lots holding the changed copies.
    def apply!
      Lot.transaction do
        lots = @lots.preload(:entry).to_a
        Catalog::Entry.preload_extensions(lots.map(&:entry))
        groups = lots.group_by { |lot| [ lot.catalog_entry_id, Lot.key_for(lot.finish, @condition, lot.price_paid_cents) ] }
        targets = existing_targets(groups.keys, lots)
        check_cap!(groups, targets)
        groups.map { |key, group| merge(targets[key], group).id }
      end
    end

    private
      # Lots outside the change that already have a target identity.
      def existing_targets(keys, lots)
        @account.lots.where(catalog_entry_id: keys.map(&:first).uniq, lot_key: keys.map(&:last).uniq).where.not(id: lots.map(&:id))
          .index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }.slice(*keys)
      end

      def check_cap!(groups, targets)
        over = groups.select { |key, group| group.sum(&:quantity) + (targets[key]&.quantity || 0) > Lot::MAX_QUANTITY }.values.flatten
        return if over.empty?

        raise Lot::CapExceeded, @sort.apply(@account.lots.joins(entry: :set).where(id: over.map(&:id))).preload(entry: :set).first
      end

      # The existing lot survives if there is one, else the group's first lot; the others fold into it.
      def merge(target, group)
        survivor = target || group.first
        quantity = group.sum(&:quantity) + (target&.quantity || 0)
        (group - [ survivor ]).each(&:destroy!)
        survivor.update!(condition: @condition, quantity:)
        survivor
      end
  end
  ```
- [ ] In `app/models/bulk_selection.rb`, add these public methods after `everything?`:
  ```ruby
  # Selects lots that hold changed copies after Set condition, e.g. a merged lot (AC-6.5).
  def include!(lot_ids)
    all_matching? ? marks.where(lot_id: lot_ids).delete_all : mark!(lot_ids - marks.pluck(:lot_id))
  end

  # The selected lots' collectible vocabulary; a selection spans one collectible (spec 006 Non-Goals).
  def vocabulary = Catalog.collecting_for(lots.pick(Catalog::Entry.arel_table[:collectible_type]) || Catalog.collecting.keys.first)
  ```
- [ ] Write `app/controllers/concerns/bulk_selected.rb`:
  ```ruby
  # The session's bulk selection, for the pages that act on it (spec 006 Stories 6–7). Their Cancel,
  # Back and redirects return to the bulk table it was made in, on the same page (AC-6.5, AC-7.2, AC-7.9).
  module BulkSelected
    extend ActiveSupport::Concern

    included do
      before_action :set_selection
    end

    private
      def set_selection
        @selection = Current.session.bulk_selection
        @bulk_path = helpers.collection_listing_path(bulk: 1, query: @selection&.query, sort: @selection&.sort, page: params[:page])
        redirect_to @bulk_path, status: :see_other, alert: BulkSelection::NOTHING_SELECTED if request.get? && !selection?
      end

      def selection? = @selection.present? && @selection.lots.exists?
  end
  ```
- [ ] Write `app/controllers/collections/condition_changes_controller.rb`:
  ```ruby
  # Setting one condition on every selected lot, from its own page (spec 006 Story 6).
  class Collections::ConditionChangesController < ApplicationController
    include BulkSelected

    def new
      @copies = @selection.copies
      @vocabulary = @selection.vocabulary
    end

    def create
      @condition = params[:condition]
      return refuse(BulkSelection::NONE_LEFT, copies: 0) unless selection?

      @copies = @selection.copies
      @vocabulary = @selection.vocabulary
      return refuse("That isn't a known condition.") unless @condition == "" || @vocabulary.conditions.key?(@condition)

      changed = Lot::ConditionChange.new(account: Current.account, lots: @selection.lots, condition: @condition.presence, sort: @selection.sort).apply!
      @selection.include!(changed)
      redirect_to @bulk_path, status: :see_other, notice: changed_message
    rescue Lot::CapExceeded => error
      refuse(helpers.over_cap_message("Nothing changed.", error.lot))
    end

    private
      def changed_message
        items = helpers.items_count(@copies)
        @condition.present? ? "Set the condition of #{items} to #{@vocabulary.conditions.fetch(@condition).first}." : "Cleared the condition of #{items}."
      end

      def refuse(message, copies: @copies)
        @copies = copies
        @vocabulary ||= Catalog.collecting_for(Catalog.collecting.keys.first)
        flash.now[:alert] = message
        render :new, status: :unprocessable_content
      end
  end
  ```
- [ ] Add to `app/helpers/collections_helper.rb`:
  ```ruby
  # Why a change was refused at the lot cap (spec 006 AC-6.4, AC-7.5).
  def over_cap_message(prefix, lot)
    "#{prefix} #{lot.entry.name} (#{set_number(lot.entry)}) would have more than #{number_with_delimiter(Lot::MAX_QUANTITY)} copies in one lot."
  end
  ```
- [ ] Write `app/views/collections/condition_changes/new.html.erb`:
  ```erb
  <% content_for :title, "Set condition · Collector" %>
  <%= render "layouts/appbar", section: :collection, detail: true, back_path: @bulk_path %>
  <main class="c-main c-page">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Set the condition of <%= items_count(@copies) %></h1></div></div>
    <%= form_with url: collection_condition_change_path(page: params[:page]), class: "c-form" do |form| %>
      <fieldset class="c-choices">
        <legend class="c-field__label">Condition</legend>
        <% @vocabulary.conditions.each do |value, (label, short)| %>
          <label class="c-check"><%= radio_button_tag :condition, value, @condition == value, required: true %><%= label %> (<%= short %>)</label>
        <% end %>
        <label class="c-check"><%= radio_button_tag :condition, "", @condition == "" %>Not specified</label>
      </fieldset>
      <div class="c-form__actions">
        <%= form.submit "Apply", class: "c-btn c-btn--primary" %>
        <%= link_to "Cancel", @bulk_path, class: "c-btn c-btn--secondary" %>
      </div>
    <% end %>
  </main>
  <%= render "layouts/tabbar", section: :collection %>
  ```
- [ ] Append to `app/assets/stylesheets/collector/additions.css`:
  ```css
  /* ---------- Choice page (spec 006): one choice from a short list, as radios in a fieldset ---------- */
  .c-choices { display:flex; flex-direction:column; gap:var(--space-2); margin:0; padding:0; border:0; }
  .c-choices legend { margin-bottom:var(--space-2); padding:0; }
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/lot/condition_change_spec.rb spec/models/bulk_selection_spec.rb spec/requests/bulk_condition_spec.rb spec/requests/bulk_mode_spec.rb` — expect PASS.
- [ ] Commit: `feat(collection): set the condition of the selected lots`

---

## Phase 9: Bulk Remove with Undo

**Implements:** FR-5 (Remove), FR-6 | **Satisfies:** AC-7.1, AC-7.2, AC-7.3, AC-7.4, AC-7.5, AC-7.6, AC-7.7, AC-7.8, AC-7.9 (confirmation), AC-8.1 (action time), AC-8.3, Error Scenarios (Undo rows)
**Files:** `spec/routing/routes_spec.rb`, `db/migrate/20260930100003_create_bulk_removals.rb`, `app/models/bulk_removal.rb`, `app/models/session.rb`, `app/controllers/collections/bulk_removals_controller.rb`, `app/controllers/collections/bulk_removals/undos_controller.rb`, `app/controllers/lots_controller.rb`, `app/views/collections/bulk_removals/new.html.erb`, `app/views/shared/_status_message.html.erb`, `app/views/layouts/application.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/models/bulk_removal_spec.rb`, `spec/requests/bulk_removal_spec.rb`
**Interfaces:** Consumes: Phases 6 and 8 (`BulkSelected`, `Lot::CapExceeded`, `over_cap_message`, `prepare_collection_at`). Produces:
- `BulkRemoval.remove!(selection)`, `.supersede!(session)`, `#undo!(sort:)`, `#undoable?`
- `BulkRemoval::NotUndoable`, `::NO_LONGER_UNDOABLE`
- `Session#bulk_removals`
- `flash[:undo]`, which the status message renders as an Undo button

- [ ] Add to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes bulk removal and its undo", :aggregate_failures do
    expect(get: "/collection/bulk_removals/new").to route_to("collections/bulk_removals#new")
    expect(post: "/collection/bulk_removals").to route_to("collections/bulk_removals#create")
    expect(post: "/collection/bulk_removals/1/undo").to route_to("collections/bulk_removals/undos#create", bulk_removal_id: "1")
  end
  ```
- [ ] Write `spec/models/bulk_removal_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe BulkRemoval, type: :model do
    let(:user) { create(:user) }
    let(:account) { user.account }
    let(:session) { user.sessions.create! }
    let(:selection) { BulkSelection.for(session) }
    let(:sort) { CollectionTable::Sort.parse(nil, nil) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
    def select_all = selection.record!(shown_ids: [], ticked_ids: [], header_rendered: false, header_ticked: true)

    it "removes the selected lots, keeping them for one undo, and empties the selection", :aggregate_failures do
      lot = own(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
      select_all
      removal = described_class.remove!(selection)
      expect([ Lot.count, removal.copies, removal.undoable?, selection.reload.lots.to_a ]).to eq([ 0, 2, true, [] ])
      expect(removal.reload.lots_data).to eq([
        { "catalog_entry_id" => lot.catalog_entry_id, "finish" => "foil", "condition" => "near_mint", "price_paid_cents" => 150, "quantity" => 2 }
      ])
    end

    it "removes only the lots matching the filter at the time" do
      bolt = own("Lightning Bolt")
      opt = own("Opt")
      selection.restart!(query: "bolt", sort:)
      select_all
      described_class.remove!(selection)
      expect([ Lot.exists?(bolt.id), Lot.exists?(opt.id) ]).to eq([ false, true ])
    end

    it "restores exactly the removed lots once", :aggregate_failures do
      own(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 150)
      select_all
      before = Lot.pluck(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity)
      removal = described_class.remove!(selection).reload
      removal.undo!(sort:)
      expect([ Lot.pluck(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity), removal.undoable? ]).to eq([ before, false ])
      expect { removal.undo!(sort:) }.to raise_error(BulkRemoval::NotUndoable)
    end

    it "merges restored lots into lots added since" do
      lot = own(quantity: 2)
      select_all
      removal = described_class.remove!(selection).reload
      Lot.add!(account:, entry: lot.entry, quantity: 3)
      removal.undo!(sort:)
      expect(Lot.pluck(:quantity)).to eq([ 5 ])
    end

    it "restores nothing when a merge would pass 9,999 copies", :aggregate_failures do
      lot = own(quantity: 2)
      select_all
      removal = described_class.remove!(selection).reload
      full = Lot.add!(account:, entry: lot.entry, quantity: 9_999)
      expect { removal.undo!(sort:) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(full) }
      expect([ Lot.pluck(:quantity), removal.reload.undoable? ]).to eq([ [ 9_999 ], true ])
    end

    it "restores lots of retired printings" do
      own.entry.update!(retired_at: 1.day.ago)
      select_all
      described_class.remove!(selection).reload.undo!(sort:)
      expect(Lot.count).to eq(1)
    end

    it "keeps one undoable removal per session, leaving superseded ones as stubs", :aggregate_failures do
      own("Card A")
      select_all
      first = described_class.remove!(selection)
      own("Card B")
      select_all
      second = described_class.remove!(selection)
      expect([ first.reload.undoable?, first.lots_data, second.undoable? ]).to eq([ false, nil, true ])
      described_class.supersede!(session)
      expect(second.reload.undoable?).to be(false)
    end

    it "goes with its session" do
      own
      select_all
      described_class.remove!(selection)
      user.end_sessions!
      expect(described_class.count).to eq(0)
    end

    it "keeps an indexed account key and cascades from sessions", :aggregate_failures do
      connection = described_class.connection
      expect(connection.columns("bulk_removals").find { |column| column.name == "account_id" }.null).to be(false)
      expect(connection.indexes("bulk_removals").map(&:columns)).to include(a_collection_starting_with("account_id"))
      expect(connection.foreign_keys("bulk_removals").find { |key| key.to_table == "sessions" }.on_delete).to eq(:cascade)
    end
  end
  ```
- [ ] Write `spec/requests/bulk_removal_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Bulk Remove and Undo", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    def own(name = "Lightning Bolt", **options) = owned_printing(name, account: user.account, **options)
    def page_html = Nokogiri::HTML5(response.body)
    def alert_text = page_html.at_css(".c-status__message--alert").text

    def select_lots(*lots, q: "", page: nil, all: false)
      post collection_selection_path, params: { q: }
      params = { go: "remove", q:, rendered_q: q, all_rendered: "0", page:, shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
      params[:all] = "1" if all
      patch collection_selection_path, params: params.compact
    end

    def remove_selected(page: nil)
      post collection_bulk_removals_path(page:)
      follow_redirect!
    end

    def undo_form = page_html.at_css(".c-status form.c-status__action")

    it "confirms with exact numbers before removing anything", :aggregate_failures do
      select_lots(own(quantity: 2), own("Opt", quantity: 10), page: 1)
      get new_collection_bulk_removal_path(page: 1)
      expect(page_html.at_css(".c-confirm h1").text).to eq("Remove 12 items?")
      expect(page_html.at_css(".c-confirm p").text).to eq("This removes 12 items in 2 lots from your collection. You can undo this right afterwards.")
      expect(page_html.at_css(".c-confirm form button.c-btn--danger").text).to eq("Remove 12 items")
      expect(page_html.at_css(".c-confirm form")["action"]).to eq(collection_bulk_removals_path(page: 1))
      expect(page_html.at_css(".c-confirm a.c-btn--secondary")["href"]).to eq(collection_path(bulk: 1))
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1))
      expect(Lot.count).to eq(2)
    end

    it "keeps the selection when the collector cancels", :aggregate_failures do
      lot = own
      select_lots(lot)
      get new_collection_bulk_removal_path
      get collection_path(bulk: 1)
      expect(page_html.at_css(".c-bulkbar__count").text).to eq("1 of 1 selected")
    end

    it "removes, returns to the bulk table with nothing selected, and offers Undo", :aggregate_failures do
      select_lots(own(quantity: 2), own("Opt"))
      own("Shock")
      post collection_bulk_removals_path
      expect(response).to redirect_to(collection_path(bulk: 1))
      follow_redirect!
      expect(page_html.at_css(".c-status__message").text.squish).to eq("Removed 3 items from your collection. Undo")
      expect(undo_form["action"]).to eq(collection_bulk_removal_undo_path(BulkRemoval.sole))
      expect(undo_form.at_css("input[name=return_to]")["value"]).to eq(collection_path(bulk: 1))
      expect([ page_html.at_css(".c-bulkbar__count").text, response.body.include?("1 item · 1 unique") ]).to eq([ "0 of 1 selected", true ])
    end

    it "shows the empty state with Undo when the removal empties the collection", :aggregate_failures do
      select_lots(own)
      remove_selected
      expect(response.body).to include("No cards in your collection yet.", "Removed 1 item from your collection.")
      expect(undo_form).to be_present
    end

    it "restores the removed lots on Undo and lands on the page it carries", :aggregate_failures do
      select_lots(own(quantity: 2))
      remove_selected
      post undo_form["action"], params: { return_to: collection_path(bulk: 1, q: "bolt") }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt"))
      expect(flash[:notice]).to eq("Restored 2 items to your collection.")
      expect(Lot.sole.quantity).to eq(2)
    end

    it "lands on the collection for an Undo URL off this instance" do
      select_lots(own)
      remove_selected
      post undo_form["action"], params: { return_to: "https://elsewhere.example/collection" }
      expect(response).to redirect_to(collection_path)
    end

    it "refuses a used Undo with 422, re-rendering the page it carries", :aggregate_failures do
      select_lots(own)
      remove_selected
      action = undo_form["action"]
      post action, params: { return_to: collection_path(bulk: 1) }
      post action, params: { return_to: collection_path(bulk: 1) }
      expect(response).to have_http_status(:unprocessable_content)
      expect(alert_text).to eq("This removal can no longer be undone.")
      expect(page_html.at_css("form#bulk")).to be_present
    end

    it "ends the Undo when anything else is removed in the session", :aggregate_failures do
      select_lots(own("Opt"))
      remove_selected
      action = undo_form["action"]
      other = own
      delete lot_path(other)
      post action, params: { return_to: collection_path }
      expect([ response.status, alert_text ]).to eq([ 422, "This removal can no longer be undone." ])
    end

    it "refuses an Undo past 9,999 copies, restoring nothing", :aggregate_failures do
      lot = own(number: "146")
      select_lots(lot)
      remove_selected
      action = undo_form["action"]
      Lot.add!(account: user.account, entry: lot.entry, quantity: 9_999)
      post action, params: { return_to: collection_path(view: "table") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(alert_text).to eq("Nothing restored. Lightning Bolt (#{lot.entry.set.code.upcase} · 146) would have more than 9,999 copies in one lot.")
      expect(Lot.sole.quantity).to eq(9_999)
    end

    it "removes every lot matching the filter for Select all, and nothing else", :aggregate_failures do
      bolt = own("Lightning Bolt")
      opt = own("Opt")
      select_lots(q: "bolt", all: true)
      post collection_bulk_removals_path
      expect([ Lot.exists?(bolt.id), Lot.exists?(opt.id) ]).to eq([ false, true ])
    end

    it "refuses when every selected lot is gone", :aggregate_failures do
      lot = own
      select_lots(lot)
      lot.destroy!
      post collection_bulk_removals_path
      expect([ response.status, alert_text ]).to eq([ 422, "None of the selected items are in your collection any more." ])
    end

    it "lets only the session that removed undo it", :aggregate_failures do
      select_lots(own)
      remove_selected
      action = undo_form["action"]
      delete session_path
      post action, params: { return_to: collection_path }
      expect(response).to redirect_to(new_session_path)
      sign_in_as(user)
      post action, params: { return_to: collection_path }
      expect(response).to have_http_status(:not_found)
      post collection_bulk_removal_undo_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/bulk_removal_spec.rb spec/requests/bulk_removal_spec.rb` — expect FAIL (uninitialized constant `BulkRemoval`).
- [ ] Write `db/migrate/20260930100003_create_bulk_removals.rb`:
  ```ruby
  class CreateBulkRemovals < ActiveRecord::Migration[8.1]
    def change
      create_table :bulk_removals do |t|
        t.references :session, null: false, foreign_key: { on_delete: :cascade }
        t.references :account, null: false, foreign_key: { on_delete: :cascade }
        t.integer :copies, null: false
        t.json :lots_data
        t.timestamps
        t.index :session_id, unique: true, where: "lots_data IS NOT NULL", name: "index_bulk_removals_undoable_per_session"
      end
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate` — expect `bulk_removals` in `db/schema.rb`, with the partial index's `where: "lots_data IS NOT NULL"`.
- [ ] Write `app/models/bulk_removal.rb`:
  ```ruby
  # A bulk removal that can be undone once, from the status message right after it (spec 006 Story 7,
  # FR-6). It belongs to the session that made it. Used or superseded, it keeps no lot data, so a
  # replayed Undo can say it no longer works.
  class BulkRemoval < ApplicationRecord
    NO_LONGER_UNDOABLE = "This removal can no longer be undone.".freeze
    NotUndoable = Class.new(StandardError)

    belongs_to :session
    belongs_to :account

    scope :undoable, -> { where.not(lots_data: nil) }

    # Removes the selected lots as they are now, keeping them for one undo; the selection empties (AC-7.3, AC-7.8).
    def self.remove!(selection)
      transaction do
        lots = selection.lots.to_a
        supersede!(selection.session)
        removal = create!(session: selection.session, account: selection.account, copies: lots.sum(&:quantity),
          lots_data: lots.map { |lot| lot.slice(:catalog_entry_id, :finish, :condition, :price_paid_cents, :quantity) })
        selection.account.lots.where(id: lots.map(&:id)).destroy_all
        selection.restart!(query: selection.query, sort: selection.sort)
        removal
      end
    end

    # Ends the chance to undo the session's earlier removal (AC-7.6).
    def self.supersede!(session) = session.bulk_removals.undoable.each { |removal| removal.update!(lots_data: nil) }

    def undoable? = !lots_data.nil?

    # Puts back exactly the removed lots, merging into lots of the same identity; all or nothing (AC-7.4, AC-7.5).
    def undo!(sort:)
      raise NotUndoable unless undoable?

      transaction do
        entries = Catalog::Entry.where(id: lots_data.pluck("catalog_entry_id")).index_by(&:id)
        Catalog::Entry.preload_extensions(entries.values)
        check_cap!(sort)
        lots_data.each do |data|
          Lot.add!(account:, entry: entries.fetch(data["catalog_entry_id"]), quantity: data["quantity"],
            finish: data["finish"], condition: data["condition"], price_paid_cents: data["price_paid_cents"])
        end
        update!(lots_data: nil)
      end
    end

    private
      def check_cap!(sort)
        over = lots_data.filter_map do |data|
          existing = account.lots.find_by(catalog_entry_id: data["catalog_entry_id"],
            lot_key: Lot.key_for(data["finish"], data["condition"], data["price_paid_cents"]))
          existing if existing && existing.quantity + data["quantity"] > Lot::MAX_QUANTITY
        end
        raise Lot::CapExceeded, sort.apply(account.lots.joins(entry: :set).where(id: over.map(&:id))).preload(entry: :set).first if over.any?
      end
  end
  ```
- [ ] Replace `app/models/session.rb`:
  ```ruby
  class Session < ApplicationRecord
    belongs_to :user
    # The database removes these with the session (ON DELETE CASCADE): sessions also end through
    # delete_all (User#end_sessions!, user deletion), which runs no callbacks (spec 006 FR-4, FR-6).
    has_one :bulk_selection
    has_many :bulk_removals
  end
  ```
- [ ] Write `app/controllers/collections/bulk_removals_controller.rb`:
  ```ruby
  # Removing every selected lot at once (spec 006 Story 7): a confirmation page first, then the
  # removal, with a one-time Undo in the status message.
  class Collections::BulkRemovalsController < ApplicationController
    include BulkSelected

    def new
      @copies = @selection.copies
      @lots_count = @selection.lots.count
    end

    def create
      return refuse(BulkSelection::NONE_LEFT) unless selection?

      removal = BulkRemoval.remove!(@selection)
      redirect_to @bulk_path, status: :see_other, notice: "Removed #{helpers.items_count(removal.copies)} from your collection.",
        flash: { undo: removal.id }
    end

    private
      def refuse(message)
        @copies, @lots_count = 0, 0
        flash.now[:alert] = message
        render :new, status: :unprocessable_content
      end
  end
  ```
- [ ] Write `app/controllers/collections/bulk_removals/undos_controller.rb`:
  ```ruby
  # Undo of a bulk removal, from the status message right after it (spec 006 AC-7.4–7.7). Only the
  # session that removed can undo, so any other removal is not found (AC-8.3).
  class Collections::BulkRemovals::UndosController < ApplicationController
    include CollectionListing

    def create
      removal = Current.session.bulk_removals.find(params[:bulk_removal_id])
      removal.undo!(sort: return_sort)
      redirect_to return_path, status: :see_other, notice: "Restored #{helpers.items_count(removal.copies)} to your collection."
    rescue BulkRemoval::NotUndoable
      refuse(BulkRemoval::NO_LONGER_UNDOABLE)
    rescue Lot::CapExceeded => error
      refuse(helpers.over_cap_message("Nothing restored.", error.lot))
    end

    private
      # The collection page the message was on; anything else lands on the collection (AC-7.4).
      def return_path
        @return_path ||= begin
          uri = URI.parse(url_from(params[:return_to]).to_s)
          [ uri.path, uri.query ].compact.join("?") if uri.path == collection_path
        rescue URI::InvalidURIError
          nil
        end || collection_path
      end

      def return_sort
        values = Rack::Utils.parse_query(URI.parse(return_path).query)
        CollectionTable::Sort.parse(values["sort"], values["dir"])
      end

      def refuse(message)
        prepare_collection_at(return_path)
        render_collection_refusal(message)
      end
  end
  ```
- [ ] In `app/controllers/lots_controller.rb`, `destroy`, add `BulkRemoval.supersede!(Current.session)` after `@lot.destroy!` (AC-7.6).
- [ ] Write `app/views/collections/bulk_removals/new.html.erb`:
  ```erb
  <% content_for :title, "Remove items · Collector" %>
  <%= render "layouts/appbar", section: :collection, detail: true, back_path: @bulk_path %>
  <main class="c-main c-page">
    <section class="c-confirm">
      <h1 class="c-pagehead__title">Remove <%= items_count(@copies) %>?</h1>
      <p>This removes <%= items_count(@copies) %> in <%= pluralize(number_with_delimiter(@lots_count), "lot") %> from your collection. You can undo this right afterwards.</p>
      <div class="c-form__actions">
        <%= button_to "Remove #{items_count(@copies)}", collection_bulk_removals_path(page: params[:page]), class: "c-btn c-btn--danger" %>
        <%= link_to "Cancel", @bulk_path, class: "c-btn c-btn--secondary" %>
      </div>
    </section>
  </main>
  <%= render "layouts/tabbar", section: :collection %>
  ```
- [ ] Replace `app/views/shared/_status_message.html.erb`:
  ```erb
  <%# locals: (message:, alert: false, undo: nil) %>
  <% if undo %>
    <%# After a bulk removal: the message and its one-time Undo, which returns to this page (spec 006 AC-7.3, AC-7.4). %>
    <div class="c-status__message c-status__message--action">
      <span><%= message %></span>
      <%= button_to "Undo", collection_bulk_removal_undo_path(undo), params: { return_to: request.fullpath },
            class: "c-btn c-btn--secondary c-btn--sm", form: { class: "c-status__action", data: { turbo_frame: "_top" } } %>
    </div>
  <% else %>
    <p class="c-status__message<%= " c-status__message--alert" if alert %>"><%= message %></p>
  <% end %>
  ```
- [ ] In `app/views/layouts/application.html.erb`, change the status line's render to pass the Undo:
  ```erb
  <div id="status" class="c-status" role="status" aria-live="polite"><% if (message = flash[:notice] || flash[:alert]) %><%= render "shared/status_message", message:, alert: flash[:alert].present?, undo: flash[:undo] %><% end %></div>
  ```
- [ ] Append to `app/assets/stylesheets/collector/additions.css`:
  ```css
  /* ---------- Status message with an action (spec 006): the sentence, then one small button ---------- */
  .c-status__message--action { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:var(--space-2); }
  .c-status__action { display:flex; }
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/models/bulk_removal_spec.rb spec/requests/bulk_removal_spec.rb spec/requests/lots_spec.rb spec/requests/bulk_mode_spec.rb && bin/brakeman -q` — expect PASS, with no Brakeman warnings.
- [ ] Commit: `feat(collection): remove the selected lots with a one-time undo`

---

## Phase 10: Design-system docs, phone sweep and query counts

**Implements:** FR-7, NFR Performance (bounded queries), NFR Accessibility (360px) | **Satisfies:** AC-2.8 (sweep), AC-4.4 (sweep), AC-7.9 (phone)
**Files:** `docs/design-system/components/{SortHeader,StatusAction,BulkConfirmPage,ChoicePage,BulkForm,ViewSwitchForm}.md`, `docs/design-system/README.md`, `spec/design_system_files_spec.rb`, `spec/system/narrow_pages_spec.rb`, `spec/requests/query_counts_spec.rb`
**Interfaces:** Consumes: every view above. Produces: nothing new.

- [ ] In `spec/design_system_files_spec.rb`, example "documents every new pattern and lists it in the README", extend `new_patterns` with `SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm`.
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect FAIL (the docs don't exist).
- [ ] Write one doc per pattern in the export's format: a title, one sentence on the purpose, **Markup** with the exact HTML the app renders (copied from the partial), then the rules as bullets. For example, `docs/design-system/components/BulkForm.md`:
  ````markdown
  # BulkForm

  The table in bulk mode as one form, so every tick reaches the server with whatever the collector presses next, with or without scripting.

  **Markup** — one `PATCH` form (`id="bulk"`) holds the bulk bar, the table and the pager. The filter input and a visually hidden Filter button live in the filter bar and join the form with `form="bulk"`.

  ```html
  <div class="c-filterbar" role="search">
    <label class="c-input">…<input type="search" name="q" form="bulk" aria-label="Search your collection"></label>
    <button type="submit" form="bulk" name="go" value="filter" class="c-sr" tabindex="-1">Filter</button>
    <div class="c-filterbar__end"><div class="c-seg" role="group" aria-label="View">…inert buttons…</div></div>
  </div>
  <form id="bulk" method="post" action="/collection/selection">
    <input type="hidden" name="_method" value="patch">
    <div class="c-bulkbar" role="region" aria-label="Bulk actions">…<button name="go" value="done" class="c-btn c-btn--primary c-btn--sm">Done</button></div>
    <table class="c-table">… <th aria-sort="ascending"><button name="go" value="/collection?bulk=1&amp;dir=desc&amp;sort=name" class="c-table__sort">Name</button></th> …</table>
    <nav class="c-pager" aria-label="Pagination"><button name="go" value="/collection?bulk=1&amp;page=2" class="c-btn c-btn--secondary c-btn--sm">Next</button></nav>
  </form>
  ```

  - Every control that leaves the page is a submit button named `go`: Filter, the sort headers, Previous/Next, the actions and Done. Links would lose unsubmitted ticks, and a hover prefetch must never change the selection.
  - Filter comes first in tree order, so Enter in the search field filters rather than running an action.
  - The view switch stays outside the form and is inert: Table pressed, Grid disabled.
  - Each submission sends `shown_ids[]`, `ticked_ids[]`, the header checkbox (`all`) and how it was rendered (`all_rendered`).
  ````
  Write the other five the same way, from their partials and `additions.css` rules:

  | Doc | Covers |
  |---|---|
  | `SortHeader` | `.c-table__sort` in a `th[aria-sort]`: a link outside bulk mode, a `go` button in it; the arrow comes from `aria-sort` |
  | `StatusAction` | `.c-status__message--action` with `.c-status__action`: one sentence plus one small secondary button (Undo) |
  | `BulkConfirmPage` | `ConfirmPage` for many items: "Remove <n> items?", items and lots stated, `Remove <n> items` (danger) and Cancel back to the bulk table |
  | `ChoicePage` | `.c-choices` fieldset of `.c-check` radios, Apply (primary) and Cancel, as a detail page |
  | `ViewSwitchForm` | `c-seg` buttons with `form="view-switch"` and the hidden GET forms (`#view-switch`, `#edit-many`) in the results frame |
- [ ] In `docs/design-system/README.md`, after the "App additions (spec 004 …)" paragraph, add: "App additions (spec 006, in `collector/additions.css`): `SortHeader`, `StatusAction`, `BulkConfirmPage`, `ChoicePage`, `BulkForm`, `ViewSwitchForm`. Upstream these into the published design system before the next export replaces this folder."
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect PASS.
- [ ] Commit: `docs(design): document the patterns added for spec 006`
- [ ] Add to `spec/requests/query_counts_spec.rb`:
  ```ruby
  it "keeps the table's queries independent of the number of lots, in and out of bulk mode", :aggregate_failures do
    user.update!(collection_view: "table")
    own(printing, finish: "foil")
    post collection_selection_path
    few = queries_for(collection_path)
    few_bulk = queries_for(collection_path(bulk: 1))
    29.times { |n| own(printing, condition: n.even? ? "near_mint" : nil) }
    expect(queries_for(collection_path)).to eq(few)
    expect(queries_for(collection_path(bulk: 1))).to eq(few_bulk)
  end
  ```
- [ ] Run: `bin/rspec spec/requests/query_counts_spec.rb` — expect PASS. If it fails, a row partial is querying per row. Fix it with `preload` in `CollectionTable#lots` or in `SelectionState`, and don't commit until it passes.
- [ ] Commit: `test(collection): bound the table's queries in and out of bulk mode`
- [ ] Extend `spec/system/narrow_pages_spec.rb` with a second example, in the same 360px driver:
  ```ruby
  it "never scrolls sideways on the table, bulk mode and its pages", :aggregate_failures do
    user = create(:user)
    owned_printing(account: user.account, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid_cents: 123_456)
    system_sign_in_as(user)
    fits = -> { page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth") }
    visit collection_path(view: "table")
    expect(fits.call).to be(true), "the table scrolls sideways"
    visit collection_path
    find(".c-filterbar__more summary").click
    click_on "Edit many"
    expect(fits.call).to be(true), "bulk mode scrolls sideways"
    check "Select all"
    find(".c-bulkbar__more summary").click
    click_on "Set condition…"
    expect(page).to have_css("h1", text: "Set the condition of 9,999 items")
    expect(fits.call).to be(true), "Set condition scrolls sideways"
    expect(page).to have_css(".c-appbar__back")
    find(".c-appbar__back").click
    find(".c-bulkbar__more summary").click
    click_on "Remove"
    expect(page).to have_css("h1", text: "Remove 9,999 items?")
    expect(fits.call).to be(true), "the removal confirmation scrolls sideways"
  end
  ```
- [ ] Run: `bin/rspec spec/system/narrow_pages_spec.rb` — expect PASS. A failure names the overflowing page; the fix goes in `additions.css` (tokens only), and the spec is re-run before committing.
- [ ] Commit: `test(design): check the table and bulk pages at 360px`

---

## Phase 11: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs, NFR Performance

- [ ] Run the full suite and local CI: `bin/ci` — expect every step green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Run `bin/rails zeitwerk:check` — expect "All is good!".
- [ ] Check migrations reverse cleanly: `bin/rails db:rollback STEP=3 && bin/rails db:migrate` — expect no errors and an unchanged `db/schema.rb` (`git diff --exit-code db/schema.rb`).
- [ ] Performance (NFR, manual). In development, with the catalog loaded, run this script:
  ```ruby
  # bin/rails runner tmp/perf_006.rb  (scratch file; not committed)
  user = User.find_or_create_by!(email_address: "perf@example.test") { |u| u.name = "Perf"; u.password = "correct horse battery" }
  account = user.account
  Catalog::Entry.searchable.limit(5_000).each { |entry| Lot.add!(account:, entry:) } if account.lots.count < 5_000
  session = user.sessions.create!
  time = ->(label, &block) { started = Process.clock_gettime(Process::CLOCK_MONOTONIC); block.call; puts format("%-28s %6.0f ms", label, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000) }
  CollectionTable::Sort::COLUMNS.product(%w[asc desc]).each do |column, direction|
    time.call("table #{column} #{direction}") { CollectionTable.new(account:, query: "", page: 1, sort: CollectionTable::Sort.parse(column, direction)).lots }
  end
  selection = BulkSelection.for(session)
  selection.record!(shown_ids: [], ticked_ids: [], header_rendered: false, header_ticked: true)
  time.call("set condition 5,000") { Lot::ConditionChange.new(account:, lots: selection.lots, condition: "near_mint", sort: selection.sort).apply! }
  removal = nil
  time.call("remove 5,000") { removal = BulkRemoval.remove!(selection) }
  time.call("undo 5,000 (not in NFR)") { removal.reload.undo!(sort: selection.sort) }
  ```
  Expect every table line under 500 ms, and Set condition and remove under 2,000 ms. Record the numbers in the PR description.
  - **If Set condition goes over 2 s:** in `Lot::ConditionChange#merge`, write lots with no merge (group of one, no existing target) through one `@account.lots.where(id: ids).update_all(condition: @condition, lot_key: …, updated_at: Time.current)` per target key. Add a same-line comment: tenant-scoped, the condition is already validated against the vocabulary, and the cap can't change without a merge. Re-run the script.
  - **If remove goes over 2 s:** replace `destroy_all` in `BulkRemoval.remove!` with `delete_all`, with the same kind of comment: `Lot` has no destroy callbacks, and `Account` already uses `dependent: :delete_all`.
- [ ] Walk the spec's ACs in the browser at 1280px and 390px, in light and dark themes (NFR Accessibility): switch views, sort, Edit many, tick, page, Select all, Set condition, Remove and Undo, Esc. Repeat the bulk flow with JavaScript disabled in the browser.
- [ ] Use `sdd-superpowers:verification-before-completion`, then `sdd-superpowers:sdd-review` (implementation mode, Fable).

---

## Quickstart Validation

1. `bin/setup --skip-server && bin/rails db:migrate && bin/dev` (the worktree's port is printed by `bin/setup`).
2. Sign in, add a few cards from Search with different finishes, then open **Collection**.
3. Choose **Table**. Expect one row per lot. Sort by **Condition**, then sort by it again to reverse it. Reload `/collection`: it's still the table.
4. Choose **Edit many**. Tick two rows; expect "<n> of <m> selected" to update without a reload. Choose **Next**, then **Previous**: the ticks are still there.
5. Choose **Set condition…**, then **Lightly played**, then **Apply**. Expect "Set the condition of <n> items to Lightly played." and those rows showing `LP`.
6. Tick **Select all**, choose **Remove**, then confirm. Expect "Removed <n> items from your collection." with **Undo**. Choose **Undo**: expect "Restored <n> items to your collection." and the rows back.
7. Press **Esc** (or **Done**). Expect the saved view, with the filter kept.
8. Repeat steps 4–6 with JavaScript disabled. Everything works; the count updates only on the next page.

---

## Spec coverage (self-review)

| Spec item | Phase |
|---|---|
| FR-1 (view preference) | 3, 6 (bulk never saves) |
| FR-2 (table, vocabulary, finish order) | 1, 2, 4 |
| FR-3 (sorting) | 1, 2, 6 (bulk headers) |
| FR-4 (bulk mode, selection, protocol, prefetch) | 5, 6, 7 |
| FR-5 (actions, 303/422, messages) | 6, 8, 9 |
| FR-6 (undo record) | 9 |
| FR-7 (design patterns) | 2, 6, 8, 9 (CSS), 10 (docs) |
| AC-1.1–1.6, 1.8–1.10, AC-8.5 | 3 |
| AC-1.7 | 3 (AC-11.7), 4 (return target), 9 (single remove ends Undo) |
| AC-2.1–2.5, 2.7 | 1, 2 |
| AC-2.6 | 4 |
| AC-2.8 | 7, 10 |
| AC-3.1–3.8 | 1, 2, 3 (switch keeps sort) |
| AC-4.1–4.5, 4.7, 4.8 | 6 |
| AC-4.4 (phone), 4.6 | 7 |
| AC-5.1–5.7, 5.9 | 5, 6 |
| AC-5.8 | 7 |
| AC-6.1–6.6 | 8 |
| AC-7.1–7.9 | 9 (7.9: 8 and 9) |
| AC-8.1, 8.2, 8.4 | 5, 6, 8, 9 |
| AC-8.3 | 9 |
| NFR performance | 10 (queries), 11 (timings) |
| NFR security (CSRF, allowlist, ids) | 1 (Arel only), 6, 8, 9; Brakeman in 9, 11 |
| NFR reliability (all or nothing, reversible, refresh) | 5, 8, 9, 11 |
| NFR accessibility | 2, 3, 6, 7, 10, 11 |
| Error scenarios | 2 (view, sort, page), 4 (return path), 6 (nothing selected, foreign ids, empty, no match), 8 (condition, cap, gone), 9 (Undo rows) |

**Gates:**
- **Simplicity:** 3 components and no new dependencies.
- **Anti-Abstraction:** framework features are used directly; the POROs each have one job.
- **Integration-First:** routing examples and request-spec contracts precede each phase's code.

**Verification gate:** every FR maps to a phase; every phase lists the ACs it satisfies and its interfaces; no placeholders; every code step shows complete code.
