# Plan: Spec 041, Move Many Lots at Once

**Spec:** [spec.md](spec.md) 0.4.0 (approved 2026-11-06)
**Issue:** [#48](https://github.com/plainprogrammer/Collector/issues/48), roadmap item 13. The pull request for this plan says "Refs #48"; the implementation pull request closes it.
**Method:** every task is one red-green cycle: write the spec, run it and see it fail for the stated reason, write the code, run it green, run `bin/rubocop -a` on the touched files. The code blocks are drafts against the code as read on 2026-11-06, not pre-run: an executor who finds a method or matcher that differs keeps the intent and records the deviation in the commit body.
**No migration, no new table, no export change** (decision 7): nothing a collector owns is added, so `docs/architecture/data-portability.md` and `docs/export-format/` don't change, and the Coverage-table guard stays green.

## Goal

"Move to…" in bulk mode, beside Set condition: it opens its own page with one To select, then moves every copy of the selected lots to one of the account's locations, or to none, in one write transaction, merging lots that reach one identity, holding the 9,999 cap, all or nothing. It works on "every matching lot" under the name and location filters.

## What exists today (read before changing)

- `Lot::ConditionChange` is the pattern: `apply!` in one `Lot.transaction`, `group_by` the new identity, `existing_targets`, `check_cap!` (raises `Lot::CapExceeded` with the first over-cap lot in `@sort` order), a one-statement `update_alone!` that rebuilds `lot_key` in SQL, and `merge`. `Lot::Move` is the one-lot move (merge into the destination's lot, which survives).
- `BulkSelection#lots` re-resolves the selection against the account, the name filter and the stored location filter; `include!(ids)` selects lots (under every-matching it deletes the exceptions' marks), `restart!(query:, sort:, location:)` empties it. Marks cascade on lot deletion (`bulk_selection_marks` foreign key, `on_delete: :cascade`); number-entry lines and scanner entries `nullify` (read as "Changed in your collection", spec 032 AC-7.6).
- `Collections::SelectionsController` records the page's ticks, then `ACTIONS` go to `act`, which redirects (303) to the action's page when `selection.lots.exists?`, else re-renders the bulk table with 422. `BulkSelected` (a concern) sets `@selection` and `@bulk_path` (the bulk table with its filters, sort and page) and redirects a GET with no selection (303, "Select at least one item.").
- `Collections::ConditionChangesController` is the closest controller; `collections/condition_changes/new.html.erb` the closest view; `lots/moves/new.html.erb` the closest To select; `shared/_field_errors` and `field_error_describedby` tie an error to its field.
- `CollectionFilter::Place::NONE` is `"none"`, `Place::ID` the id pattern. `account.locations.ordered` is the locations page's order (comparison key, then name).
- Key builders today (area doc: "Four places build a key"): `Lot.key_for`, the SQL in `Lot::ConditionChange#update_alone!`, `BulkRemoval#identity` with its `insert_all`, the apply's attribute builder.
- `spec/rails_helper.rb` excludes `:timing` examples unless `SCANNER_TIMING` is set; `spec/requests/collection_location_filter_timing_spec.rb` is the model for a timing example. Narrow phone widths run in a fixed-width iframe: `open_in_narrow_frame` / `within_narrow_frame` (`spec/support/narrow_frame.rb`).

## Design decisions the plan takes (each traces to the spec)

**D1. The key rule (FR-2): a fifth key builder, one SQL statement, with a parity spec.** Lots that move and meet no other lot of their identity (the common case: filing a box) are rewritten in one `UPDATE … SET location_id = ?, lot_key = <rebuilt from the row's columns> || ?, updated_at = ?` per 1,000 ids, exactly as `Lot::ConditionChange#update_alone!` does for the condition. The alternative, `lot.update!(location: to)` per lot, runs `Lot`'s validations: `finish_offered` and `condition_known` load the lot's entry and its vocabulary, an N+1 of at least two statements per lot, which for 5,000 lots does not fit the 2-second bar (spec 006 N set Set condition's one-statement update for the same reason). The lots that merge (a survivor) are written with `Lot.key_for` and a `where(id:).update_all` of their own row, one statement per survivor, which the NFR allows ("one statement per lot that merges or survives a merge"), and the folded lots are deleted in batched statements. Consequences, all in this plan: Task 2 writes the parity spec (ADR 0025 Consequences: "a spec per place"); Task 17 changes the area doc's "Four places build a key" to five and Task 18 CLAUDE.md's "four places build a `lot_key`". ADR 0025 is not edited (it records what was true on 2026-10-24; the area doc is the current truth).

**Why `update_all` and `delete_all` against `.claude/rules/models.md`.** The rule keeps normal flows on validations and tenant checks. The move keeps the checks it needs in its own code: every statement goes through `@account.lots`; the destination is looked up through the account; the cap is checked for every group before the first write; no write can collide (alone lots have a free identity, merging lots are deleted before survivors change key); `Lot` has no callbacks or dependents and the foreign keys cascade (marks) or nullify (number-entry lines, scanner entries). `Lot::ConditionChange#update_alone!` is the precedent, and each statement carries a `# Safe:` comment saying so.

**D2. Table order decides the survivor and the named lot.** `Lot::ConditionChange` takes `group.first` from an unordered relation. The move orders the selected lots with `sort.apply(lots.joins(entry: :set))` (the same ordering its cap message already uses), so "the first of them in the bulk table's order survives" (spec decision 4, AC-3.4) is true by construction. Ties break by id (`CollectionTable::Sort.default_order`).

**D3. Whose identity group counts a lot that is already there (decision 3).** The selected lots split into *movers* (place differs from the destination) and *stayers* (already there). Movers are grouped by `[entry id, Lot.key_for(…, destination id)]`. The destination's existing lot of that identity, selected stayer or not, is the group's target and survives. A stayer is never rewritten; it is only ever a target. "Moved" counts the movers' copies, "already there" the stayers' copies; every selected lot a stayer, so no mover, is `NothingToMove` (422).

**D4. The To field is the flat parameter `to`** (as Set condition's is `condition`): `""` is the prompt, `"none"` is No location, anything else must match `CollectionFilter::Place::ID` and name one of the account's locations, else 404. A missing parameter reads as `""`. A request body carries no nested `move[...]` hash, so a missing key is the prompt's 422, never a 400.

**D5. The order of answers (decision 6) is the order of before_actions and then of statements in `create`:** (1) `BulkSelected#set_selection` (a GET with no selection or no lot left: 303); (2) `require_locations` (no location: 303 "You have no locations yet.", any verb, whatever `to` was); (3) `create` with no selected lot: 422 `BulkSelection::NONE_LEFT`; (4) blank `to`: 422 on the To field; (5) a `to` that isn't `none` or an own location: 404; (6) the move and its refusals. A refusal never touches the selection.

**D6. The selection after a move** is one model method, `BulkSelection#after_move!(lot_ids)`: `include!(lot_ids)` when the stored location filter is `""` (AC-3.9), else `restart!` under the same query, sort and location (AC-3.13). The controller never branches on the filter.

**D7. Messages** live as constants on `Lot::BulkMove` (`CHOOSE`, `NO_LOCATIONS`) and its `NothingToMove` error (the "already in" text); the notice is `CollectionsHelper#moved_message`. Locations are named without quotation marks (decision 4).

**D8. The timing bar is a `:timing` RSpec example** (`spec/requests/bulk_move_timing_spec.rb`), run with `SCANNER_TIMING=1 bin/rspec --tag timing spec/requests/bulk_move_timing_spec.rb` (the coordinator's `--tag timing` plus the environment variable `rails_helper` reads to lift its exclusion). Its numbers go into `verification.md`.

## Files

| File | Change |
|---|---|
| `config/routes.rb` | `resource :move, only: %i[new create]` under `collection` |
| `app/models/lot/bulk_move.rb` | new: the move (`Lot::BulkMove`, `Result`, `NothingToMove`, `CHOOSE`, `NO_LOCATIONS`) |
| `app/models/bulk_selection.rb` | `after_move!` |
| `app/controllers/collections/selections_controller.rb` | `ACTIONS` gains `move`; `act` routes it; no locations is a navigation |
| `app/controllers/collections/moves_controller.rb` | new |
| `app/helpers/collections_helper.rb` | `moved_message` |
| `app/views/collections/_bulk.html.erb` | "Move to…" in the bar and the menu, while the account has a location |
| `app/views/collections/moves/new.html.erb` | new: the move page |
| `spec/models/lot/bulk_move_spec.rb` | new (Tasks 2–6) |
| `spec/models/bulk_selection_spec.rb` | `#after_move!` examples (Task 7) |
| `spec/routing/routes_spec.rb` | the two routes (Task 1) |
| `spec/requests/bulk_move_spec.rb` | new (Tasks 8–11, 13) |
| `spec/import_apply_core_spec.rb` | three files in its list (Task 12) |
| `spec/system/bulk_move_spec.rb` | new (Task 14) |
| `spec/requests/bulk_move_timing_spec.rb` | new (Task 15) |
| `docs/architecture/collection-and-lots.md`, `docs/design-system/components/BulkForm.md`, `Form.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/041-move-many-lots/verification.md` | Tasks 16–19 |

No component or token is new: the move page uses `c-main`, `c-page`, `c-pagehead`, `c-form`, `c-field`, `c-field__label`, `c-field__error`, `c-form__actions`, `c-btn`; the bar and menu reuse `c-btn c-btn--secondary c-btn--sm` and `c-menu__item`. No stylesheet changes (the `collector-design-system` skill is read before Tasks 8 and 9).

---

## Phase 1: The move itself (models)

### Task 1: The routes

**Implements:** FR-1 (the page exists). **Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`.

Test, next to the `condition_change` lines (line 68):

```ruby
expect(get: "/collection/move/new").to route_to("collections/moves#new")
expect(post: "/collection/move").to route_to("collections/moves#create")
```

Red: no route matches. Code, after `resource :condition_change` in `config/routes.rb`:

```ruby
      resource :condition_change, only: %i[new create]
      resource :move, only: %i[new create]
```

Helpers: `new_collection_move_path`, `collection_move_path`.

### Task 2: Move lots that meet no other lot, with the key parity

**Implements:** AC-3.1 (model half), AC-3.2, AC-3.10, FR-2 (same lot, same id; key rule; times). **Files:** `app/models/lot/bulk_move.rb`, `spec/models/lot/bulk_move_spec.rb`.

Tests (red: `NameError: uninitialized constant Lot::BulkMove`):

```ruby
require "rails_helper"

# Spec 041 Stories 3 and 4: moving many lots at once.
RSpec.describe Lot::BulkMove, type: :model do
  let(:account) { create(:user).account }
  let(:blue) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Long box") }
  let(:sort) { CollectionTable::Sort.parse(nil, nil) }

  def lot(entry = nil, **attributes) = create(:lot, account:, **{ entry: }.compact, **attributes)
  def move(lots, to, sort: self.sort) = described_class.new(account:, lots: account.lots.where(id: lots.map(&:id)), to:, sort:).apply!

  it "moves every copy to the destination, keeping each lot's id and added time (AC-3.1)", :aggregate_failures do
    lots = [ lot(location: box, quantity: 2), lot(location: box, quantity: 5), lot(quantity: 1) ]
    untouched = lot(location: box, quantity: 7)
    Lot.update_all(created_at: 1.day.ago, updated_at: 1.day.ago)
    result = move(lots, blue)
    expect(result).to have_attributes(ids: match_array(lots.map(&:id)), moved: 8, already_there: 0)
    expect(lots.map { |moved| moved.reload.location }).to eq([ blue, blue, blue ])
    expect(lots.map { |moved| moved.quantity }).to eq([ 2, 5, 1 ])
    expect(lots.map { |moved| moved.created_at < 1.hour.ago }).to all(be(true))   # the added time stays
    expect(lots.map { |moved| moved.updated_at > 1.hour.ago }).to all(be(true))   # the changed time is the move's
    expect(untouched.reload).to have_attributes(location: box, updated_at: be < 1.hour.ago)
  end

  it "moves to no location (AC-3.2)", :aggregate_failures do
    placed = lot(location: blue, quantity: 3)
    move([ placed ], nil)
    expect(placed.reload).to have_attributes(location_id: nil, lot_key: Lot.key_for(nil, nil, nil))
  end

  it "keeps lots that differ only in finish, condition or price paid separate (AC-3.10)" do
    entry = create(:mtg_printing).entry
    others = [ lot(entry, finish: "foil", location: box), lot(entry, condition: "damaged", location: box), lot(entry, price_paid_cents: 150, location: box) ]
    move(others, blue)
    expect(account.lots.where(location: blue).count).to eq(3)
  end

  it "keeps each moved lot's key equal to the one Lot.key_for gives, to a place and to none", :aggregate_failures do
    lots = [ lot(finish: "foil", location: box), lot(price_paid_cents: 150, condition: "damaged"), lot(price_paid_cents: 0, finish: "nonfoil", location: blue) ]
    [ blue, nil, box, blue ].each do |to|
      move(lots, to)
      expected = lots.map { |held| Lot.key_for(held.finish, held.condition, held.price_paid_cents, to&.id) }
      expect(Lot.where(id: lots.map(&:id)).order(:id).pluck(:lot_key)).to eq(expected)
    end
  end
end
```

(The last example moves lots whose own place is sometimes the destination; from the second pass on every lot is a stayer or a mover, which Task 3 pins down. It is here because it is the ADR 0025 parity spec for the fifth builder: `lot_key` is read from the database and compared with `Lot.key_for`, never with the SQL's own text.)

Code, `app/models/lot/bulk_move.rb` (Tasks 3 to 5 extend it; this is its first version, with the final names so later tasks only add):

```ruby
# Moves every copy of many lots to one location, or to none (spec 041). Lots that reach one identity in the destination
# merge into one (the destination's own lot survives, else the first moved lot in the bulk table's order); a selected lot
# already in the destination stays where it is (decision 3). All or nothing: the 9,999 cap is checked for every merge
# before anything is written. Collectible-agnostic.
#
# models.md says not to use update_all/delete_all in normal flows (they skip validations and tenant checks). The move does, as
# Lot::ConditionChange#update_alone! does, for the 2-second bar, and each statement is safe: scoped through @account.lots,
# values bound, the cap and every identity collision checked on the lots read in this transaction, the place looked up through
# the account, and Lot has no callbacks or dependents.
class Lot::BulkMove
  CHOOSE = "Choose where to move them.".freeze
  NO_LOCATIONS = "You have no locations yet.".freeze
  BATCH = 1_000 # ids per statement, well inside SQLite's bound-variable limit

  # +ids+: the lots now holding the moved copies; +moved+: the copies that moved; +already_there+: the selected copies that
  # were already in the destination.
  Result = Data.define(:ids, :moved, :already_there)

  # Every selected lot is already in the destination: nothing would change (spec 041 AC-3.7).
  class NothingToMove < StandardError
    attr_reader :to

    def initialize(to)
      @to = to
      super(to ? "The selected items are already in #{to.name}." : "The selected items already have no location.")
    end
  end

  # The selection selects no lot any more (removed in another tab): not "already there" (spec 041 decision 6 (3)).
  class NoLotsLeft < StandardError
    def initialize = super(BulkSelection::NONE_LEFT)
  end

  # +to+ is a Location of +account+, or nil for none. +lots+ is the selection's relation of the account's lots.
  def initialize(account:, lots:, to:, sort:)
    @account, @lots, @to, @sort = account, lots, to, sort
  end

  def apply!
    Lot.transaction do
      lots = @sort.apply(@lots.where(account_id: @account.id).joins(entry: :set)).to_a # the account's lots only, in the bulk table's order, read under the write lock
      raise NoLotsLeft if lots.empty?

      movers, stayers = lots.partition { |lot| lot.location_id != @to&.id }
      raise NothingToMove, @to if movers.empty?

      groups = movers.group_by { |lot| [ lot.catalog_entry_id, key_for(lot) ] }
      targets = existing_targets(groups.keys)
      alone = groups.select { |key, group| group.one? && !targets[key] }
      move_alone!(alone.values.map { |group| group.first.id }, Time.current)
      Result.new(ids: groups.map { |key, group| targets[key]&.id || group.first.id }, moved: movers.sum(&:quantity), already_there: stayers.sum(&:quantity))
    end
  end

  private
    def key_for(lot) = Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, @to&.id)

    # The destination's lots of the identities being moved in, selected or not. Only the entry and the place are filtered in
    # SQL: Lot::ConditionChange found long id lists on lot_key slow at 5,000 lots.
    def existing_targets(keys)
      @account.lots.where(location_id: @to&.id, catalog_entry_id: keys.map(&:first).uniq).index_by { |lot| [ lot.catalog_entry_id, lot.lot_key ] }.slice(*keys)
    end

    # Lots that keep their own identity apart from the place, in one statement per batch: lot_key is rebuilt as Lot.key_for
    # would, place included (a fifth key builder; spec 041 FR-2, ADR 0025). Merging lots are handled separately.
    def move_alone!(ids, now)
      suffix = @to ? "|#{@to.id}" : ""
      ids.each_slice(BATCH) do |slice|
        @account.lots.where(id: slice).update_all([ "location_id = ?, lot_key = COALESCE(finish, '') || '|' || COALESCE(condition, '') || '|' || COALESCE(price_paid_cents, '') || ?, updated_at = ?", @to&.id, suffix, now ]) # Safe: tenant-scoped; every value is bound; the destination was looked up through the account; the identity of each lot is free in the destination (checked against the lots read in this transaction); quantity, finish, condition and price don't change
      end
    end
end
```

Green: the four examples. Run `bin/rspec spec/models/lot/bulk_move_spec.rb`.

### Task 3: Lots already there; nothing to move

**Implements:** AC-3.6, AC-3.7, decision 3. **Files:** the same two.

Tests (red: the stayers are rewritten or counted as moved, and the all-there case doesn't raise):

```ruby
  it "leaves lots already there alone and counts their copies apart (AC-3.6)", :aggregate_failures do
    there = lot(location: blue, quantity: 3)
    coming = lot(location: box, quantity: 2)
    Lot.update_all(updated_at: 1.day.ago)
    result = move([ there, coming ], blue)
    expect(result).to have_attributes(moved: 2, already_there: 3, ids: [ coming.id ])
    expect(there.reload.updated_at).to be < 1.hour.ago
    expect(coming.reload.location).to eq(blue)
  end

  it "counts lots already unplaced the same way for no location (AC-3.6)" do
    expect(move([ lot(quantity: 4), lot(location: box, quantity: 1) ], nil)).to have_attributes(moved: 1, already_there: 4)
  end

  it "refuses when every selected lot is already there, naming the place, and changes nothing (AC-3.7)", :aggregate_failures do
    there = lot(location: blue)
    expect { move([ there ], blue) }.to raise_error(described_class::NothingToMove, "The selected items are already in Blue binder.")
    unplaced = lot
    expect { move([ unplaced ], nil) }.to raise_error(described_class::NothingToMove, "The selected items already have no location.")
    expect(there.reload.location).to eq(blue)
  end
```

Code: Task 2's `apply!` already splits movers and stayers and raises, so the first and third examples pass on arrival if Task 2 is right; if one is red, the fix is in `partition`. Run them first; a pass on arrival is recorded in the commit body as a characterisation of Task 2's code, not as a missing red.

### Task 4: Merges

**Implements:** AC-3.3, AC-3.4, AC-3.5, AC-3.12, decision 4, FR-2 (merge rules, same lot kept when no meeting). **Files:** the same two.

Tests (red: `merging` groups are never written, so the moved lots keep their old place):

```ruby
  describe "merging" do
    let(:entry) { create(:mtg_printing).entry } # a printing with no lot yet: lot.entry would be an unplaced lot's identity, and a second unplaced lot(entry) would hit the unique index

    it "merges a moved lot into the destination's lot of its identity, which survives (AC-3.3)", :aggregate_failures do
      moved = lot(entry, location: box, quantity: 2)
      survivor = lot(entry, location: blue, quantity: 3)
      expect(move([ moved ], blue).ids).to eq([ survivor.id ])
      expect(survivor.reload.quantity).to eq(5)
      expect(Lot.exists?(moved.id)).to be(false)
    end

    it "makes selected lots of one identity one lot, the first in the table's order surviving (AC-3.4)", :aggregate_failures do
      first = lot(entry, quantity: 4)             # unplaced, lower id
      second = lot(entry, location: box, quantity: 2)
      Lot.update_all(created_at: 1.day.ago)
      expect(move([ first, second ], blue).ids).to eq([ first.id ])
      expect(first.reload.created_at).to be < 1.hour.ago # the survivor keeps its added time
      expect(first.reload).to have_attributes(location: blue, quantity: 6, lot_key: Lot.key_for(nil, nil, nil, blue.id))
      expect(Lot.exists?(second.id)).to be(false)
    end

    it "lets the sort choose the survivor (AC-3.4)", :aggregate_failures do
      many = lot(entry, quantity: 4)
      few = lot(entry, location: box, quantity: 2)
      by_quantity = CollectionTable::Sort.parse("quantity", "asc")
      expect(move([ many, few ], blue, sort: by_quantity).ids).to eq([ few.id ])
      expect(few.reload.quantity).to eq(6)
    end

    it "folds two moved lots into the destination's lot when it has the identity (AC-3.5)", :aggregate_failures do
      a = lot(entry, quantity: 4)
      b = lot(entry, location: box, quantity: 2)
      held = lot(entry, location: blue, quantity: 1)
      expect(move([ a, b ], blue).ids).to eq([ held.id ])
      expect([ held.reload.quantity, Lot.where(id: [ a, b ]).count ]).to eq([ 7, 0 ])
    end

    it "treats a selected lot already there as the target, and counts its copies as already there (AC-3.12)", :aggregate_failures do
      a = lot(entry, location: box, quantity: 2)
      b = lot(entry, location: blue, quantity: 3)
      result = move([ a, b ], blue)
      expect(result).to have_attributes(ids: [ b.id ], moved: 2, already_there: 3)
      expect([ b.reload.quantity, Lot.exists?(a.id) ]).to eq([ 5, false ])
    end

    it "reads a number-entry line as changed when its lot is folded away, and names the new place when its lot moved whole (spec 041 decision 6; spec 032 AC-7.6; spec 034 decision 3)", :aggregate_failures do
      folded = NumberEntry.add!(account:, entry:, quantity: 2, finish: nil, line_key: "a" * 32).line
      moved = NumberEntry.add!(account:, entry: create(:mtg_printing).entry, quantity: 1, finish: nil, line_key: "b" * 32).line
      held = lot(entry, location: blue, quantity: 3)
      move(account.lots.where(id: [ folded.lot_id, moved.lot_id ]).to_a, blue)
      expect(folded.reload).not_to be_undoable           # its lot is gone: "Changed in your collection"
      expect(moved.reload).to be_undoable
      expect(moved.lot.location).to eq(blue)              # the line names its lot's new place
      expect(held.reload.quantity).to eq(5)
    end

    it "keeps lots of other places and identities as they were", :aggregate_failures do
      a = lot(entry, quantity: 2)
      other_finish = lot(entry, finish: "foil", quantity: 1)
      move([ a ], blue)
      expect(other_finish.reload).to have_attributes(location: nil, quantity: 1)
    end
  end
```

Code: replace `Task 2`'s tail of `apply!` and add the writers (the folded lots are deleted first so a survivor's new key can never meet a lot about to disappear; the survivor's key comes from `Lot.key_for` through the group's key):

```ruby
      groups = movers.group_by { |lot| [ lot.catalog_entry_id, key_for(lot) ] }
      targets = existing_targets(groups.keys)
      alone, merging = groups.partition { |key, group| group.one? && !targets[key] }
      now = Time.current
      delete!(merging.flat_map { |key, group| targets[key] ? group : group.drop(1) }.map(&:id))
      merging.each { |key, group| merge!(key, group, targets[key], now) }
      move_alone!(alone.map { |_, group| group.first.id }, now)
      Result.new(ids: groups.map { |key, group| targets[key]&.id || group.first.id }, moved: movers.sum(&:quantity), already_there: stayers.sum(&:quantity))
```

```ruby
    # The destination's lot gains the copies and survives; with none, the group's first lot takes the place and the sum.
    # One statement per surviving lot, written with Lot.key_for's text (key.last): validations would load each lot's entry
    # and vocabulary, and the cap, the place and the tenant are checked above.
    def merge!(key, group, target, now)
      if target
        @account.lots.where(id: target.id).update_all(quantity: target.quantity + group.sum(&:quantity), updated_at: now) # Safe: tenant-scoped; the cap was checked for this sum
      else
        @account.lots.where(id: group.first.id).update_all(location_id: @to&.id, lot_key: key.last, quantity: group.sum(&:quantity), updated_at: now) # Safe: tenant-scoped; the cap was checked; the key is Lot.key_for's
      end
    end

    # The database nulls or cascades what points at a lot (number-entry lines, scanner entries, marks).
    def delete!(ids)
      ids.each_slice(BATCH) { |slice| @account.lots.where(id: slice).delete_all } # Safe: tenant-scoped, bound ids
    end
```

Green: the six examples plus Tasks 2 and 3's. The unique index `[account_id, catalog_entry_id, lot_key]` backs the writes: a wrong key here raises `ActiveRecord::RecordNotUnique` in these examples.

### Task 5: The cap, atomicity, the destination removed meanwhile

**Implements:** AC-3.8, FR-2 (all or nothing, the cap names a *selected* lot), Reliability. **Files:** the same two.

Tests (red: without `check_cap!` an over-cap merge reaches the `lots_quantity_range` check constraint and raises `ActiveRecord::StatementInvalid`, not `CapExceeded`; the cap examples fail for that reason). Four examples pass on arrival and are characterisations of Tasks 2 to 4, named so in the commit, as Task 3's are: the foreign-key rollback, `NoLotsLeft`, "touches only the account's lots" and "allows exactly 9,999":

```ruby
  describe "the 9,999 cap" do
    let(:entry) { create(:mtg_printing).entry } # a printing with no lot yet: lot.entry would be an unplaced lot's identity, and a second unplaced lot(entry) would hit the unique index

    it "changes nothing and names the first selected lot of an over-cap identity (AC-3.8)", :aggregate_failures do
      fine = lot(location: box)
      over = lot(entry, location: box, quantity: 5_000)
      other = lot(entry, quantity: 5_000)
      expect { move([ fine, over, other ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(over) }
      expect(Lot.order(:id).pluck(:location_id)).to eq([ box.id, box.id, nil ]) # every lot where it was
    end

    it "names a selected lot when the over-cap destination lot is unselected (AC-3.8)", :aggregate_failures do
      moved = lot(entry, location: box, quantity: 9_000)
      lot(entry, location: blue, quantity: 1_000)
      expect { move([ moved ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(moved) }
    end

    it "names the selected destination lot when it comes first in the table's order (AC-3.8)", :aggregate_failures do
      held = lot(entry, location: blue, quantity: 9_000)
      moved = lot(entry, location: box, quantity: 1_000)
      expect { move([ moved, held ], blue) }.to raise_error(Lot::CapExceeded) { |error| expect(error.lot).to eq(held) }
    end

    it "allows exactly 9,999" do
      lot(entry, location: blue, quantity: 9_000)
      expect(move([ lot(entry, location: box, quantity: 999) ], blue).moved).to eq(999)
    end
  end

  it "changes nothing when the destination was removed meanwhile, and raises the foreign key error", :aggregate_failures do
    gone = create(:location, account:)
    alone = lot(location: box)
    merged = lot(location: box, quantity: 2)
    twin = lot(merged.entry, quantity: 1)
    Location.where(id: gone.id).delete_all
    expect { move([ alone, merged, twin ], gone) }.to raise_error(ActiveRecord::InvalidForeignKey)
    expect([ alone.reload.location, merged.reload.quantity, Lot.exists?(twin.id) ]).to eq([ box, 2, true ])
  end

  it "raises NoLotsLeft, not 'already there', when the relation selects no lot of the account", :aggregate_failures do
    theirs = create(:lot, account: create(:user).account)
    expect { described_class.new(account:, lots: Lot.where(id: theirs.id), to: blue, sort:).apply! }.to raise_error(described_class::NoLotsLeft, BulkSelection::NONE_LEFT)
    expect(theirs.reload.location).to be_nil
  end

  it "touches only the account's lots", :aggregate_failures do
    theirs = create(:lot, account: create(:user).account, quantity: 2)
    mine = lot
    described_class.new(account:, lots: Lot.where(id: [ mine.id, theirs.id ]), to: blue, sort:).apply!
    expect([ mine.reload.location, theirs.reload.location ]).to eq([ blue, nil ])
  end
```

Two details the examples fix: the foreign-key example passes a Location object whose row is gone, so the failure is the database's, exactly the production case behind `Lots::MovesController`'s `rescue_from`; "touches only the account's lots" passes a relation that reaches another account's lot and proves the read's account guard (`@lots.where(account_id: @account.id)`) in `apply!`; the writers' own `@account.lots.where(id:)` scoping is a second line the examples can't reach, since a foreign lot never gets that far, and it is checked by reading (and `Brakeman`/review), not by an example.

Code, in `apply!` between `existing_targets` and the writes:

```ruby
      check_cap!(groups, targets, lots.to_set(&:id))
```

```ruby
    # Every merge is checked before anything is written (spec 041 AC-3.8). The lot named is the first, in the table's order,
    # among the *selected* lots of the over-cap identities: the moved lots and a selected lot already there; an unselected
    # destination lot may not be in the table.
    def check_cap!(groups, targets, selected)
      over = groups.select { |key, group| group.sum(&:quantity) + (targets[key]&.quantity || 0) > Lot::MAX_QUANTITY }
      return if over.empty?

      named = over.flat_map { |key, group| group + [ targets[key] ].compact.select { |target| selected.include?(target.id) } }
      raise Lot::CapExceeded, @sort.apply(@account.lots.joins(entry: :set).where(id: named.map(&:id))).preload(entry: :set).first
    end
```

The `account.lots` scoping in `existing_targets`, `check_cap!` and every writer is the tenant rule; the first read, `@lots`, is the caller's relation (`BulkSelection#lots` is account-scoped; Task 5's last example proves the writers don't depend on it).

### Task 6: A bounded number of statements

**Implements:** NFR Performance (statement count), AC-4.4's precondition. **Files:** `spec/models/lot/bulk_move_spec.rb` (code unchanged unless red).

```ruby
  def queries_during
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  describe "statement counts" do
    before { blue } # the lazy let would otherwise INSERT inside the counted block

    it "runs as many statements for 12 lots that merge with nothing as for 2" do
      few = Array.new(2) { lot(location: box) }
      many = Array.new(12) { lot(location: box) }
      expect(queries_during { move(many, blue) }).to eq(queries_during { move(few, blue) })
    end

    it "writes one statement per survivor and batches the deletes of folded lots" do
      entries = Array.new(6) { create(:mtg_printing).entry }
      pairs = entries.flat_map { |entry| [ lot(entry, location: box), lot(entry) ] } # six groups of two, each merging
      two_groups = queries_during { move(pairs.first(4), blue) }  # groups 1 and 2
      four_groups = queries_during { move(pairs.last(8), blue) }  # groups 3 to 6, none seen by the first move
      expect(four_groups - two_groups).to eq(2) # two more groups, two more survivor statements; the folded lots go in one batch either way
    end
  end
```

Green on arrival if Tasks 2 to 5 are written as above; these are the characterisation of the NFR and are named so in the commit.

### Task 7: The selection after a move

**Implements:** AC-3.9, AC-3.13, decision 6, AC-3.11 (no removal supersession; the model has no call to `BulkRemoval`). **Files:** `app/models/bulk_selection.rb`, `spec/models/bulk_selection_spec.rb`.

Tests, appended to the `BulkSelection` spec (it already has `own`, `tick`, `default_sort`, `selection`):

```ruby
  describe "#after_move! (spec 041)" do
    let(:blue) { create(:location, account:) }

    it "selects the lots that now hold the moved copies under all locations, an excepted one too (AC-3.9)", :aggregate_failures do
      a = own("Card A")
      excepted = own("Card B")
      selection.restart!(query: "", sort: default_sort)
      tick([ a, excepted ], [ a ], header_ticked: true, baseline: [ a, excepted ], header_toggled: true)
      expect(selection.lots).to contain_exactly(a)
      selection.after_move!([ excepted.id ])
      expect(selection.lots).to contain_exactly(a, excepted)
    end

    it "marks the surviving lots of a ticked-set selection (AC-3.9)" do
      a = own("Card A")
      b = own("Card B")
      tick([ a, b ], [ a ])
      selection.after_move!([ b.id ])
      expect(selection.lots).to contain_exactly(a, b)
    end

    it "restarts empty under the same filters and sort when a location filter is set (AC-3.13)", :aggregate_failures do
      a = own("Card A", location: blue)
      selection.restart!(query: "card", sort: CollectionTable::Sort.parse("name", "desc"), location: blue.id.to_s)
      tick([ a ], [ a ])
      selection.after_move!([ a.id ])
      expect(selection.lots).to be_empty
      expect(selection.context?("card", CollectionTable::Sort.parse("name", "desc"), location: blue.id.to_s)).to be(true)
      expect(selection.all_matching?).to be(false)
    end

    it "restarts under none the same way (AC-3.13)" do
      a = own("Card A")
      selection.restart!(query: "", sort: default_sort, location: CollectionFilter::Place::NONE)
      tick([ a ], [ a ])
      selection.after_move!([ a.id ])
      expect(selection.lots).to be_empty
    end
  end
```

Red: `NoMethodError: undefined method 'after_move!'`. Code, after `restart!` in `BulkSelection`:

```ruby
  # After a move (spec 041 decision 6): under all locations the moved lots still match, so the lots now holding the moved
  # copies are selected (a merged survivor, an excepted destination lot too, as after Set condition, AC-3.9); under a
  # location or "No location" they no longer match, so the selection restarts empty under the same filters and sort, as
  # after Remove (AC-3.13; spec 037 AC-5.6).
  def after_move!(lot_ids)
    return include!(lot_ids) if location_filter.empty?

    restart!(query: query, sort: sort, location: location_filter)
  end
```

---

## Phase 2: The action in bulk mode

Read `.claude/skills/collector-design-system/SKILL.md`, `docs/design-system/README.md`, `BulkForm.md`, `Form.md`, `CollectionTable.md` before Tasks 8 and 9.

### Task 8: "Move to…" in the bar, the menu and the selections controller

**Implements:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, FR-1. **Files:** `app/views/collections/_bulk.html.erb`, `app/controllers/collections/selections_controller.rb`, `spec/requests/bulk_move_spec.rb` (new; later tasks append).

The spec file's head (used by Tasks 8 to 11 and 13):

```ruby
require "rails_helper"

# Spec 041: "Move to…" in bulk mode.
RSpec.describe "Bulk Move to…", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }
  let!(:box) { create(:location, account:, name: "Long box") }

  before { sign_in_as(user) }

  def own(name = "Lightning Bolt", **options) = owned_printing(name, account:, **options)
  def twin(lot, **options) = create(:lot, account:, entry: lot.entry, **options)
  def page_html = Nokogiri::HTML5(response.body)
  def bar_count = page_html.at_css(".c-bulkbar__count").text
  def selected_names = page_html.css("tbody tr[aria-selected=true]").map { |row| row.at_css("a")&.text.to_s }

  # Edit many, then the bulk form's submission for the pressed control: it records the page's ticks first (spec 006 FR-4).
  def select_lots(*lots, go: "move", location: "", page: nil)
    post collection_selection_path, params: { location: }
    patch collection_selection_path, params: { go:, q: "", rendered_q: "", rendered_location: location, all_rendered: "0", page:,
      shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }.compact
  end

  # "Select all", with the exceptions unticked (they were ticked when the page rendered).
  def select_everything(shown, except: [], go: "move", location: "")
    post collection_selection_path, params: { location: }
    patch collection_selection_path, params: { go:, rendered_q: "", rendered_location: location, all_rendered: "0", all: "1", header_toggled: "1",
      shown_ids: shown.map(&:id), baseline_ids: shown.map(&:id), ticked_ids: (shown - except).map(&:id) }
  end
```

Tests (red: the bar has two buttons; `go=move` is not an action):

```ruby
  describe "the bulk bar (Story 1)" do
    it "offers Move to… after Set condition and before Remove, in the bar and in the menu (AC-1.1)", :aggregate_failures do
      own
      post collection_selection_path
      get collection_path(bulk: 1)
      expect(page_html.css(".c-bulkbar__extra button").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      expect(page_html.css(".c-bulkbar__more .c-menu__item").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      button = page_html.at_css('.c-bulkbar__extra button[value=move]')
      expect([ button["form"], button["name"], button["type"] ]).to eq(%w[bulk go submit])
    end

    context "when the account has no location (AC-1.2)" do
      before { Location.where(account:).delete_all }

      it "offers no Move to…, and a submission asking for it is a navigation that moves nothing", :aggregate_failures do
        lot = own
        post collection_selection_path
        get collection_path(bulk: 1)
        expect(page_html.css(".c-bulkbar button").map(&:text)).to eq([ "Set condition…", "Remove", "Set condition…", "Remove", "Done" ])
        select_lots(lot)
        expect(response).to redirect_to(collection_path(bulk: 1))
        expect(response).to have_http_status(:see_other)
        expect(lot.reload.location).to be_nil
      end
    end
  end

  describe "pressing Move to…" do
    it "records the ticks and opens the move page, keeping the page (AC-1.3)", :aggregate_failures do
      lot = own
      select_lots(lot, page: 1)
      expect(response).to redirect_to(new_collection_move_path(page: 1)) # act passes the submitted page on
      expect(response).to have_http_status(:see_other)
      select_lots(lot, page: 3)
      expect(response).to redirect_to(new_collection_move_path(page: 3))
      get new_collection_move_path
      expect(page_html.at_css("h1").text).to eq("Move 1 item") # the ticks were recorded
    end

    it "refuses with the bulk table when nothing is selected (AC-1.4)", :aggregate_failures do
      own
      select_lots(go: "move")
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("Select at least one item.")
      expect(page_html.at_css(".c-bulkbar")).to be_present
    end

    it "refuses when the ticked lot was removed in another tab (AC-1.5)", :aggregate_failures do
      gone = own
      post collection_selection_path
      gone.destroy!
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ gone.id ], ticked_ids: [ gone.id ] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
    end

    it "refuses when every ticked lot is another account's, so none is left (AC-1.5, AC-5.1)", :aggregate_failures do
      theirs = create(:lot, account: create(:user).account)
      post collection_selection_path
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ theirs.id ], ticked_ids: [ theirs.id ] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
    end
  end
```

(Scanner sitting entries share the number-entry line's mechanism, `on_delete: :nullify` on the lot, which Task 4's number-entry example exercises; spec 032's own examples cover the scanner's read.)

Code, `Collections::SelectionsController`:

```ruby
  ACTIONS = %w[set_condition move remove].freeze
```

```ruby
    ACTIONS.include?(params[:go]) && offered?(params[:go]) ? act(selection, query, location, sort) : navigate(selection, *destination(query, location, sort))
```

```ruby
    # "Move to…" is offered only while the account has a location; asked for without one it is a navigation (spec 041 AC-1.2).
    def offered?(action) = action != "move" || Current.account.locations.exists?
```

and in `act`:

```ruby
      if selection.lots.exists?
        path = case params[:go]
        when "remove" then new_collection_bulk_removal_path(page:)
        when "move" then new_collection_move_path(page:)
        else new_collection_condition_change_path(page:)
        end
        redirect_to path, status: :see_other
```

(`navigate` for `go=move` falls into `destination`'s last branch: `collection_values("move")` parses no collection path and returns nil, so the page, filters and sort are kept.)

`_bulk.html.erb`: inside `.c-bulkbar__extra`, between Set condition and Remove, and inside the menu between Set condition and the separator:

```erb
        <%= button_tag "Set condition…", type: "submit", form: "bulk", name: "go", value: "set_condition", class: "c-btn c-btn--secondary c-btn--sm" %>
        <% if table.places? %><%= button_tag "Move to…", type: "submit", form: "bulk", name: "go", value: "move", class: "c-btn c-btn--secondary c-btn--sm" %><% end %>
        <%= button_tag "Remove", … %>
```

```erb
          <%= button_tag "Set condition…", type: "submit", form: "bulk", name: "go", value: "set_condition", class: "c-menu__item" %>
          <% if table.places? %><%= button_tag "Move to…", type: "submit", form: "bulk", name: "go", value: "move", class: "c-menu__item" %><% end %>
          <div class="c-menu__sep"></div>
```

### Task 9: The move page and the answers to a GET

**Implements:** AC-1.6, AC-1.7 (GET), AC-2.1, AC-2.4, AC-5.4, FR-3 (the GET answers), NFR (page queries, accessibility markup). **Files:** `app/controllers/collections/moves_controller.rb`, `app/views/collections/moves/new.html.erb`, `spec/requests/bulk_move_spec.rb`.

Tests (red: `ActionController::RoutingError`/`uninitialized constant Collections::MovesController`):

```ruby
  describe "the move page (Story 2)" do
    it "says how many items, offers a required To select and Cancel back to the bulk table (AC-2.1, AC-2.4)", :aggregate_failures do
      lots = Array.new(4) { |i| own("Card #{i}", quantity: 3) }
      select_lots(*lots, page: 2)
      get new_collection_move_path(page: 2)
      expect(response).to have_http_status(:ok)
      expect(page_html.at_css("h1").text).to eq("Move 12 items")
      select = page_html.at_css("select#to")
      expect([ select["name"], select["required"] ]).to eq([ "to", "required" ])
      expect(page_html.css("select#to option").map { |option| [ option.text, option["value"] ] })
        .to eq([ [ "Choose…", "" ], [ "No location", "none" ], [ "Blue binder", blue.id.to_s ], [ "Long box", box.id.to_s ] ])
      expect(page_html.at_css("select#to option[selected]").text).to eq("Choose…")
      expect(page_html.at_css("label[for=to]").text).to eq("To")
      expect(page_html.at_css("input[type=submit]")["value"]).to eq("Move")
      expect(page_html.at_css(".c-form__actions a")["href"]).to eq(collection_path(bulk: 1, page: 2))
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(collection_path(bulk: 1, page: 2))
      expect(page_html.at_css("main form.c-form")["action"]).to eq(collection_move_path(page: 2)) # the appbar has a Sign out form of its own
    end

    it "says 'Move 1 item' for one copy" do
      select_lots(own)
      get new_collection_move_path
      expect(page_html.at_css("h1").text).to eq("Move 1 item")
    end

    it "leaves out the selection's own place (AC-2.1)", :aggregate_failures do
      in_box = own(location: box)
      select_lots(in_box, location: box.id.to_s)
      get new_collection_move_path
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "No location", "Blue binder" ])
      unplaced = own("Opt")
      select_lots(unplaced, location: CollectionFilter::Place::NONE)
      get new_collection_move_path
      expect(page_html.css("select#to option").map(&:text)).to eq([ "Choose…", "Blue binder", "Long box" ])
    end

    it "keeps the tab bar on Collection, as Set condition's page does" do
      select_lots(own)
      get new_collection_move_path
      expect(page_html.at_css('.c-tabbar a[aria-current="page"]').text).to include("Collection")
    end
  end

  describe "the GET answers (decision 6)" do
    it "sends the collector back to the bulk table when nothing is selected (AC-1.6)" do
      get new_collection_move_path
      expect([ response.location, flash[:alert] ]).to eq([ "http://www.example.com#{collection_path(bulk: 1)}", "Select at least one item." ])
    end

    it "does the same for a selection whose lots are gone (decision 6 (1))", :aggregate_failures do
      lot = own
      select_lots(lot)
      lot.destroy!
      get new_collection_move_path
      expect([ response.status, flash[:alert] ]).to eq([ 303, "Select at least one item." ])
    end

    it "answers 'You have no locations yet.' with a selection and no location (AC-1.7)", :aggregate_failures do
      lot = own
      select_lots(lot)
      Location.where(account:).delete_all
      get new_collection_move_path
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:alert]).to eq("You have no locations yet.")
      get collection_path(bulk: 1)
      expect(bar_count).to eq("1 of 1 selected") # the selection is kept
    end

    it "asks nothing of the selection or the lots when the request is a prefetch (AC-5.4)", :aggregate_failures do
      lot = own
      select_lots(lot)
      expect { get new_collection_move_path, headers: { "X-Sec-Purpose" => "prefetch" } }.not_to change { [ Lot.pluck(:id, :location_id, :updated_at), BulkSelection::Mark.count ] }
    end

    it "runs the same queries for 1 and 30 selected lots and for 1 and 30 locations (NFR)" do
      select_lots(own)
      get new_collection_move_path
      few = count_queries { get new_collection_move_path }
      lots = Array.new(29) { |i| own("Card #{i}") }
      29.times { create(:location, account:) }
      select_lots(*lots, own("Another"))
      expect(count_queries { get new_collection_move_path }).to eq(few)
    end
  end
```

(`BulkSelection::Mark` is the marks model, `has_many :marks, class_name: "BulkSelection::Mark"`. The prefetch example passes on arrival: `new` changes nothing. It is the AC-5.4 guard, recorded as a characterisation in the commit.)

Code, `app/controllers/collections/moves_controller.rb` (`create` arrives in Task 10; this task adds `new` and the shared before_actions):

```ruby
# Moving every copy of the selected lots to one location, or to none, from its own page (spec 041). A bulk action like Set
# condition: the page's ticks were recorded first, and every answer returns to the bulk table it came from.
class Collections::MovesController < ApplicationController
  include BulkSelected

  before_action :require_locations
  before_action :set_destinations

  rescue_from(ActiveRecord::InvalidForeignKey) { raise ActiveRecord::RecordNotFound } # the destination was removed meanwhile

  def new
    @copies = @selection.copies
    @to = ""
  end

  private
    # The order of answers (decision 6): BulkSelected has answered a GET with nothing selected; an account with no location
    # has nothing to move to, whatever was submitted. The selection is kept.
    def require_locations
      redirect_to @bulk_path, status: :see_other, alert: Lot::BulkMove::NO_LOCATIONS unless Current.account.locations.exists?
    end

    # The To field's options: the prompt (""), "No location" ("none", the location filter's word, spec 037 decision 1), then the
    # account's locations in the locations page's order; the selection's own place is left out (AC-2.1).
    def set_destinations
      own = @selection&.location_filter.to_s
      locations = Current.account.locations.ordered.reject { |location| location.id.to_s == own }
      @destinations = [ [ "Choose…", "" ] ] + (own == CollectionFilter::Place::NONE ? [] : [ [ "No location", CollectionFilter::Place::NONE ] ]) +
        locations.map { |location| [ location.name, location.id ] }
    end
end
```

`app/views/collections/moves/new.html.erb`:

```erb
<% content_for :title, "Move items · Collector" %>
<%= render "layouts/appbar", section: :collection, detail: true, back_path: @bulk_path %>
<main class="c-main c-page">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">Move <%= items_count(@copies) %></h1></div></div>
  <% to_errors = @to_errors || [] %>
  <%= form_with url: collection_move_path(page: params[:page]), class: "c-form" do |form| %>
    <div class="c-field<%= " c-field--invalid" if to_errors.any? %>">
      <%= label_tag :to, "To", class: "c-field__label" %>
      <%= select_tag :to, options_for_select(@destinations, @to), required: true, "aria-describedby": field_error_describedby("to-error", to_errors) %>
      <%= render "shared/field_errors", messages: to_errors, id: "to-error" %>
    </div>
    <div class="c-form__actions">
      <%= form.submit "Move", class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", @bulk_path, class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
</main>
<%= render "layouts/tabbar", section: :collection %>
```

A plain `<form method="post">` with a `required` select and no `data-controller`: no scripting is involved (AC-6.1, Task 13). `c-pagehead + .c-form` already spaces them (Form.md).

### Task 10: The move, with its notice and its selection

**Implements:** AC-3.1, AC-3.2, AC-3.3 (request), AC-3.6, AC-3.9, AC-3.11, AC-3.12, AC-3.13, AC-4.1, AC-4.2, AC-4.3, FR-3 (the success answer). **Files:** `app/controllers/collections/moves_controller.rb`, `app/helpers/collections_helper.rb`, `spec/requests/bulk_move_spec.rb`.

Tests (red: `AbstractController::ActionNotFound`, `create` missing):

```ruby
  describe "moving (Story 3)" do
    it "moves the three lots with the same ids and says how many items (AC-3.1)", :aggregate_failures do
      lots = [ own("Card A", location: box, quantity: 2), own("Card B", location: box, quantity: 5), own("Card C", location: box, quantity: 1) ]
      select_lots(*lots)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:notice]).to eq("Moved 8 items to Blue binder.")
      expect(account.lots.order(:id).pluck(:id, :location_id, :quantity)).to eq(lots.map { |lot| [ lot.id, blue.id, lot.quantity ] })
    end

    it "moves to no location (AC-3.2)", :aggregate_failures do
      lots = [ own("Card A", location: blue, quantity: 2), own("Card B", location: box) ]
      select_lots(*lots)
      post collection_move_path, params: { to: "none" }
      expect(flash[:notice]).to eq("Moved 3 items to no location.")
      expect(lots.map { |lot| lot.reload.location_id }).to eq([ nil, nil ])
    end

    it "merges into the destination's lot, which survives (AC-3.3)", :aggregate_failures do
      moved = own(location: box, quantity: 2)
      survivor = twin(moved, location: blue, quantity: 3)
      select_lots(moved)
      post collection_move_path, params: { to: blue.id }
      expect([ survivor.reload.quantity, Lot.exists?(moved.id) ]).to eq([ 5, false ])
    end

    it "keeps the returning page and the filters in the redirect (AC-3.1)" do
      select_lots(own("Bolt A"), page: 1)
      post collection_move_path(page: 2), params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, page: 2))
    end

    it "counts the copies already there (AC-3.6)", :aggregate_failures do
      there = own("Card A", location: blue, quantity: 3)
      coming = own("Card B", location: box, quantity: 2)
      select_lots(there, coming)
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder. 3 items were already there.")
    end

    it "says '1 item was already there' (AC-3.6)", :aggregate_failures do
      select_lots(own("Card A", location: blue), own("Card B", location: box))
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 1 item to Blue binder. 1 item was already there.")
    end

    it "says it for no location too (AC-3.6)" do
      select_lots(own("Card A"), own("Card B", location: box, quantity: 2))
      post collection_move_path, params: { to: "none" }
      expect(flash[:notice]).to eq("Moved 2 items to no location. 1 item was already there.")
    end

    it "leaves a selected lot already there as the target and selected (AC-3.12)", :aggregate_failures do
      a = own(location: box, quantity: 2)
      b = twin(a, location: blue, quantity: 3)
      select_lots(a, b)
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder. 3 items were already there.")
      expect([ b.reload.quantity, Lot.exists?(a.id) ]).to eq([ 5, false ])
      follow_redirect!
      expect([ bar_count, selected_names.size ]).to eq([ "5 of 5 selected", 1 ])
    end

    it "counts only the copies that moved when a selected lot was removed in another tab (Error Scenarios)", :aggregate_failures do
      kept = own("Card A", location: box, quantity: 2)
      gone = own("Card B", location: box, quantity: 3)
      select_lots(kept, gone)
      gone.destroy!
      post collection_move_path, params: { to: blue.id }
      expect(flash[:notice]).to eq("Moved 2 items to Blue binder.")
      expect(kept.reload.location).to eq(blue)
    end

    it "does not touch the session's bulk removal Undo (AC-3.11)", :aggregate_failures do
      removed = own("Opt")
      select_lots(removed, go: "remove")
      post collection_bulk_removals_path
      moved = own("Card A", location: box)
      select_lots(moved)
      post collection_move_path, params: { to: blue.id }
      expect(BulkRemoval.undoable.count).to eq(1)
    end
  end

  describe "the selection after a move (AC-3.9, AC-3.13)" do
    it "keeps the lots now holding the moved copies selected under all locations, a merged survivor and an excepted destination lot too (AC-3.9)", :aggregate_failures do
      a = own("Card A", location: box, quantity: 2)
      excepted = twin(a, location: blue, quantity: 3)
      c = own("Card C", quantity: 1)
      select_everything([ a, excepted, c ], except: [ excepted ])
      post collection_move_path, params: { to: blue.id }
      follow_redirect!
      expect(bar_count).to eq("All 6 items selected")
      expect(page_html.css("tbody tr").size).to eq(2)
      expect(page_html.css("tbody tr[aria-selected=true]").size).to eq(2)
    end

    it "keeps the lots selected under a name filter too (AC-3.9)", :aggregate_failures do
      bolt = own("Bolt A", location: box)
      own("Opt", location: box)
      post collection_selection_path, params: { q: "bolt" }
      patch collection_selection_path, params: { go: "move", q: "bolt", rendered_q: "bolt", rendered_location: "", all_rendered: "0", shown_ids: [ bolt.id ], ticked_ids: [ bolt.id ] }
      post collection_move_path, params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, q: "bolt"))
      follow_redirect!
      expect(bar_count).to eq("1 of 1 selected")
    end

    it "restarts empty under a location filter (AC-3.13)", :aggregate_failures do
      lot = own(location: box)
      select_lots(lot, location: box.id.to_s)
      post collection_move_path, params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, location: box.id))
      follow_redirect!
      expect(bar_count).to eq("0 of 0 selected")
      expect(page_html.css("tbody tr")).to be_empty
    end

    it "restarts empty under no location, listing what is left (AC-3.13)", :aggregate_failures do
      moved = own("Card A")
      own("Card B")           # unplaced and unticked: it stays, so the table still renders under No location
      own("Card C", location: box)
      select_lots(moved, location: "none")
      post collection_move_path, params: { to: blue.id }
      follow_redirect!
      expect(bar_count).to eq("0 of 1 selected")
      expect(page_html.at_css("thead input[type=checkbox]")["checked"]).to be_nil
    end
  end

  describe "everything a filter shows (Story 4)" do
    it "moves exactly the matching lots that are not exceptions, resolved at run time (AC-4.1, AC-4.2)", :aggregate_failures do
      a, kept = own("Card A", location: box), own("Card B", location: box)
      elsewhere = own("Card D", location: blue)
      select_everything([ a, kept ], except: [ kept ], location: box.id.to_s)
      late = own("Card C", location: box) # added to Long box after the selection was made
      post collection_move_path, params: { to: "none" }
      expect([ a, late, kept, elsewhere ].map { |lot| lot.reload.location_id }).to eq([ nil, nil, box.id, blue.id ])
      expect(flash[:notice]).to eq("Moved 2 items to no location.")
      follow_redirect!
      expect([ bar_count, page_html.css("tbody tr").size ]).to eq([ "0 of 1 selected", 1 ])
    end

    it "lands on the nearest real page when the move empties the last one (AC-4.2)", :aggregate_failures do
      stub_const("CollectionTable::PER_PAGE", 1)
      lots = [ own("Card A", location: box), own("Card B", location: box) ]
      select_lots(lots.last, location: box.id.to_s, page: 2)
      post collection_move_path(page: 2), params: { to: blue.id }
      expect(response).to redirect_to(collection_path(bulk: 1, location: box.id, page: 2))
      follow_redirect!
      expect([ response.status, page_html.css("tbody tr").size ]).to eq([ 200, 1 ])
    end

    it "moves only the unplaced lots matching the name under a name filter and No location (AC-4.3)", :aggregate_failures do
      bolt = own("Bolt A")
      placed = own("Bolt B", location: box)
      other = own("Opt")
      post collection_selection_path, params: { q: "bolt", location: "none" }
      patch collection_selection_path, params: { go: "move", q: "bolt", rendered_q: "bolt", location: "none", rendered_location: "none", all_rendered: "0", all: "1",
        header_toggled: "1", shown_ids: [ bolt.id ], baseline_ids: [], ticked_ids: [ bolt.id ] }
      post collection_move_path, params: { to: blue.id }
      expect([ bolt.reload.location, placed.reload.location, other.reload.location ]).to eq([ blue, box, nil ])
    end
  end
```

Code, `Collections::MovesController#create` and its helpers:

```ruby
  def create
    @to = params[:to].to_s
    return refuse(alert: BulkSelection::NONE_LEFT, copies: 0) unless selection?

    @copies = @selection.copies
    return refuse(to_errors: [ Lot::BulkMove::CHOOSE ]) if @to.blank?

    destination = destination_for(@to)
    result = Lot::BulkMove.new(account: Current.account, lots: @selection.lots, to: destination, sort: @selection.sort).apply!
    @selection.after_move!(result.ids)
    redirect_to @bulk_path, status: :see_other, notice: helpers.moved_message(result, destination)
  rescue Lot::CapExceeded => error
    refuse(alert: helpers.over_cap_message("Nothing moved.", error.lot))
  rescue Lot::BulkMove::NothingToMove => error
    refuse(alert: error.message)
  rescue Lot::BulkMove::NoLotsLeft => error # the lots went between the check above and the write lock
    refuse(alert: error.message, copies: 0)
  end
```

```ruby
    # nil for "No location"; any other value must be one of the account's location ids, else 404 (decision 6 (5), AC-2.3).
    def destination_for(value)
      return if value == CollectionFilter::Place::NONE
      raise ActiveRecord::RecordNotFound unless value.match?(CollectionFilter::Place::ID)

      Current.account.locations.find(value)
    end

    # Every refusal re-renders the move page with 422 and keeps the selection and the chosen To.
    def refuse(alert: nil, to_errors: [], copies: @copies)
      @copies, @to_errors = copies, to_errors
      flash.now[:alert] = alert if alert
      render :new, status: :unprocessable_content
    end
```

`CollectionsHelper`:

```ruby
  # The move's notice (spec 041 AC-3.1, AC-3.2, AC-3.6): the copies that moved, and when any were already there, how many.
  def moved_message(result, to)
    message = "Moved #{items_count(result.moved)} to #{to ? to.name : "no location"}."
    return message if result.already_there.zero?

    "#{message} #{items_count(result.already_there)} #{result.already_there == 1 ? "was" : "were"} already there."
  end
```

### Task 11: The refusals and the order of answers

**Implements:** AC-1.7 (POST), AC-2.2, AC-2.3, AC-3.7, AC-3.8, AC-5.1, AC-5.2, AC-5.3, FR-3, decision 6's order, the stale-twice rows of Error Scenarios. **Files:** `spec/requests/bulk_move_spec.rb` (code from Task 10; red only where noted).

Tests:

```ruby
  describe "refusals (decision 6, in its order)" do
    let!(:lot) { own(location: box, quantity: 2) }

    before { select_lots(lot) }

    def selection_kept
      get collection_path(bulk: 1)
      bar_count
    end

    it "(2) answers 'You have no locations yet.' with any destination, selection kept (AC-1.7)", :aggregate_failures do
      lot.update!(location: nil) # a location that holds a lot cannot be removed (restrict foreign key)
      Location.where(account:).delete_all
      post collection_move_path, params: { to: "none" }
      expect(response).to redirect_to(collection_path(bulk: 1))
      expect(flash[:alert]).to eq("You have no locations yet.")
      post collection_move_path, params: { to: "424242" }
      expect(response).to have_http_status(:see_other)
      expect(selection_kept).to eq("2 of 2 selected")
    end

    it "(3) answers 422 with 'None of the selected items…' when the selection selects no lot", :aggregate_failures do
      lot.destroy!
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
      expect(page_html.at_css("h1").text).to eq("Move 0 items")
    end

    it "(3) answers the same when the session never made a selection" do
      BulkSelection.where(account:).destroy_all # the session never made a selection (signing in again is redirected while signed in)
      post collection_move_path, params: { to: "none" }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "(4) asks to choose a destination on the To field when none was chosen (AC-2.2)", :aggregate_failures do
      [ {}, { to: "" }, { to: " " } ].each do |params|
        post collection_move_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(page_html.at_css(".c-field--invalid .c-field__error").text).to eq("Choose where to move them.")
        expect(page_html.at_css("select#to")["aria-describedby"]).to eq(page_html.at_css(".c-field__error")["id"])
      end
      expect([ lot.reload.location, selection_kept ]).to eq([ box, "2 of 2 selected" ])
    end

    it "(4) keeps Back and Cancel on the bulk table with its filters, sort and page when it re-renders (AC-2.4)", :aggregate_failures do
      select_lots(lot, location: box.id.to_s)
      post collection_move_path(page: 2), params: { to: "" }
      bulk = collection_path(bulk: 1, location: box.id, page: 2)
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css('header a[aria-label="Back"]')["href"]).to eq(bulk)
      expect(page_html.at_css(".c-form__actions a")["href"]).to eq(bulk)
    end

    it "(5) answers 404 for another account's location or one removed meanwhile, changing nothing (AC-2.3, AC-5.2)", :aggregate_failures do
      theirs = create(:location, account: create(:user).account)
      gone = create(:location, account:)
      id = gone.id
      gone.destroy!
      [ theirs.id, id, 0, "abc", "017", "9" * 19, [ "none" ], { x: 1 } ].each do |value|
        post collection_move_path, params: { to: value }
        expect(response).to have_http_status(:not_found)
      end
      expect([ lot.reload.location, theirs.lots.count, selection_kept ]).to eq([ box, 0, "2 of 2 selected" ])
    end

    it "(6) refuses when every selected lot is already there (AC-3.7)", :aggregate_failures do
      post collection_move_path, params: { to: box.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("The selected items are already in Long box.")
      expect(page_html.at_css("select#to option[selected]").text).to eq("Long box")
      expect(selection_kept).to eq("2 of 2 selected")
    end

    it "(6) refuses 'already have no location' for unplaced lots (AC-3.7)" do
      unplaced = own("Opt")
      select_lots(unplaced)
      post collection_move_path, params: { to: "none" }
      expect([ response.status, page_html.at_css("#status").text ]).to match([ 422, a_string_including("The selected items already have no location.") ])
    end

    it "(6) refuses a merge past 9,999, naming the first selected lot, changing nothing (AC-3.8)", :aggregate_failures do
      held = twin(lot, location: blue, quantity: 9_999)
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("Nothing moved. Lightning Bolt (#{ApplicationController.helpers.set_number(lot.entry)}) would have more than 9,999 copies in one lot.")
      expect([ lot.reload.location, held.reload.quantity, selection_kept ]).to eq([ box, 9_999, "2 of 10,001 selected" ])
    end

    it "ignores another account's lot ids and an account, user or admin value (AC-5.1, AC-5.3)", :aggregate_failures do
      other = create(:user)
      theirs = create(:lot, account: other.account)
      post collection_selection_path
      patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ lot.id, theirs.id ], ticked_ids: [ lot.id, theirs.id ] }
      post collection_move_path, params: { to: blue.id, account_id: other.account.id, user_id: other.id, admin: "1", location_id: box.id }
      expect([ lot.reload.location, theirs.reload.location, theirs.account_id ]).to eq([ blue, nil, other.account.id ])
      expect(user.reload.admin?).to be(false)
    end
  end

  describe "a stale page submitted twice" do
    it "finds the lots already there under all locations (AC-3.7) and creates or loses no copy", :aggregate_failures do
      lot = own(location: box, quantity: 2)
      select_lots(lot)
      post collection_move_path, params: { to: blue.id }
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("The selected items are already in Blue binder.")
      expect(account.lots.sum(:quantity)).to eq(2)
    end

    it "finds the selection restarted empty under a location filter (decision 6)", :aggregate_failures do
      lot = own(location: box, quantity: 2)
      select_lots(lot, location: box.id.to_s)
      post collection_move_path, params: { to: blue.id }
      post collection_move_path, params: { to: blue.id }
      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("#status").text).to include("None of the selected items are in your collection any more.")
      expect(account.lots.sum(:quantity)).to eq(2)
    end
  end
```

The `{ x: 1 }` and array values in the 404 list reach `params[:to].to_s` as a Hash's or Array's text, which is neither `none` nor an id: 404 is the contract. `BulkSelection::Mark` is the marks model (`has_many :marks, class_name: "BulkSelection::Mark"`); `user.admin?` is the existing predicate on `User` (if the model names it otherwise, use that name).

---

## Phase 3: Guards, no scripting, phone, performance

### Task 12: The core names no collectible

**Implements:** FR-4. **Files:** `spec/import_apply_core_spec.rb`.

Add to the `files` list in the `let(:files)` array (it also fails "exists, every file of it" until the files exist, which they do after Tasks 2, 9, 10):

```ruby
      app/models/lot/bulk_move.rb app/controllers/collections/moves_controller.rb app/views/collections/moves/new.html.erb
```

Run `bin/rspec spec/import_apply_core_spec.rb`. Red only if a file names `mtg` or `scryfall`; none does. Recorded as a guard added, not a failing-first test; the spec's own two examples are the red-green for the list.

### Task 13: Without scripting

**Implements:** AC-6.1. **Files:** `spec/requests/bulk_move_spec.rb`.

How it is tested: the server side of the flow is the whole of the no-script path. The bulk form is a plain `PATCH` form whose controls are `type=submit name=go` buttons joined by `form="bulk"` (BulkForm.md), and the move page is a plain POST form with a `required` select and no Stimulus controller. A request spec that sends exactly the fields a browser without scripting would send, reads the move page's form from the HTML (action, field name, hidden fields) and posts what that form says, is the proof; a system spec would run scripting (all `spec/system` runs Firefox with it on). Test:

```ruby
  it "moves the lots with plain forms: tick, press Move to…, choose, press Move (AC-6.1)", :aggregate_failures do
    lots = [ own("Card A", quantity: 2), own("Card B", quantity: 1) ]
    post collection_selection_path
    get collection_path(bulk: 1)
    bulk = page_html.at_css("form#bulk")
    expect(bulk["method"]).to eq("post")
    expect(page_html.at_css('button[form=bulk][name=go][value=move]')).to be_present
    ids = page_html.css("tbody input[name='shown_ids[]']").map { |input| input["value"] }
    # What a browser without scripting submits: the shown ids, the ticked ones, the pressed button.
    patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", header_toggled: "0", page: 1,
      shown_ids: ids, ticked_ids: ids }
    follow_redirect!
    form = page_html.css("main form").find { |candidate| URI(candidate["action"]).path == collection_move_path } # its action carries ?page=1
    expect(form).to be_present
    expect(form.css("[data-controller]")).to be_empty
    expect(form.at_css("select[name=to][required]")).to be_present
    post form["action"], params: { to: blue.id }
    follow_redirect!
    expect(page_html.at_css("#status").text).to include("Moved 3 items to Blue binder.")
    expect(lots.map { |lot| lot.reload.location }).to eq([ blue, blue ])
  end
```

Green on arrival after Tasks 8 to 10: a characterisation of the path with no scripting, named so.

### Task 14: A browser, and a phone

**Implements:** AC-6.2, AC-6.1 (with scripting too), Accessibility (the status region announces the notice). **Files:** `spec/system/bulk_move_spec.rb` (new).

How it is tested: headless Firefox cannot open a window narrower than 500px, so 360px is a fixed-width iframe (`open_in_narrow_frame`, as `narrow_bulk_pages_spec.rb` does for Set condition); at that width CSS hides `.c-bulkbar__extra` and shows `.c-bulkbar__more`, so the spec reaches "Move to…" through the menu and checks the page fits. The keyboard-only flow is a manual check recorded in `verification.md`, as spec 006 did (spec NFR Accessibility); no system spec scripts Tab.

```ruby
require "rails_helper"

# Spec 041: Move to… in a browser, on a desktop and at 360px.
RSpec.describe "Bulk Move to…", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:account) { user.account }
  let!(:blue) { create(:location, account:, name: "Blue binder") }

  def frame_fits? = page.evaluate_script("(() => { const view = document.getElementById('narrow').contentWindow; return view.document.documentElement.scrollWidth <= view.innerWidth })()")

  it "moves the selected lots from the bar and returns to the bulk table (AC-3.1, AC-3.9)", :aggregate_failures do
    owned_printing("Card A", account:, quantity: 2)
    owned_printing("Card B", account:, quantity: 1)
    visit collection_path
    click_on "Edit many"
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    expect(page).to have_css("h1", exact_text: "Move 3 items")
    select "Blue binder", from: "To"
    click_on "Move"
    expect(page).to have_css("#status", text: "Moved 3 items to Blue binder.")
    expect(page).to have_css(".c-bulkbar__count", exact_text: "All 3 items selected")
    expect(account.lots.pluck(:location_id).uniq).to eq([ blue.id ])
  end

  it "does not move when the To prompt is left (AC-2.2: the browser refuses it first)", :aggregate_failures do
    lot = owned_printing(account:)
    visit collection_path(bulk: 1)
    check "Select all"
    within(".c-bulkbar__extra") { click_on "Move to…" }
    click_on "Move"
    expect(page.evaluate_script("document.getElementById('to').validity.valueMissing")).to be(true) # the browser's required check stopped it
    expect(page).to have_css("h1", text: "Move 1 item")  # still the move page
    expect(page).to have_no_css(".c-field--invalid")      # the server's refusal never rendered: the browser stopped it
    expect(page).to have_no_css("#status", text: /\S/)
    expect(lot.reload.location).to be_nil
  end

  it "reaches Move to… from the bar's menu at 360px and fits the move page (AC-6.2)", :aggregate_failures do
    owned_printing(account:, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid_cents: 123_456)
    visit collection_path
    open_in_narrow_frame(collection_path(bulk: 1), width: 360, ready: ".c-bulkbar")
    within_narrow_frame do
      expect(page).to have_no_css(".c-bulkbar__extra", visible: :visible)
      check "Select all"
      find(".c-bulkbar__more summary").click
      expect(page.all(".c-bulkbar__more .c-menu__item").map(&:text)).to eq([ "Set condition…", "Move to…", "Remove" ])
      click_on "Move to…"
      expect(page).to have_css("h1", text: "Move 9,999 items").and have_css(".c-appbar__back")
      expect(page).to have_select("To", options: [ "Choose…", "No location", "Blue binder" ])
    end
    expect(frame_fits?).to be(true)
  end
end
```

(In a system spec the `within_narrow_frame` block navigates the iframe; `frame_fits?` runs against the page that holds the frame. The first example's `check "Select all"` works only in bulk mode with scripting, as `bulk_mode_spec.rb` does it.)

Run `bin/rspec spec/system/bulk_move_spec.rb` (needs headless Firefox).

### Task 15: The 5,000-lot, 300-location bar

**Implements:** AC-4.4, NFR Performance. **Files:** `spec/requests/bulk_move_timing_spec.rb` (new).

The bar is a `:timing` example (measured, never gating; run with `SCANNER_TIMING=1 bin/rspec --tag timing spec/requests/bulk_move_timing_spec.rb`), written like spec 037's. The fixture is the spec's: 5,000 lots over 300 locations, many merging into lots already in the destination, in the same table as two other accounts' lots. The shape (the account holds 5,396 lots with the extras): 1,000 printings; lot `i` is printing `i % 1000` in location `i % 300`, with price paid `i / 3000` (0 or 1) so the pairs are unique; every printing therefore has lots of one price in several places, which merge when moved to one place (about 2,000 merge groups: 1,000 of three lots at price 0 and 1,000 of two lots at price 1); 396 extra lots (printings 1 to 400 that are not multiples of 100) already in the destination add merges into existing lots.

```ruby
require "rails_helper"

# Spec 041 AC-4.4, NFR Performance: moving every matching lot of 5,000 lots, over 300 locations, many merging into lots
# already in the destination, in under 2 seconds of server time. Measured, never gating (run with SCANNER_TIMING=1); the
# result goes in verification.md.
RSpec.describe "Bulk move timing", :timing, type: :request do
  let(:user) { create(:user) }

  def seed(account, entries, count: 5_000, places: 300)
    locations = Array.new(places) { |i| account.locations.create!(name: "Place #{i}") }
    now = Time.current
    rows = Array.new(count) do |i|
      location = locations[i % places]
      price = i / 3_000
      { account_id: account.id, catalog_entry_id: entries[i % entries.size], quantity: 1 + (i % 4), finish: "nonfoil", price_paid_cents: price,
        location_id: location.id, lot_key: Lot.key_for("nonfoil", nil, price, location.id), created_at: now, updated_at: now }
    end
    rows.each_slice(1_000) { Lot.insert_all(it) }
    locations
  end

  it "moves 5,000 lots to one location in under 2 s" do
    entries = Array.new(1_000) { |i| create(:mtg_printing, entry: create(:catalog_entry, name: "Card #{i}")).entry.id }
    2.times { seed(create(:user).account, entries) }
    locations = seed(user.account, entries)
    destination = locations.first
    now = Time.current
    extra = (1..400).reject { |i| (i % 100).zero? }.map do |i| # printings the destination doesn't hold: later moves merge into these
      { account_id: user.account.id, catalog_entry_id: entries[i], quantity: 1, finish: "nonfoil", price_paid_cents: 0, location_id: destination.id,
        lot_key: Lot.key_for("nonfoil", nil, 0, destination.id), created_at: now, updated_at: now }
    end
    Lot.insert_all(extra)
    sign_in_as(user)

    post collection_selection_path
    patch collection_selection_path, params: { go: "move", rendered_q: "", rendered_location: "", all_rendered: "0", all: "1", header_toggled: "1", shown_ids: [], ticked_ids: [] }
    before = [ user.account.lots.count, user.account.lots.sum(:quantity) ]
    statements = 0
    counter = ->(*, payload) { statements += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { post collection_move_path, params: { to: destination.id } }
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

    after = [ user.account.lots.count, user.account.lots.sum(:quantity) ]
    RSpec.configuration.reporter.message format("move %d lots -> %d lots, %d copies kept, %d ms, %d statements", before.first, after.first, after.last, elapsed, statements)
    expect(response).to have_http_status(:see_other)
    expect(after.last).to eq(before.last) # no copy lost
    expect(user.account.lots.where.not(location_id: destination.id)).to be_empty
    expect(elapsed).to be < 2_000
  end
end
```

(Seed note: `i % 1000` and `i % 300` with price `i / 3000` are unique within 5,000 lots: `lcm(1000, 300) = 3000`, and `i / 3000` separates the two passes. `shown_ids: []` with `all: 1` selects every matching lot with no exceptions; if the controller's `ids` helper wants the keys, pass `shown_ids: []` as written. The 400 extra lots collide with no seeded lot: the seeded lots in `locations.first` are `i % 300 == 0`, printings `i % 1000`, all multiples of 100, which `reject { (i % 100).zero? }` skips.)

Expected on a developer laptop: well under 2 s (about 2,000 single-row survivor `UPDATE`s, one per merge group since every group merges, plus about 4 `DELETE` batches for the folded lots). If it is over, the contingency is in Risks. The numbers are recorded in `verification.md` (Task 19).

---

## Phase 4: Documents

Each is edited with the source inline (spec 041 AC or decision), per `.claude/rules/documentation.md`. No RSpec checks any of them (`.claude/rules/testing.md`); each is verified by reading, recorded in `verification.md`.

### Task 16: The design system's documents

**Implements:** "Documents that change", rows `BulkForm.md` and `Form.md`. **Files:** `docs/design-system/components/BulkForm.md`, `docs/design-system/components/Form.md`.

`BulkForm.md`: in the markup block, the `c-bulkbar__extra` buttons become Set condition…, a `go=move` "Move to…" (`c-btn c-btn--secondary c-btn--sm`), Remove; add a bullet after "Every control that leaves the page…":

```markdown
- The bulk bar's actions are "Set condition…", "Move to…" and "Remove", in that order, in the bar and in the "More bulk actions" menu. "Move to…" is offered only while the account has a location (spec 041 AC-1.1, AC-1.2). Each opens its own page (a `Form` page, or a confirmation) and returns to the bulk table.
```

`Form.md`: after the line about selects:

```markdown
- A required select whose first option is a prompt says "Choose…" and submits `""`, so the browser's required check refuses it; "Not specified" is for an optional field's blank (spec 041 decision 6, AC-2.1, AC-2.2).
```

Run `bin/rspec spec/requests/design_system_spec.rb` only if a stylesheet changed (none does).

### Task 17: The area doc

**Implements:** "Documents that change", row `collection-and-lots.md`; the supersessions of spec 006 FR-5, AC-4.4 and spec 032 decisions 3 to 5. **Files:** `docs/architecture/collection-and-lots.md`.

Edits, each with its source:

1. **Scope**, the bulk mode line: `Bulk mode: the selection, Set condition, Move to…, the bulk removal and its Undo (`BulkSelection`, `Collections::SelectionsController`, `Lot::ConditionChange`, `Lot::BulkMove`, `Collections::MovesController`, `BulkRemoval`) (spec 006 Stories 4–8; spec 032 Story 7; spec 041)`.
2. **Glossary**: add `**Destination:** the place a bulk move sends lots to, one of the account's locations or none. **Already there:** a selected lot whose place is the destination (spec 041 Terms).`
3. **Invariants**, "Four places build a key" becomes "Five places build a key and all carry the place: `Lot.key_for`, the SQL in `Lot::ConditionChange#update_alone!`, the SQL in `Lot::BulkMove#move_alone!`, `BulkRemoval#identity` with its `insert_all`, and the apply's attribute builder for `upsert_lots!`" with "(spec 041 FR-2; `spec/models/lot/bulk_move_spec.rb` proves the move's)".
4. **Invariants**, the merge list: `…`Lot::Move`, `Lot::ConditionChange`, `Lot::BulkMove` and `BulkRemoval#undo!`` (spec 041 decision 4).
5. **Invariants**, "Only some ways of adding choose a place": add "bulk Move to… chooses one place for every selected lot", and change the clause "quick add and the bulk actions add or keep copies unplaced (or keep each lot's place)" to "quick add adds copies unplaced, and the other bulk actions keep each lot's place" (spec 041).
6. **Invariants**, "Everything is scoped to `Current.account`": add "a foreign location id for a bulk move is 404, foreign lot ids are ignored (spec 041 AC-5.1, AC-5.2)".
7. **Bulk mode**: after "Set condition", a paragraph:

```markdown
**Move to…** (its own page, shown only while the account has a location; `/collection/move/new`, `POST /collection/move`): "Move <n> items" with a required To select ("Choose…" submitting `""`, "No location" submitting `none`, then the locations in the locations page's order; the selection's own place is left out). Every copy of each selected lot moves (`Lot::BulkMove`): a lot that meets no lot of its identity in the destination stays the same lot, one that does merges into the destination's lot, selected lots of one identity become one (the first in the table's order survives), a selected lot already there stays and counts as "already there"; all or nothing at the cap. 303 to the bulk table with "Moved <n> items to <name>." ("…to no location."), plus "<m> items were already there." when any were. Under all locations the lots now holding the moved copies are selected; under a location or "No location" the selection restarts empty (`BulkSelection#after_move!`). No Undo; it doesn't supersede the removal's. Refusals (422, move page, selection kept): "Choose where to move them." on To, "The selected items are already in <name>." / "…already have no location.", "Nothing moved. <name> (<SET> · <number>) would have more than 9,999 copies in one lot."; 404 for a location that isn't the account's; 303 "You have no locations yet." with no location. The order of answers: a GET with no selection, no location, no lot selected, no destination, a foreign destination, the move (spec 041 decisions 1–6, Stories 1–4, FR-1–FR-3).
```

8. **Locations section**: replace "Until "Move to…" (#48), a location is emptied one lot at a time with Move copies (spec 032 decision 3)." with "A location is emptied by filtering the collection to it, `Edit many`, selecting every matching lot and choosing "Move to…"; a shortcut from the refusal page is [#187](https://github.com/plainprogrammer/Collector/issues/187) (spec 041 decision 5)."
9. **Moving copies** section's intro: "It moves one lot; many lots at once is Move to… in bulk mode (spec 041)".
10. **Named constants**: rows for `Lot::BulkMove::CHOOSE` ("Choose where to move them."), `Lot::BulkMove::NO_LOCATIONS` ("You have no locations yet."), `Lot::BulkMove::BATCH` (1,000; ids per statement), `Lot::BulkMove::NothingToMove` text; the measured-bars paragraph: add "and Move to… on every matching lot of 5,000 lots over 300 locations under 2 seconds (spec 041 AC-4.4; the `:timing` example `spec/requests/bulk_move_timing_spec.rb`)".
11. **Decisions not in an ADR**: replace "Move copies works on one lot, from the card page; many lots at once is #48" with "Move copies works on one lot, from the card page; Move to… in bulk mode moves whole lots, with no Undo, and leaves a selected lot already there alone (maintainer, 2026-11-06; spec 041 decisions 1–3)".
12. **Accepted limits**: the #48 line becomes "No sort by location (spec 037 Non-Goals); a move's merged lots stay merged when moved back (spec 041 decision 1); no partial lots in bulk (decision 2); [#187](https://github.com/plainprogrammer/Collector/issues/187): no shortcut from a location's refusal page into bulk mode."
13. **Decisions not in an ADR**: add "Bulk Move to… writes with `update_all` and `delete_all` on the account's lots, against the models rule, for the 2-second bar: every statement is tenant-scoped and bound, the cap and identity collisions are checked first, `Lot` has no callbacks, and the foreign keys cascade or nullify what points at a lot (`Lot::ConditionChange#update_alone!` is the precedent; spec 041 FR-2, D1 of its plan)".
14. **Sources**: add `spec 041`, and move issue #48 from the "open:" list of the issues line to the closed ones (#187 takes its place there as open); **Distillation log** is left to `distill-feature` (rule: documentation.md, session end), not written by hand here.

### Task 18: `CLAUDE.md` and the roadmap

**Implements:** "Documents that change", rows `CLAUDE.md` and `docs/roadmap.md`. **Files:** `CLAUDE.md`, `docs/roadmap.md`.

`CLAUDE.md` status paragraph: after "or moves some or all of a lot's copies with Move copies (`Lot::Move`, spec 032; …)": append "and moves every copy of many lots at once from bulk mode with Move to… (`Lot::BulkMove`, spec 041)". The "Collection and lots" bullet: "four places build a `lot_key`" becomes "five places build a `lot_key`"; the specs list gains `041`. Nothing else in CLAUDE.md restates the move's rules (documentation.md: point to the area doc).

`docs/roadmap.md` item 13 (line 35): `13. [#48](…) Move many lots at once (the "Move to…" deferred in spec 006). **Built <date>, done when its pull request merges:** [spec 041](specs/041-move-many-lots/spec.md): "Move to…" in bulk mode, for the selected lots or every matching lot, to a location or none (PR <number>).` The date and number are filled when the pull request exists; if it doesn't yet, the sentence reads "Planned: spec 041 (approved 2026-11-06)" and the distillation step finishes it.

### Task 19: `verification.md` skeleton

**Implements:** the Hard Gate "no completion claim without fresh evidence"; spec "performance recorded in `verification.md`", "keyboard recorded in `verification.md`". **Files:** `docs/specs/041-move-many-lots/verification.md` (new).

```markdown
# Verification: Spec 041, Move Many Lots at Once

**Spec:** [spec.md](spec.md) 0.4.0 · **Plan:** [plan.md](plan.md) · **Pull request:** (number when opened; closes [#48](https://github.com/plainprogrammer/Collector/issues/48))

## Evidence per criterion

Spec files: `spec/models/lot/bulk_move_spec.rb` (the move), `spec/models/bulk_selection_spec.rb` ("#after_move!"), `spec/requests/bulk_move_spec.rb`, `spec/routing/routes_spec.rb`, `spec/import_apply_core_spec.rb`, `spec/system/bulk_move_spec.rb`, `spec/requests/bulk_move_timing_spec.rb`.

| Criterion | Evidence |
|---|---|
| (one row per AC and FR of the spec, filled from the plan's traceability table with the example names as written) | |

## Measured

| What | Command | Result |
|---|---|---|
| AC-4.4, Performance: 5,000 lots, 300 locations, every matching lot to one place | `SCANNER_TIMING=1 bin/rspec --tag timing spec/requests/bulk_move_timing_spec.rb` | (the printed line: lots before and after, copies kept, ms, statements; machine) |
| Move page queries, 1 and 30 selected lots, 1 and 30 locations | `bin/rspec spec/requests/bulk_move_spec.rb -e "same queries"` | (equal counts) |

## Manual checks

| Check | Result |
|---|---|
| Accessibility NFR: the whole flow with the keyboard alone (Edit many, tick or Select all, Tab to "Move to…", Enter, choose in To, Move; also Cancel; the status region announces the notice and each refusal; the To error is read with its field; focus is visible throughout) | (date, browser) |
| Phone width: the bar's menu reaches "Move to…"; the move page fits (the system example proves 360px; this is a look at a real phone or 390px window) | |
| Documents read: area doc, `BulkForm.md`, `Form.md`, `CLAUDE.md`, `docs/roadmap.md` agree with the code | |

## Implementation review

(Written by `sdd-review` Mode B; first line the verdict, e.g. "SPEC-ALIGNED". `distill-feature` reads this heading.)
```

### Task 20: The whole of it, fresh

**Implements:** the completion gate. Run, in this order, each fresh: `bin/rspec spec/models/lot/bulk_move_spec.rb spec/models/bulk_selection_spec.rb spec/routing spec/requests/bulk_move_spec.rb spec/requests/bulk_mode_spec.rb spec/requests/bulk_condition_spec.rb spec/requests/bulk_removal_spec.rb spec/requests/collection_location_filter_spec.rb spec/import_apply_core_spec.rb`; `bin/rspec spec/system/bulk_move_spec.rb spec/system/bulk_mode_spec.rb spec/system/narrow_bulk_pages_spec.rb`; the timing example (Task 15); `bin/ci` (RuboCop, Brakeman, upgrade guard, the whole suite; the commit and push hooks run these too). Every failure is fixed at its cause, never by editing an existing example of specs 006, 032 or 037 except where the bar gains a button (those examples' button lists are the one place an existing spec may need a line: `spec/requests/bulk_mode_spec.rb` and the system bulk examples that count `.c-bulkbar` buttons; any such edit is named in the commit body as spec 041's supersession of 006 AC-4.4).

---

## Traceability

| Criterion | Task | Spec file(s) |
|---|---|---|
| AC-1.1 bar and menu order | 8 | `spec/requests/bulk_move_spec.rb` "offers Move to… after Set condition…"; `spec/system/bulk_move_spec.rb` (menu order at 360px) |
| AC-1.2 no location: not offered, navigation | 8 | `bulk_move_spec.rb` "when the account has no location" |
| AC-1.3 ticks recorded, page opens (303) | 8 | `bulk_move_spec.rb` "records the ticks and opens the move page" |
| AC-1.4 nothing selected, 422 | 8 | `bulk_move_spec.rb` "refuses with the bulk table when nothing is selected" |
| AC-1.5 all gone, 422 | 8 | `bulk_move_spec.rb` "refuses when the ticked lot was removed in another tab", "refuses when every ticked lot is another account's…" |
| AC-1.6 GET with no selection, 303 | 9 | `bulk_move_spec.rb` "sends the collector back to the bulk table when nothing is selected" |
| AC-1.7 last location removed | 9 (GET), 11 (POST) | `bulk_move_spec.rb` "answers 'You have no locations yet.'…" and refusal "(2)" |
| AC-2.1 heading, To options, prompt, buttons, own place left out | 9 | `bulk_move_spec.rb` "says how many items…", "leaves out the selection's own place" |
| AC-2.2 no destination, 422 on To | 11 (server), 14 (browser) | `bulk_move_spec.rb` refusal "(4)"; `system/bulk_move_spec.rb` "does not move when the To prompt is left" |
| AC-2.3 foreign or removed location, 404 | 11 | `bulk_move_spec.rb` refusal "(5)" |
| AC-2.4 Back and Cancel keep page, filters, sort | 9, 11 | `bulk_move_spec.rb` "says how many items…" (the page), refusal "(4) keeps Back and Cancel…" (re-render under a filter and page) |
| AC-3.1 same lots, same ids, notice | 2, 10 | `bulk_move_spec.rb` (model) "moves every copy…"; request "moves the three lots…" |
| AC-3.2 to no location | 2, 10 | model "moves to no location"; request "moves to no location" |
| AC-3.3 merge into the destination's lot | 4, 10 | model "merges a moved lot into…"; request "merges into the destination's lot" |
| AC-3.4 selected lots of one identity merge, the first survives | 4 | model "makes selected lots of one identity one lot…" (also the survivor's added time), "lets the sort choose the survivor" |
| AC-3.5 merge with the destination's lot too | 4 | model "folds two moved lots into the destination's lot" |
| AC-3.6 already there, counted | 3, 10 | model "leaves lots already there alone…"; request notice examples (3 variants) |
| AC-3.12 selected lot already there is the target | 4, 10 | model "treats a selected lot already there as the target"; request "leaves a selected lot already there…" |
| AC-3.7 every lot already there, 422 | 3, 11 | model "refuses when every selected lot is already there"; request refusals "(6)" |
| AC-3.8 cap, names the first selected lot | 5, 11 | model "the 9,999 cap" (4 examples); request "refuses a merge past 9,999…" |
| AC-3.9 selection under all locations | 7, 10 | `bulk_selection_spec.rb` "#after_move!" (2); request "keeps the lots now holding the moved copies selected…" |
| AC-3.13 restart under a location filter | 7, 10 | `bulk_selection_spec.rb` "#after_move!" (2); request "restarts empty under a location filter", "…under no location" |
| AC-3.10 only one identity merges | 2 | model "keeps lots that differ only in finish, condition or price paid separate" |
| AC-3.11 removal Undo unaffected | 10 | request "does not touch the session's bulk removal Undo" |
| AC-4.1 every matching lot, exceptions, at run time | 10 | request "moves exactly the matching lots that are not exceptions…" |
| AC-4.2 filter shows what is left, nearest page | 10 | request "lands on the nearest real page…", the Story 4 example's "0 of 1 selected" |
| AC-4.3 name filter and No location | 10 | request "moves only the unplaced lots matching the name…" |
| AC-4.4 5,000 lots in under 2 s | 6, 15 | `bulk_move_spec.rb` (model, statements); `spec/requests/bulk_move_timing_spec.rb` |
| AC-5.1 foreign lot ids ignored | 5, 11 | model "touches only the account's lots"; request "ignores another account's lot ids…" |
| AC-5.2 foreign location 404 | 11 | request refusal "(5)" |
| AC-5.3 no account, user or admin value used | 11 | request "ignores another account's lot ids and an account, user or admin value" |
| AC-5.4 prefetch changes nothing | 9 | request "asks nothing of the selection or the lots when the request is a prefetch" |
| AC-6.1 without scripting | 13 | request "moves the lots with plain forms…" (the form's own fields and no Stimulus) |
| AC-6.2 phone: reachable, fits | 14 | `system/bulk_move_spec.rb` "reaches Move to… from the bar's menu at 360px…" |
| FR-1 the action (offered, ticks first, resolved at run time, no change on GET/prefetch) | 8, 9, 10 | as AC-1.1 to AC-1.6, AC-4.1, AC-5.4 |
| FR-2 the move (same lot; merge; cap; key rule; one transaction; not another account) | 2 to 5 | `spec/models/lot/bulk_move_spec.rb` incl. the key parity example (Task 2), the foreign-key rollback and tenant examples (Task 5) |
| FR-3 the answers (303 notice and selection; 422; 404; 303 alert; refusals keep the selection) | 10, 11 | `bulk_move_spec.rb` "moving", "refusals", "a stale page submitted twice" |
| FR-4 the core names no collectible | 12 | `spec/import_apply_core_spec.rb` |
| NFR Performance (statements; move page queries; the 2 s bar) | 6, 9, 15 | model "runs as many statements…"; request "runs the same queries for 1 and 30…"; the timing example |
| NFR Accessibility | 9, 14, 19 | markup (label, `required`, `aria-describedby`) in `bulk_move_spec.rb`; the keyboard flow is the manual check in `verification.md` |
| NFR Security (account scoping, no account/user/admin values) | 5, 11 | as AC-5.1 to AC-5.3 |
| NFR Reliability (all or nothing, one transaction) | 5, 11 | model cap and foreign-key examples; request "a stale page submitted twice" |
| Error Scenarios (all nine rows) | 8, 9, 10, 11 | the rows' own examples: nothing selected (8), all gone (8, 9), no destination (11), foreign or removed destination (11), every lot there (11), over the cap (11), no location (9, 11), stale twice (11); some selected lots gone: Task 10 "counts only the copies that moved when a selected lot was removed in another tab"; the selection selects no lot at the write lock: Task 5 "raises NoLotsLeft"; number-entry lines (decision 6): Task 4 "reads a number-entry line as changed…" |
| Decision 7 (no export change) | none | no file of `docs/export-format/` or the Coverage tables changes; `bin/ci` proves the guard stays green |
| Documents that change | 16, 17, 18, 19 | read, recorded in `verification.md` |

## Risks, and what only a run can confirm

1. **The 2-second bar.** Written for one statement per surviving merge group plus batched deletes. If the timing example is over 2 s, the contingency (inside the NFR's "statements independent of the number of selected lots" as a stricter reading, not a spec change) is to write the survivors in one statement per batch: `UPDATE lots SET quantity = CASE id WHEN … END, lot_key = CASE id … END, location_id = ?, updated_at = ? WHERE id IN (…)`, built from bound pairs. That stays a single key rule, `Lot.key_for`'s text computed in Ruby. Only a run measures it.
2. **`joins(entry: :set)` on top of `CollectionFilter.lots`' `joins(:entry)`.** ActiveRecord merges the two into one join tree, which is what `check_cap!` in `Lot::ConditionChange` relies on with a plain `account.lots.joins(entry: :set)`; combined with the name filter's `Catalog::Entry.named_like` merge it is untested. Task 4's examples run it with a name filter only in the request spec (AC-3.9 name filter); a duplicate-alias error would show there.
3. **`Sort.apply`'s condition rank** takes the vocabulary from the entry's collectible type in SQL; sorting by condition on a selection is not covered by an example here. A one-line example in Task 4 (`sort: CollectionTable::Sort.parse("condition", "asc")`) is worth adding if the executor finds the rank needs the preloaded extension.
4. **`delete_all` and `update_all`** are used, with comments, as `Lot::ConditionChange` uses `update_all`: `Lot` has no callbacks or dependents, the foreign keys null or cascade what points at a lot, and every statement is `@account.lots.where(id:)`. If the executor adds a callback or a `dependent:` to `Lot` later, these writers skip it.
5. **SQLite bound-variable limit.** Statements bind at most 1,000 ids (`BATCH`); `existing_targets` binds the distinct printing ids in one `IN`, as `Lot::ConditionChange` does. At the largest account (tens of thousands of printings in one move) that list could pass SQLite's 32,766 limit; the 5,000-lot bar does not reach it. If it does for a real account, batch that read by `BATCH` too (a one-line change, same result).
6. **Order of `before_action`s.** `include BulkSelected` registers `set_selection` before the controller's own `require_locations`; Rails runs callbacks in declaration order, and the examples "(1) GET with no selection and no location answers 'Select at least one item.'" are worth one line in Task 9's GET describe if the executor wants decision 6 (1) before (2) pinned.
7. **`--tag timing` and the exclusion.** `rails_helper` excludes `:timing` unless `SCANNER_TIMING` is set; whether `--tag timing` alone overrides the exclusion was not run. The plan's command sets both.
8. **Pre-existing examples that count bulk-bar buttons.** `spec/requests/bulk_mode_spec.rb` and the system bulk examples may assert the bar's button list; they change with spec 006 AC-4.4's supersession (Task 20 names it). Found only by running them.
9. **`flash` and the location name.** The notice contains a location's name (up to 60 characters) in the session-cookie flash; with "1 item was already there." it stays well under the 4 KB cookie limit.
10. **The keyboard and screen-reader checks** (Accessibility NFR) are manual, as in spec 006; the status region and `aria-describedby` markup are asserted, the experience is not.
