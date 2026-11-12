# Implementation Plan: Replace a Proxy with a Copy

**Spec:** [spec.md](spec.md) (v0.4.0, Approved at Gate A, 2026-11-11, by the coordinator under the maintainer's delegation); plan approved at Gate B (the coordinator, under the maintainer's delegation, 2026-11-11; revision 3, with the Lot::MoveIntoZone contract additions)
**Decisions:** none new; ADR 0028's deck model and spec 068's proxy table are used as they are (spec decision 14)
**Created:** 2026-11-11
**Revision:** 2 (from plan review round 1: 1 blocking, 8 major, 13 minor)

## Global Constraints

- **No new data.** No migration, no table, no column, no change to the export, the import, the backup or the upgrade seed (decision 12). A replacement writes lots and one proxy row, both of which format version 4 already carries.
- **A proxy is never a lot, and only these two pages lower one by moving or adding copies** (decision 6; spec 068 AC-4.2 still holds for every other path). Nothing in this plan touches `Lot.add!`, `Lot::Move`, `Lot::BulkMove`, the scanner or number entry.
- **Free** means a lot whose location is none or a place (kind `place`); a lot in any zone of any deck, Considering included, is not free (decision 2). It has one definition, `Lot.free`, and the move of chosen copies into a zone has one home, `Lot::MoveIntoZone` (decision 8, the coordinator's ruling at Gate A). Spec 071 cherry-picks the commits of T1 and T2, so **after their SHAs are sent to the coordinator those files are not changed without telling the coordinator**.
- **Every read and write goes through the signed-in account.** The deck by `FindsDeck#set_deck` (location id through `Current.account`, `Location::ID_TEXT` guard), the proxy by `set_proxy(:proxy_id)` among the deck's own, the lots by `account.lots.free` of the proxy's card. Another account's deck or proxy, a place's or zone's id as the deck and an id that isn't digits only are 404; a lot id in the form that isn't one of the account's free lots of the card counts as "no longer free" (422), never as a distinct answer (decision 9). No parameter names an account, a zone, a location, a kind or an entry (AC-3.13, AC-4.7).
- **The vocabulary gate reads the proxy's printing's collectible type** (`Deck::Proxy.replaceable?(entry)`), never the deck's (decision 1; AC-1.4, AC-2.9, AC-4.8).
- **One transaction, judged under the lock.** The proxy and the chosen lots are read again inside the write transaction; a refusal leaves it by an exception nothing rescues inside, and the page that shows the refusal is built from a read made after the rollback, with every `shown` field written again (decisions 6, 7, 9, 10).
- **The core guard.** Deck files never name a game, a source, a format or a zone key but `considering`, comments included, and `mtg`, `scryfall` and `magic` are banned anywhere in them (`spec/deck_core_spec.rb`); the new controllers, the new `Deck::Proxy::*` classes, the new views and `lots/_form.html.erb` are matched by its globs already, so the file count changes (T13). `app/models/lot/*.rb` is outside the guard but names no collectible either.
- **Design system:** tokens and `c-*` classes only. Both pages' `main` is `c-main c-page c-decks` (the touch floor of `.c-decks .c-btn`, the wrap of `.c-decks .c-pagehead__title`, spec 068's select floor). The `c-pick` rules of spec 060 exist; the one new rule is the wrap of Add a new copy's read-only Location line (`.c-decks .c-field__value`, T9 Step 3a, under its own heading); T12 measures every width and adds no other CSS for a control that already meets its rule.
- **The existing examples this change breaks** are found by a grep, not memory (spec "Supersedes and updates"): T6 lists them with their lines.
- **Tests:** tag spec types explicitly; `:aggregate_failures` on multi-expectation examples; an "absent" assertion uses a fixture that could produce the present case (the lesson of spec 066); a request example that asserts a name is absent builds it at run time (the 404 page prints the spec's source); no prose documents checked from RSpec; the "works without scripting" examples run under `rack_test` with `driven_by` declared before the sign-in and the driver asserted.
- **Code documentation** (`.claude/rules/code-documentation.md`): every public class, module and method added or changed gets a summary comment (the why, side effects, whether it needs `Current.account`, transactions); no collectible named in a core file's comments.
- **One shared test database:** never run two spec runs at once. Targeted `bin/rspec <file>` runs need no CI slot; a full `bin/ci`, or a push whose hook runs it, asks the coordinator first.
- **Commits:** Conventional, one per task, each ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `git add` and `git commit` in separate calls.

---

## Goal

A collector opens a proxy row's menu and uses a free copy they own ("Use my copy": lots listed with a number field each, the proxy's own printing first) or adds a new one ("Add a new copy": the Add a copy form with the printing, finish and zone filled in); the copies enter the zone and the proxy shrinks, or goes at zero, in one write that does all of it or none, and neither a double submit nor a copy that changed meanwhile can move anything twice or silently less.

---

## Pre-implementation gates

- **Simplicity (≤3 components).** Three: the two shared parts (`Lot.free`, `Lot::MoveIntoZone`), the two proxy actions (`Deck::Proxy::UseCopies`, `Deck::Proxy::AddCopy`, `Deck::Proxy#lower_by!`) and their pages (two controllers, two views, the menu, the form partial's options). No gem, JavaScript, migration or job.
- **Anti-abstraction.** `Lot::Move` is used as it is (decision 7), not wrapped twice: `MoveIntoZone` exists because #255 needs the same all-or-nothing move of chosen copies, and it adds the free test under the lock and the judging that `Lot::Move` leaves out. `Lot::Form` and `lots/_form.html.erb` are reused for Add a new copy; the partial gains four optional locals, no copy. `UseCopies` and `AddCopy` are the two pages' form objects, the pattern `Deck::Proxy::Addition` set.
- **Integration-first.** The shared parts and their model specs come first (T1, T2); each form object's spec comes before the controller that uses it; every task starts with its failing example.
- **Statement counts fixed here.** Use my copy's page (GET) runs a fixed number of statements however many lots, printings and places there are: the deck, its location, the proxy with its zone, entry and set, the free lots with their entries and sets (one statement each with the preloads), the places, one extension read for the finishes. T7 measures it for 1 lot and for 12 lots and asserts equality (AC-2.7). The deck page's count is unchanged (AC-1.5): the menu reads `row.entry` and the lines already loaded, and `Catalog.collecting` (a hash), no query.

## File map

| File | Change | Responsibility |
|------|--------|----------------|
| `app/models/lot.rb`, `spec/models/lot/free_spec.rb` | edit, new | `Lot.free` (T1) |
| `app/models/lot/move_into_zone.rb`, `spec/models/lot/move_into_zone_spec.rb` | new | The all-or-nothing move of chosen `[lot, count]` pairs into a zone (T2) |
| `app/models/deck/proxy.rb`, `spec/models/deck/proxy_spec.rb` | edit | `Deck::Proxy.replaceable?`, `#lower_by!`; the header comment's list of writers (T3) |
| `app/models/deck/proxy/use_copies.rb`, `spec/models/deck/proxy/use_copies_spec.rb` | new | Use my copy's form object (T4) |
| `app/models/deck/proxy/add_copy.rb`, `spec/models/deck/proxy/add_copy_spec.rb` | new | Add a new copy's form object (T5) |
| `app/models/deck/page.rb` | edit | `Row#replaceable?` (T6) |
| `config/routes.rb` | edit | `replacement` and `copy` under a proxy (T6) |
| `app/helpers/decks_helper.rb`, `app/views/decks/_proxy_menu.html.erb`, `spec/requests/deck_pages_spec.rb` | edit | The menu's two new items and their labels; the examples that read the menu (T6) |
| `app/controllers/decks/proxies/replacements_controller.rb`, `app/views/decks/proxies/replacements/new.html.erb`, `spec/requests/deck_proxy_replacements_spec.rb` | new | Use my copy's pages (T7, T8) |
| `app/views/lots/_form.html.erb` | edit | Fixed place, Quantity maximum, Cancel path, shown count (T9) |
| `app/controllers/decks/proxies/copies_controller.rb`, `app/views/decks/proxies/copies/new.html.erb`, `spec/requests/deck_proxy_copies_spec.rb`, `app/assets/stylesheets/collector/additions.css` | new, edit | Add a new copy's pages and the wrap rule of its read-only Location (T9) |
| `spec/requests/deck_proxy_replacement_tenancy_spec.rb` | new | A 404 per page and verb, another account's lot (T10) |
| `spec/models/deck_proxy_replacement_round_trip_spec.rb`, `spec/models/lot_proxy_isolation_spec.rb` | new, edit | The export and restore after a replacement; `Lot::MoveIntoZone` is no path that changes a proxy (T11) |
| `spec/system/deck_proxy_replacements_spec.rb` | new | Both flows in Firefox and under `rack_test`; widths, themes and the touch-floor rules (T12) |
| `spec/deck_core_spec.rb`, `spec/import_apply_core_spec.rb` | edit | The file count; the guard of `Lot::MoveIntoZone` (T13) |
| `app/models/deck/proxy.rb` (header), `spec/models/lot_proxy_isolation_spec.rb` (header), `docs/design-system/**`, `docs/architecture/**`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md` | edit | Comments and documents (T14, T15) |
| `docs/specs/070-replace-proxy-with-copy/screenshots/**`, `verification.md` | new | Evidence (T16, T17) |

Batches for the implementer subagents (2–4 consecutive tasks, one commit per task, test first): **A** = T1–T2 (then the SHAs go to the coordinator), **B** = T3–T5, **C** = T6–T8, **D** = T9–T11, **E** = T12–T13. The supervisor checks each batch's diff; the documentation (T14, T15), the screenshots (T16) and `verification.md` (T17) are the supervisor's.

---

## Phase 0: The shared parts

**Implements:** FR-3, decisions 2, 7, 8 | **Satisfies:** AC-7.2 (comments), AC-3.4, AC-3.7, AC-3.8 (at the model), AC-3.14
**Files:** `app/models/lot.rb`, `app/models/lot/move_into_zone.rb`, `spec/models/lot/free_spec.rb`, `spec/models/lot/move_into_zone_spec.rb`
**Interfaces:** Produces `Lot.free` (a chainable scope) and `Lot::MoveIntoZone.new(account:, zone:, picks:)#call!` → Integer, raising `Lot::MoveIntoZone::Refused` (`#reasons`: `{ lot_id => :not_free | :count | :not_saveable | :cap }`). Consumed by T4 and by spec 071.

### T1: `Lot.free`

- [ ] **Step 1: The failing spec** `spec/models/lot/free_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 decision 2 (spec 057's "Free to use"): a lot is free when it is in no deck zone.
RSpec.describe Lot, ".free", type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }

  it "holds the unplaced lots and the lots of a place, and no lot in a zone, Considering included", :aggregate_failures do
    unplaced = create(:lot, account:)
    in_a_place = create(:lot, account:, location: create(:location, account:))
    in_main = create_lot_in_zone(deck, "main")
    in_considering = create_lot_in_zone(deck, "considering")

    expect(account.lots.free).to contain_exactly(unplaced, in_a_place)
    expect(account.lots).to include(in_main, in_considering) # the fixture could have produced them
  end

  it "chains with the account's lots and other conditions, and leaves the account scoping to the caller", :aggregate_failures do
    mine = create(:lot, account:)
    other = create(:user).account
    theirs = create(:lot, account: other, location: create(:location, account: other))

    expect(account.lots.free.where(catalog_entry_id: mine.catalog_entry_id)).to contain_exactly(mine)
    expect(described_class.free).to include(mine, theirs)
  end
end
```

- [ ] **Step 2: Run it** `bin/rspec spec/models/lot/free_spec.rb`. Expected: FAIL, `NoMethodError: undefined method 'free'`.

- [ ] **Step 3: The scope.** In `app/models/lot.rb`, after `scope :with_place` (before `before_validation`), add:

```ruby
  # The lots that are free to use: in no deck zone, so unplaced or in a place. A lot in any zone of any deck, Considering
  # included, is in a deck and is not free (spec 057's "Free to use"; spec 070 decision 2). Proxies never change it. Written as
  # "no place or a place" and not as "not in a zone" because `NOT IN` over a NULL location is never true in SQL.
  #
  # Chain it on the account's lots (`account.lots.free`): it names no account itself, and the subselect is over places of any
  # account, which is safe because a lot's place is always its own account's (`location_is_the_accounts`).
  #
  # @return [ActiveRecord::Relation<Lot>]
  scope :free, -> { where(location_id: nil).or(where(location_id: Location.places.select(:id))) }
```

- [ ] **Step 4: Run** `bin/rspec spec/models/lot/free_spec.rb spec/models/lot_spec.rb`. Expected: all PASS. Then `bin/rubocop -a app/models/lot.rb spec/models/lot/free_spec.rb`.

- [ ] **Step 5: Commit** (stage the two files, then commit): `feat(lots): Lot.free, the lots in no deck zone (spec 070, #257)`.

### T2: `Lot::MoveIntoZone`

- [ ] **Step 1: The failing spec** `spec/models/lot/move_into_zone_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 decisions 7 and 8: the all-or-nothing move of chosen copies of free lots into a zone, through Lot::Move.
RSpec.describe Lot::MoveIntoZone, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:zone) { deck.zone("main") }
  let(:binder) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Red box") }
  let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry }

  def lot_in(location, quantity = 4, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def move(picks, to: zone) = described_class.new(account:, zone: to, picks:).call!

  def reasons_of(picks)
    move(picks)
    nil
  rescue described_class::Refused => refused
    refused.reasons
  end

  it "moves a whole lot into the zone, keeping its id, and returns the copies moved", :aggregate_failures do
    lot = lot_in(binder, 3, finish: "foil", condition: "near_mint", price_paid_cents: 150)

    expect(move([ [ lot, 3 ] ])).to eq(3)
    expect(lot.reload).to have_attributes(location: zone, quantity: 3, finish: "foil", condition: "near_mint", price_paid_cents: 150)
    expect(lot.lot_key).to eq(Lot.key_for("foil", "near_mint", 150, zone.id))
  end

  it "moves some copies and leaves the rest in place, in a new lot of the same identity", :aggregate_failures do
    lot = lot_in(binder, 4)

    expect(move([ [ lot, 1 ] ])).to eq(1)
    expect(lot.reload).to have_attributes(location: binder, quantity: 3)
    expect(account.lots.find_by(location: zone)).to have_attributes(entry:, quantity: 1)
  end

  it "moves several lots, merging those that reach one identity into the zone's lot", :aggregate_failures do
    from_binder = lot_in(binder, 2)
    from_box = lot_in(box, 3)
    other_finish = lot_in(binder, 1, finish: "foil")

    expect(move([ [ from_binder, 2 ], [ from_box, 3 ], [ other_finish, 1 ] ])).to eq(6)
    expect(account.lots.where(location: zone).order(:quantity).pluck(:finish, :quantity)).to eq([ [ "foil", 1 ], [ nil, 5 ] ])
    expect(account.lots.where.not(location: zone).count).to eq(0)
  end

  it "writes nothing when the second move would pass the 9,999 cap, the first move included (one transaction)", :aggregate_failures do
    in_zone = lot_in(zone, 9_998)
    first = lot_in(binder, 1)
    second = lot_in(box, 1)

    expect(reasons_of([ [ first, 1 ], [ second, 1 ] ])).to eq({ second.id => :cap })
    expect([ in_zone.reload.quantity, first.reload.location, first.quantity, second.reload.location ]).to eq([ 9_998, binder, 1, box ])
  end

  it "refuses a lot that is no longer free, another account's lot and a lot that is gone, naming each and writing nothing", :aggregate_failures do
    taken = lot_in(deck.zone("sideboard"), 2)
    other = create(:user).account
    theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 2)
    gone = lot_in(binder, 2).tap(&:destroy!)
    fine = lot_in(binder, 2)

    expect(reasons_of([ [ taken, 1 ], [ theirs, 1 ], [ gone, 1 ], [ fine, 1 ] ])).to eq({ taken.id => :not_free, theirs.id => :not_free, gone.id => :not_free })
    expect([ fine.reload.location, fine.quantity ]).to eq([ binder, 2 ])
  end

  it "refuses a count outside 1 to the lot's copies as it stands now", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect(reasons_of([ [ lot, 0 ] ])).to eq({ lot.id => :count })
    expect(reasons_of([ [ lot, 3 ] ])).to eq({ lot.id => :count })
    lot.update_columns(quantity: 1) # changed since the caller read it
    expect(reasons_of([ [ lot, 2 ] ])).to eq({ lot.id => :count })
  end

  it "refuses a lot whose finish the vocabulary no longer lists, instead of skipping validation", :aggregate_failures do
    lot = lot_in(binder, 2)
    lot.update_columns(finish: "retired_finish")

    expect(reasons_of([ [ lot, 1 ] ])).to eq({ lot.id => :not_saveable })
    expect(lot.reload.location).to eq(binder)
  end

  it "judges every pick before it moves any, so the reasons list every refused lot", :aggregate_failures do
    bad = lot_in(binder, 2)
    worse = lot_in(box, 1)

    expect(reasons_of([ [ bad, 5 ], [ worse, 0 ] ])).to eq({ bad.id => :count, worse.id => :count })
  end

  it "refuses a zone that is not a zone of the account and a lot named twice", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect { described_class.new(account:, zone: binder, picks: [ [ lot, 1 ] ]) }.to raise_error(ArgumentError)
    expect { described_class.new(account:, zone: create(:deck).zone("main"), picks: [ [ lot, 1 ] ]) }.to raise_error(ArgumentError)
    expect { described_class.new(account:, zone:, picks: [ [ lot, 1 ], [ lot, 1 ] ]) }.to raise_error(ArgumentError)
  end

  it "joins a caller's transaction: a refusal inside it rolls the caller's own earlier writes back, and the caller's reads and picks stay under its lock", :aggregate_failures do
    in_zone = lot_in(zone, 9_998)
    first = lot_in(binder, 1)
    second = lot_in(box, 1)
    marker = create(:location, account:, name: "Marker")

    expect do
      Lot.transaction do
        marker.update!(name: "Renamed")
        free = account.lots.free.where(id: [ first.id, second.id ]).to_a # read and chosen under the caller's own lock
        move(free.map { |lot| [ lot, 1 ] })
      end
    end.to raise_error(described_class::Refused) { |refused| expect(refused.reasons).to eq({ second.id => :cap }) }

    expect(marker.reload.name).to eq("Marker") # the caller's write was rolled back with the moves
    expect([ in_zone.reload.quantity, first.reload.location ]).to eq([ 9_998, binder ])
  end

  it "tells a lot that fails its own validation, naming it, from the cap", :aggregate_failures do
    bad = lot_in(binder, 2)
    bad.update_columns(finish: "retired_finish")
    in_zone = lot_in(zone, 9_999, finish: "foil")
    capped = lot_in(box, 1, finish: "foil")

    expect(reasons_of([ [ bad, 1 ] ])).to eq({ bad.id => :not_saveable })
    expect(reasons_of([ [ capped, 1 ] ])).to eq({ capped.id => :cap })
    expect(in_zone.reload.quantity).to eq(9_999)
  end

  it "moves nothing and returns 0 for no picks" do
    expect(move([])).to eq(0)
  end

  it "leaves a failure of an outer transaction rolled back as a whole", :aggregate_failures do
    lot = lot_in(binder, 2)

    expect do
      Lot.transaction do
        move([ [ lot, 2 ] ])
        raise ActiveRecord::Rollback
      end
    end.not_to(change { lot.reload.location })
  end
end
```

- [ ] **Step 2: Run it** `bin/rspec spec/models/lot/move_into_zone_spec.rb`. Expected: FAIL, `NameError: uninitialized constant Lot::MoveIntoZone`.

- [ ] **Step 3: The class** `app/models/lot/move_into_zone.rb`:

```ruby
# Moves chosen copies of an account's free lots into one zone of a deck, all or nothing (spec 070 decisions 7 and 8). It is the
# one move of "these lots, this many copies each" into a zone: Use my copy (spec 070) hands it the collector's numbers, and
# "Add to deck" (spec 071) hands it the lots its count takes. It decides nothing about which lots or how many.
#
# It goes through `Lot::Move`, which splits a lot, merges into the zone's lot of the same identity, keeps the 9,999 cap and
# rebuilds the lot key with the zone's id. What it adds is judging every pick before the first write, under the write lock:
# each lot is read again among the account's *free* lots (so a lot taken into a zone, removed, or another account's is
# `:not_free`), its count is checked against the copies it holds now, and a lot the vocabulary can no longer save (a finish or
# condition it no longer lists; `Lot` validates both on save) is `:not_saveable` rather than moved without validation. A `:cap`
# refusal can only be found while moving, so it leaves the transaction by the exception below and the earlier moves roll back.
#
# "Free" is `Lot.free`: in no deck zone (unplaced or in a place; spec 057's "Free to use"). It takes the account explicitly and
# never reads `Current.account`.
#
# Transactions: it works nested inside a caller's transaction, by plain participation (`Lot.transaction` without
# `requires_new`: no savepoint), so a caller that has read the free lots and chosen the picks under its own write lock, or that
# lowers a proxy in the same transaction, keeps one transaction and one rollback. Called on its own it opens one (SQLite's is
# IMMEDIATE, so the reads below are under the lock). A refusal leaves by an exception, never a false return, and nothing in
# here rescues it; a caller must not rescue it inside its transaction either, or the earlier moves stay. Names no collectible.
#
# Refusals: {Refused#reasons} names every lot that can't move, by id, with one reason each: `:cap` (the zone's lot of its
# identity would pass 9,999, which is `Lot::FULL_MESSAGE`'s case) is told apart from `:not_saveable` (the lot fails its own
# validation, a finish or condition the vocabulary no longer lists), `:not_free`, and `:count`.
class Lot::MoveIntoZone
  # Why one lot can't be moved. `reasons` maps a lot's id to one of `:not_free` (no longer one of the account's free lots),
  # `:count` (not from 1 to the copies it holds now), `:not_saveable` (the lot can't be saved as it is) and `:cap` (the zone's
  # lot of its identity would hold more than 9,999; only the first such lot is named, because the moves stop there).
  class Refused < StandardError
    # @return [Hash{Integer => Symbol}]
    attr_reader :reasons

    # @param reasons [Hash{Integer => Symbol}]
    def initialize(reasons)
      @reasons = reasons
      super("lots can't be moved into the zone: #{reasons.inspect}")
    end
  end

  # @param account [Account] the signed-in account; its free lots are the only ones that move
  # @param zone [Location] a zone (kind `deck_zone`) of the account
  # @param picks [Array<Array(Lot, Integer)>] pairs of a lot and the copies to move; a lot appears once; only the lot's id is
  #   used, the lot is read again
  # @raise [ArgumentError] when the zone is not a zone of the account or a lot is named twice (programming errors)
  def initialize(account:, zone:, picks:)
    raise ArgumentError, "not a zone of the account" unless zone.zone? && zone.account_id == account.id

    ids = picks.map { |lot, _count| lot.id }
    raise ArgumentError, "a lot is named twice" unless ids.uniq.size == ids.size

    @account, @zone, @picks = account, zone, picks.map { |lot, count| [ lot.id, count ] }
  end

  # Moves the picked copies. One transaction: judged first, then moved lot by lot.
  #
  # @return [Integer] the copies moved
  # @raise [Refused] when any pick is refused; nothing is changed (a `:cap` found part way rolls the earlier moves back)
  def call!
    Lot.transaction do
      current = @account.lots.free.where(id: @picks.map(&:first)).index_by(&:id)
      reasons = judge(current)
      raise Refused, reasons if reasons.any?

      @picks.sum { |id, count| move(current.fetch(id), count) }
    end
  end

  private
    # Every refused pick with its reason, none moved yet.
    def judge(current)
      @picks.each_with_object({}) do |(id, count), reasons|
        lot = current[id]
        reason = if lot.nil? then :not_free
        elsif !count.is_a?(Integer) || !count.between?(1, lot.quantity) then :count
        elsif !lot.valid? then :not_saveable
        end
        reasons[id] = reason if reason
      end
    end

    # `Lot::Move` raises for itself, with `Lot::FULL_MESSAGE` on `copies` for the cap and no message for a lot or twin it can't
    # save; the pre-checks above make its own range sentences impossible here.
    def move(lot, count)
      Lot::Move.new(lot:, to: @zone, copies: count.to_s).call!
      count
    rescue ActiveRecord::RecordInvalid => error
      raise Refused, { lot.id => error.record.errors[:copies].include?(Lot::FULL_MESSAGE) ? :cap : :not_saveable }
    end
end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/lot/move_into_zone_spec.rb spec/models/lot/move_spec.rb`. Expected: PASS. `bin/rubocop -a` on both files. Check the YARD build for the file: `bin/yard doc 2>&1 | tail -5` shows no warning.

- [ ] **Step 5: Commit**: `feat(lots): Lot::MoveIntoZone, an all-or-nothing move of chosen copies into a zone (spec 070, #257)`. **Then send the coordinator the SHAs of T1 and T2** (`git log --oneline -2`), and do not change those four files again without telling them.

---

## Phase 1: The proxy actions

**Implements:** FR-1, FR-2, decisions 5–7, 9–11 | **Satisfies:** AC-3.1 to AC-3.15, AC-4.2 to AC-4.6a
**Files:** `app/models/deck/proxy.rb`, `app/models/deck/proxy/use_copies.rb`, `app/models/deck/proxy/add_copy.rb`, `spec/models/deck/proxy_spec.rb`, `spec/models/deck/proxy/use_copies_spec.rb`, `spec/models/deck/proxy/add_copy_spec.rb`
**Interfaces:** Produces `Deck::Proxy.replaceable?(entry)`, `Deck::Proxy#lower_by!(count)`, `Deck::Proxy::UseCopies` (`#groups`, `#fieldset_errors`, `#save`, `#used`) and `Deck::Proxy::AddCopy` (`#save`, `#form`, `#added`).

### T3: `replaceable?` and `lower_by!`

- [ ] **Step 1: The failing examples**, added to `spec/models/deck/proxy_spec.rb` (inside the existing `RSpec.describe`):

```ruby
  describe ".replaceable?" do
    it "is true for a printing of a registered collectible and false for one the instance lost (spec 070 decision 1)", :aggregate_failures do
      expect(described_class.replaceable?(entry)).to be(true)
      expect(described_class.replaceable?(build(:catalog_entry, collectible_type: "gone"))).to be(false)
    end
  end

  describe "#lower_by!" do
    it "lowers the quantity and keeps the row and its times but updated_at", :aggregate_failures do
      proxy = add(quantity: 5)
      proxy.update_columns(created_at: 2.days.ago)

      proxy.lower_by!(2)

      expect(proxy.reload).to have_attributes(quantity: 3)
      expect(proxy.created_at).to be < 1.day.ago
    end

    it "removes the proxy when the count equals its quantity", :aggregate_failures do
      proxy = add(quantity: 2)

      proxy.lower_by!(2)

      expect(proxy).to be_destroyed
      expect(described_class.count).to eq(0)
    end

    it "refuses a count below 1 or over the quantity and changes nothing", :aggregate_failures do
      proxy = add(quantity: 2)

      expect { proxy.lower_by!(0) }.to raise_error(ArgumentError)
      expect { proxy.lower_by!(3) }.to raise_error(ArgumentError)
      expect(proxy.reload.quantity).to eq(2)
    end
  end
```

- [ ] **Step 2: Run** `bin/rspec spec/models/deck/proxy_spec.rb`. Expected: the new examples FAIL (`NoMethodError`).

- [ ] **Step 3: The code**, in `app/models/deck/proxy.rb` after `.parse_quantity`:

```ruby
  # Whether the two replacement pages (spec 070) can be offered for a proxy of this printing: they name finishes and conditions
  # from the printing's collectible's vocabulary, so a printing whose collectible the instance no longer registers has none. The
  # test reads the printing's type and not the deck's (spec 070 decision 1): a change of format can leave a deck of one type
  # holding proxies of another (decision 19 of spec 068).
  #
  # @param entry [Catalog::Entry]
  # @return [Boolean]
  def self.replaceable?(entry) = Catalog.collecting.key?(entry.collectible_type)
```

and after `#change_quantity!`:

```ruby
  # Lowers the quantity by +count+ and removes the proxy when that reaches zero: the proxy's share of a replacement by copies
  # (spec 070 decision 6). Call it inside the transaction that moved or added the copies, on a proxy read again under the lock.
  #
  # @param count [Integer] from 1 to the quantity
  # @return [Deck::Proxy] self (destroyed when the count was the whole quantity)
  # @raise [ArgumentError] when +count+ is below 1 or over the quantity, a programming error: the callers judge it first
  def lower_by!(count)
    raise ArgumentError, "count must be from 1 to #{quantity}" unless count.is_a?(Integer) && count.between?(1, quantity)

    count == quantity ? destroy! : update!(quantity: quantity - count)
    self
  end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/deck/proxy_spec.rb`. Expected: PASS. `bin/rubocop -a` on both.
- [ ] **Step 5: Commit**: `feat(decks): Deck::Proxy.replaceable? and #lower_by! (spec 070, #257)`.

### T4: `Deck::Proxy::UseCopies`

- [ ] **Step 1: The failing spec** `spec/models/deck/proxy/use_copies_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 Stories 2 and 3 at the model: the free lots of a card, their groups, and the all-or-nothing replacement.
RSpec.describe Deck::Proxy::UseCopies, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:zone) { deck.zone("main") }
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:binder) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Red box") }

  def printing(set: "2x2", finishes: %w[foil nonfoil]) = create(:mtg_printing, entry: create(:catalog_entry, name: "Lightning Bolt", identity: bolt, set: create(:catalog_set, code: set)), finishes:).entry
  def proxy_of(entry, quantity: 2, finish: "foil") = create(:deck_proxy, zone:, account:, entry:, finish:, quantity:)
  def lot_in(location, entry, quantity = 2, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def uses(proxy, typed = {}, shown = nil) = described_class.new(proxy:, typed:, shown: shown || typed.to_h { |id, _| [ id, account.lots.find(id).quantity.to_s ] })

  let(:entry) { printing }
  let!(:proxy) { proxy_of(entry) }

  describe "#groups" do
    it "lists the account's free lots of the card: this printing and finish first, the rest under Other printings, in the card page's order", :aggregate_failures do
      same = lot_in(binder, entry, 1, finish: "foil")
      other_finish = lot_in(box, entry, 1, finish: "nonfoil")
      other_printing = lot_in(box, printing(set: "mm3"), 1, finish: "foil")
      lot_in(zone, entry, 1, finish: "foil")                                     # in this zone
      lot_in(deck.zone("considering"), entry, 1, finish: "foil")                 # in Considering
      create(:lot, entry: create(:mtg_printing, entry: create(:catalog_entry, name: "Other card")).entry, location: binder, account:) # another card
      other = create(:user).account
      create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 1, finish: "foil") # another account's

      groups = uses(proxy).groups

      expect(groups.map(&:first)).to eq([ "This printing", "Other printings" ])
      expect(groups.first.last.map { it.lot }).to eq([ same ])
      expect(groups.last.last.map { it.lot }).to match_array([ other_finish, other_printing ])
    end

    it "leaves a group with no lot out, and is empty with no free lot", :aggregate_failures do
      expect(uses(proxy).groups).to eq([])
      lot_in(box, printing(set: "mm3"), 1)
      expect(uses(proxy).groups.map(&:first)).to eq([ "Other printings" ])
    end

    it "matches a proxy with no finish to a lot with none" do
      bare = printing(set: "bare", finishes: [])
      bare_proxy = proxy_of(bare, finish: nil)
      lot = lot_in(binder, bare, 1)

      expect(uses(bare_proxy).groups.map { |name, rows| [ name, rows.map(&:lot) ] }).to eq([ [ "This printing", [ lot ] ] ])
    end
  end

  describe "#save" do
    it "moves the chosen copies into the zone and lowers the proxy, keeping the proxy's id", :aggregate_failures do
      lot = lot_in(binder, entry, 3, finish: "foil")

      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(true)
      expect(form.used).to eq(1)
      expect(proxy.reload.quantity).to eq(1)
      expect(lot.reload).to have_attributes(location: binder, quantity: 2)
      expect(account.lots.find_by(location: zone)).to have_attributes(quantity: 1, finish: "foil")
    end

    it "removes the proxy when the copies used equal its count", :aggregate_failures do
      lot = lot_in(binder, entry, 3, finish: "foil")

      expect(uses(proxy, { lot.id.to_s => "2" }).save).to be(true)

      expect(Deck::Proxy.exists?(proxy.id)).to be(false)
      expect(account.lots.find_by(location: zone).quantity).to eq(2)
    end

    it "lowers the proxy and keeps it when fewer copies are used than it holds", :aggregate_failures do
      big = proxy_of(printing(set: "big"), quantity: 4)
      lot = lot_in(binder, big.entry, 1, finish: "foil")

      uses(big, { lot.id.to_s => "1" }).save

      expect(big.reload.quantity).to eq(3)
    end

    it "uses copies of several lots, other printings too, and the zone's row of them is of their own printing", :aggregate_failures do
      other = printing(set: "mm3")
      a = lot_in(binder, entry, 1, finish: "foil")
      b = lot_in(box, other, 1, finish: "foil")

      form = uses(proxy, { a.id.to_s => "1", b.id.to_s => "1" })

      expect(form.save).to be(true)
      expect(account.lots.where(location: zone).pluck(:catalog_entry_id)).to match_array([ entry.id, other.id ])
    end

    it "refuses a number that isn't a whole number from 0 to the lot's copies, under that lot", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")

      %w[3 -1 1.5 abc].each do |typed|
        form = uses(proxy, { lot.id.to_s => typed })
        expect(form.save).to be(false), typed
        expect(form.rows.first.errors).to eq([ "Enter a number from 0 to 2." ]), typed
      end
      expect(lot.reload.location).to eq(binder)
    end

    it "treats blank as 0 and refuses a total of 0 or over the proxy's count, under the lots' fieldset", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")

      zero = uses(proxy, { lot.id.to_s => "" })
      over = uses(proxy, { lot.id.to_s => "3" })

      expect([ zero.save, over.save ]).to eq([ false, false ])
      expect([ zero.fieldset_errors, over.fieldset_errors ]).to eq([ [ "Enter a number from 1 to 2." ], [ "Enter a number from 1 to 2." ] ])
      expect(proxy.reload.quantity).to eq(2)
    end

    it "shows the sum's sentence only when no field or lot sentence applies", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "9" })

      form.save

      expect(form.fieldset_errors).to eq([])
      expect(form.rows.first.errors).to eq([ "Enter a number from 0 to 2." ])
    end

    it "refuses a lot that was removed, taken into a zone, moved out in part, or is another account's: 'Those copies changed'", :aggregate_failures do
      gone = lot_in(binder, entry, 1, finish: "foil")
      taken = lot_in(box, entry, 1, finish: "foil")
      part = lot_in(binder, entry, 5, finish: "nonfoil")
      other = create(:user).account
      theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 1)
      typed = { gone.id.to_s => "1", taken.id.to_s => "1", part.id.to_s => "1", theirs.id.to_s => "1" }
      shown = { gone.id.to_s => "1", taken.id.to_s => "1", part.id.to_s => "5", theirs.id.to_s => "1" }
      gone.destroy!
      taken.update!(location: deck.zone("sideboard"))
      part.update!(quantity: 3) # a split lowered it since the page was shown

      form = described_class.new(proxy:, typed:, shown:)

      expect(form.save).to be(false)
      expect(form.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
      expect(proxy.reload.quantity).to eq(2)
      expect(account.lots.where(location: zone)).to be_empty
    end

    it "fails closed on a missing or malformed shown value, and ignores a lot with 0 whatever it is", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      other = lot_in(box, entry, 1, finish: "foil")

      missing = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: {})
      junk = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "two" })
      zeroes = described_class.new(proxy:, typed: { lot.id.to_s => "1", other.id.to_s => "0", "x" => "5" }, shown: { lot.id.to_s => "2" })

      expect([ missing.save, junk.save ]).to eq([ false, false ])
      expect(missing.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
      expect(zeroes.save).to be(true)
    end

    it "refuses the second submit of one form: the first split the lot, so its quantity is no longer the one shown", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")
      typed = { lot.id.to_s => "1" }
      shown = { lot.id.to_s => "5" } # what the page drew

      expect(described_class.new(proxy:, typed:, shown:).save).to be(true)
      again = described_class.new(proxy: Deck::Proxy.find(proxy.id), typed:, shown:)

      expect(again.save).to be(false)
      expect(again.fieldset_errors).to eq([ "Those copies changed. Check the numbers and try again." ])
      expect(lot.reload.quantity).to eq(4) # moved once
      expect(proxy.reload.quantity).to eq(1) # lowered once
    end

    it "writes again the shown quantities of a refused page from a fresh read, so the next submit succeeds", :aggregate_failures do
      lot = lot_in(binder, entry, 5, finish: "foil")
      form = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "9" })

      expect(form.save).to be(false)
      row = form.groups.first.last.first
      expect(row).to have_attributes(shown: 5, typed: "1")

      retry_form = described_class.new(proxy:, typed: { lot.id.to_s => "1" }, shown: { lot.id.to_s => row.shown.to_s })
      expect(retry_form.save).to be(true)
    end

    it "refuses a lot over the cap in the zone under that lot's field, and writes nothing", :aggregate_failures do
      lot_in(zone, entry, 9_999, finish: "foil")
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.rows.first.errors).to eq([ "One lot can hold at most 9,999 copies." ])
      expect([ lot.reload.location, proxy.reload.quantity ]).to eq([ binder, 2 ])
    end

    it "refuses a lot the vocabulary can no longer save, under that lot's field", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      lot.update_columns(finish: "retired_finish")
      form = uses(proxy, { lot.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.rows.first.errors).to eq([ "Edit this copy first: its finish or condition isn't offered any more." ])
    end

    it "shows a lot the vocabulary can't save beside a total over the count: the lot's sentence and not the sum's", :aggregate_failures do
      stale = lot_in(binder, entry, 2, finish: "foil")
      stale.update_columns(finish: "retired_finish")
      fine = lot_in(box, entry, 2, finish: "nonfoil")
      form = uses(proxy, { stale.id.to_s => "2", fine.id.to_s => "2" }) # a total of 4 over the count of 2

      expect(form.save).to be(false)
      expect(form.rows.find { it.lot == stale }.errors).to eq([ "Edit this copy first: its finish or condition isn't offered any more." ])
      expect(form.fieldset_errors).to eq([])
    end

    # A characterisation, not a red: it passes on arrival, since the lots drawn are read after the transaction (AC-3.15).
    it "builds the page of a refusal from a fresh read after the rollback (the first lot holds what it held)", :aggregate_failures do
      lot_in(zone, entry, 9_999, finish: "foil")
      first = lot_in(binder, entry, 2, finish: "nonfoil")
      second = lot_in(box, entry, 2, finish: "foil")
      form = uses(proxy, { first.id.to_s => "1", second.id.to_s => "1" })

      expect(form.save).to be(false)
      expect(form.groups.flat_map(&:last).to_h { [ it.lot.id, it.lot.quantity ] }).to eq({ first.id => 2, second.id => 2 })
    end

    it "answers RecordNotFound for a proxy removed meanwhile, and writes nothing", :aggregate_failures do
      lot = lot_in(binder, entry, 2, finish: "foil")
      form = uses(proxy, { lot.id.to_s => "1" })
      proxy.destroy!

      expect { form.save }.to raise_error(ActiveRecord::RecordNotFound)
      expect(lot.reload.location).to eq(binder)
    end
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/models/deck/proxy/use_copies_spec.rb`. Expected: FAIL, `uninitialized constant Deck::Proxy::UseCopies`.

- [ ] **Step 3: The class** `app/models/deck/proxy/use_copies.rb`:

```ruby
# Use my copy's form object (spec 070 Stories 2 and 3): the free lots of a proxy's card as the page lists them, and the
# replacement of the proxy by the copies the collector chose, lot by lot. One transaction does it all: judged under the write
# lock against a fresh read, moved through `Lot::MoveIntoZone` (which goes through `Lot::Move`), then the proxy lowered by the
# copies used or removed at zero.
#
# What the form posts: `lots[<lot id>]` (the number typed, blank is 0) and `shown[<lot id>]` (the lot's quantity as the page
# drew it). A chosen lot whose quantity is no longer the shown one, or that is no longer free, is refused: that is what makes a
# second submit of one form (two tabs, a double click) refuse instead of moving twice (decision 9). A refused page is built
# again from a fresh read with every `shown` written again and the typed numbers kept, so correcting and submitting again works.
#
# Not for reuse beyond the page: "Add to deck" (spec 071) takes its lots from its own count and uses `Lot::MoveIntoZone`.
# @see file:collection-and-lots.md
class Deck::Proxy::UseCopies
  CHANGED = "Those copies changed. Check the numbers and try again.".freeze
  NOT_OFFERED = "Edit this copy first: its finish or condition isn't offered any more.".freeze

  # One lot as the page draws it: the lot, what was typed for it ("0" at first), the quantity the page now shows for it and its
  # sentences.
  Row = Data.define(:lot, :typed, :shown, :errors)

  # @return [Deck::Proxy] the proxy being replaced (read again by {#save})
  attr_reader :proxy
  # @return [Array<String>] the sentences for the lots' fieldset
  attr_reader :fieldset_errors
  # @return [Integer, nil] the copies used by a successful {#save}
  attr_reader :used

  # @param proxy [Deck::Proxy] a proxy found through the signed-in account's deck
  # @param typed [Hash] `lots` as posted: lot id => text
  # @param shown [Hash] `shown` as posted: lot id => the quantity the page showed, as text
  def initialize(proxy:, typed: {}, shown: {})
    @proxy = proxy
    @typed = typed.to_h.transform_keys(&:to_s)
    @shown = shown.to_h.transform_keys(&:to_s)
    @fieldset_errors = []
    @field_errors = Hash.new { |errors, id| errors[id] = [] }
  end

  # The account's free lots of the proxy's card, any printing, in the order of the card page's "Your copies" (newest printing,
  # finish, condition, price paid, place); retired printings included. Read once per state of the world: {#save} forgets it, so
  # a page drawn after a refusal reads again.
  #
  # @return [Array<Lot>]
  def free_lots
    @free_lots ||= proxy.account.lots.free.joins(:entry).left_joins(:location)
      .where(catalog_entries: { catalog_identity_id: proxy.entry.catalog_identity_id })
      .includes(entry: :set).preload(:location).merge(Catalog::Entry.newest_first)
      .order(:finish, :condition, :price_paid_cents)
      .order(Location.arel_table[:name_key].asc, Location.arel_table[:name].asc).to_a
  end

  # The lots in their groups, a group with no lot left out: "This printing" (the proxy's printing and finish) then "Other
  # printings" (everything else, another finish of the printing included).
  #
  # @return [Array<Array(String, Array<Row>)>]
  def groups
    own, rest = rows.partition { |row| row.lot.catalog_entry_id == proxy.catalog_entry_id && row.lot.finish == proxy.finish }
    [ [ "This printing", own ], [ "Other printings", rest ] ].reject { |_name, in_group| in_group.empty? }
  end

  # The free lots as {Row}s, in the lots' order: what was typed for each ("0" at first), the quantity to show and its sentences.
  #
  # @return [Array<Row>]
  def rows
    free_lots.map { |lot| Row.new(lot:, typed: @typed.fetch(lot.id.to_s, "0"), shown: lot.quantity, errors: @field_errors[lot.id].dup) }
  end

  # Replaces the proxy by the chosen copies, or says why not.
  #
  # @return [Boolean] false, with sentences on {#fieldset_errors} and the rows, when nothing was written
  # @raise [ActiveRecord::RecordNotFound] when the proxy was removed meanwhile (a 404)
  def save
    @fieldset_errors, @field_errors, @used = [], Hash.new { |errors, id| errors[id] = [] }, nil
    done = Lot.transaction do
      proxy.reload # the proxy's count now, under the write lock
      @free_lots = nil
      @picks = judge
      next false if invalid?

      Lot::MoveIntoZone.new(account: proxy.account, zone: proxy.zone, picks: @picks).call!
      proxy.lower_by!(@used = @picks.sum(&:last))
      true
    end
    @free_lots = nil unless done # the page is drawn from a read made after the transaction
    done
  rescue Lot::MoveIntoZone::Refused => refused
    @free_lots = nil
    absorb(refused)
    false
  end

  private
    def invalid? = @fieldset_errors.any? || @field_errors.values.any?(&:any?)

    # Parses what was typed, checks each chosen lot against the fresh read and the sum against the proxy's count. Returns the
    # `[lot, count]` pairs to move; the sentences are on the form.
    def judge
      lots = free_lots.index_by { |lot| lot.id.to_s }
      picks = []
      @typed.each do |key, text|
        next unless key.match?(Location::ID_TEXT)

        count = parse(text)
        lot = lots[key]
        if lot.nil?
          changed if count&.positive?
          next
        end
        field(lot, "Enter a number from 0 to #{number(lot.quantity)}.") if count.nil? || count > lot.quantity
        next unless count&.positive?

        field(lot, NOT_OFFERED) unless lot.valid? # a finish or condition the vocabulary no longer lists: judged with the other checks (decision 9); MoveIntoZone's own check is the backstop

        changed unless @shown[key].to_s.match?(/\A\d+\z/) && @shown[key].to_i == lot.quantity
        picks << [ lot, count ] if count <= lot.quantity
      end
      check_sum(picks) unless invalid?
      picks
    end

    def check_sum(picks)
      return if picks.sum(&:last).between?(1, proxy.quantity)

      @fieldset_errors << "Enter a number from 1 to #{number(proxy.quantity)}."
    end

    # A whole number from 0 up as typed, blank as 0, anything else nil.
    def parse(text)
      text = text.to_s.strip
      return 0 if text.empty?

      Integer(text, 10, exception: false)&.then { it if it >= 0 }
    end

    def changed = (@fieldset_errors << CHANGED unless @fieldset_errors.include?(CHANGED))

    def field(lot, sentence) = @field_errors[lot.id] << sentence

    def number(count) = ActiveSupport::NumberHelper.number_to_delimited(count)

    # `Lot::MoveIntoZone`'s reasons as this page says them.
    def absorb(refused)
      refused.reasons.each do |id, reason|
        case reason
        when :cap then @field_errors[id] << Lot::FULL_MESSAGE
        when :not_saveable then @field_errors[id] << NOT_OFFERED
        else changed
        end
      end
    end
end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/deck/proxy/use_copies_spec.rb`. Expected: PASS. Fix examples against the sentences only if a sentence is wrong in the spec, never by loosening the assertion. `bin/rubocop -a` on both files.
- [ ] **Step 5: Commit**: `feat(decks): Deck::Proxy::UseCopies, the free lots of a card and their move into the zone (spec 070, #257)`.

### T5: `Deck::Proxy::AddCopy`

- [ ] **Step 1: The failing spec** `spec/models/deck/proxy/add_copy_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 Story 4 at the model: a new copy added to the proxy's zone, the proxy lowered by the same quantity.
RSpec.describe Deck::Proxy::AddCopy, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:zone) { deck.zone("main") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }
  let!(:proxy) { create(:deck_proxy, zone:, account:, entry:, finish: "foil", quantity: 3) }

  def form(**attrs) = Lot::Form.new(entry:, **{ quantity: "1", finish: "foil" }.merge(attrs))
  def add(form = self.form, shown: proxy.quantity.to_s) = described_class.new(proxy:, form:, shown_quantity: shown)

  it "adds the lot to the zone, merging into the zone's lot of that identity, and lowers the proxy", :aggregate_failures do
    in_zone = create(:lot, account:, entry:, location: zone, finish: "foil", quantity: 2)

    expect(add(form(quantity: "2")).save).to be(true)

    expect(in_zone.reload.quantity).to eq(4)
    expect(proxy.reload.quantity).to eq(1)
    expect(account.lots.count).to eq(1)
  end

  it "adds a new lot with the form's finish, condition and price, and removes the proxy at zero", :aggregate_failures do
    expect(add(form(quantity: "3", finish: "nonfoil", condition: "near_mint", price_paid: "1.25")).save).to be(true)

    expect(account.lots.find_by(location: zone)).to have_attributes(entry:, quantity: 3, finish: "nonfoil", condition: "near_mint", price_paid_cents: 125)
    expect(Deck::Proxy.exists?(proxy.id)).to be(false)
  end

  it "lowers the proxy in the path whatever the copy's finish and no other proxy of the row", :aggregate_failures do
    other = create(:deck_proxy, zone:, account:, entry:, finish: "nonfoil", quantity: 2)

    add(form(quantity: "1", finish: "nonfoil")).save

    expect([ proxy.reload.quantity, other.reload.quantity ]).to eq([ 2, 2 ])
  end

  it "refuses a quantity over the proxy's count, after the form's own sentences", :aggregate_failures do
    over = add(form(quantity: "4"))
    huge = add(form(quantity: "10000"))

    expect([ over.save, huge.save ]).to eq([ false, false ])
    expect(over.form.errors[:quantity]).to eq([ "Enter a number from 1 to 3." ])
    expect(huge.form.errors[:quantity]).to eq([ "must be a whole number from 1 to 9,999" ]) # Add a copy's sentence wins
    expect(account.lots.count).to eq(0)
  end

  it "refuses when the proxy is not the count the form showed, and shows the count now (a second submit)", :aggregate_failures do
    first = add(form(quantity: "1"))
    expect(first.save).to be(true)

    again = add(form(quantity: "1"), shown: "3")

    expect(again.save).to be(false)
    expect(again.form.errors[:quantity]).to eq([ "This proxy changed. Check the quantity and try again." ])
    expect([ proxy.reload.quantity, account.lots.sum(:quantity) ]).to eq([ 2, 1 ])
  end

  it "fails closed on a missing shown count", :aggregate_failures do
    expect(add(form, shown: nil).save).to be(false)
    expect(account.lots.count).to eq(0)
  end

  it "refuses a merge past 9,999 and changes neither the lot nor the proxy", :aggregate_failures do
    create(:lot, account:, entry:, location: zone, finish: "foil", quantity: 9_999)
    refused = add(form(quantity: "1"))

    expect(refused.save).to be(false)
    expect(refused.form.errors[:quantity]).to include(Lot::FULL_MESSAGE)
    expect(proxy.reload.quantity).to eq(3)
  end

  it "answers RecordNotFound for a proxy removed meanwhile", :aggregate_failures do
    pending_add = add
    proxy.destroy!

    expect { pending_add.save }.to raise_error(ActiveRecord::RecordNotFound)
    expect(account.lots.count).to eq(0)
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/models/deck/proxy/add_copy_spec.rb`. Expected: FAIL (`uninitialized constant`).
- [ ] **Step 3: The class** `app/models/deck/proxy/add_copy.rb`:

```ruby
# Add a new copy's form object (spec 070 Story 4): the Add a copy form (`Lot::Form`) for the proxy's printing, whose copy lands
# in the proxy's zone through `Lot.add!` (merging as every add does) while the proxy is lowered by the same quantity, in one
# transaction. The form posts the proxy's count as it showed it (`shown_quantity`): a proxy that is not that count any more is
# refused, which is what stops a second submit of one form from adding twice (decision 10).
#
# Sentences, in this order: the form's own (`Lot::Form`'s, a quantity that isn't a whole number from 1 to 9,999 included), then
# "This proxy changed…", then "Enter a number from 1 to N." (N the proxy's count now).
# @see file:collection-and-lots.md
class Deck::Proxy::AddCopy
  CHANGED = "This proxy changed. Check the quantity and try again.".freeze

  # @return [Deck::Proxy] the proxy being replaced, read again by {#save}
  attr_reader :proxy
  # @return [Lot::Form] the form, with its sentences after a refused {#save}
  attr_reader :form
  # @return [Integer, nil] the copies added by a successful {#save}
  attr_reader :added

  # @param proxy [Deck::Proxy] a proxy found through the signed-in account's deck
  # @param form [Lot::Form] built for the proxy's printing from the permitted fields (never a location)
  # @param shown_quantity [String, nil] the proxy's count as the form showed it
  def initialize(proxy:, form:, shown_quantity:)
    @proxy, @form, @shown_quantity = proxy, form, shown_quantity
  end

  # Adds the copy and lowers the proxy, or says why not.
  #
  # @return [Boolean] false, with the sentence on the form's `quantity` or the field the lot's refusal belongs to, when nothing
  #   was written
  # @raise [ActiveRecord::RecordNotFound] when the proxy was removed meanwhile (a 404)
  def save
    Lot.transaction do
      proxy.reload # its count now, under the write lock
      next false unless acceptable?

      quantity = form.lot_attributes[:quantity]
      Lot.add!(account: proxy.account, entry: proxy.entry, location: proxy.zone, **form.lot_attributes)
      proxy.lower_by!(@added = quantity)
      true
    end
  rescue ActiveRecord::RecordInvalid => error
    form.absorb(error.record)
    proxy.reload
    false
  end

  private
    def acceptable?
      return false unless form.valid?

      if @shown_quantity.to_s != proxy.quantity.to_s
        form.errors.add(:quantity, CHANGED)
      elsif form.lot_attributes[:quantity] > proxy.quantity
        form.errors.add(:quantity, "Enter a number from 1 to #{ActiveSupport::NumberHelper.number_to_delimited(proxy.quantity)}.")
      end
      form.errors.empty?
    end
end
```

- [ ] **Step 4: Run** `bin/rspec spec/models/deck/proxy/add_copy_spec.rb`. PASS; `bin/rubocop -a`.
- [ ] **Step 5: Commit**: `feat(decks): Deck::Proxy::AddCopy, a new copy in the zone and the proxy lowered (spec 070, #257)`.

---

## Phase 2: The menu and Use my copy

**Implements:** FR-1, decision 1, 3, 4, 9, 11 | **Satisfies:** AC-1.1 to AC-1.5, AC-2.1 to AC-2.9, AC-3.1 to AC-3.3, AC-3.5 to AC-3.15 (at the page), AC-3.12, AC-3.13
**Files:** `config/routes.rb`, `app/models/deck/page.rb`, `app/helpers/decks_helper.rb`, `app/views/decks/_proxy_menu.html.erb`, `app/controllers/decks/proxies/replacements_controller.rb`, `app/views/decks/proxies/replacements/new.html.erb`, `spec/requests/deck_pages_spec.rb`, `spec/requests/deck_proxy_replacements_spec.rb`
**Interfaces:** Produces the routes `new_deck_proxy_replacement_path`, `deck_proxy_replacement_path`, `new_deck_proxy_copy_path`, `deck_proxy_copy_path`; `Deck::Page::Row#replaceable?`; helpers `proxy_item_label(verb, line, row)` (verbs `"Use"`, `"Add"`, `"Change"`, `"Remove"`), `replaces_line(deck, proxy)`, `lot_pick_label(lot)`.

### T6: The routes and the menu

- [ ] **Step 1: List what this breaks, by the spec's own grep**: `git grep -n -i "use my copy\|add a new copy\|UseMyCopy\|#257\|writers\|only by hand\|changes a proxy\|Change proxy count\|Remove proxy" -- spec docs CLAUDE.md app ':!.kamal/secrets'`. Each hit and what becomes of it: `spec/requests/deck_pages_spec.rb` lines 135 to 160 (the two menu examples) change in this task; `spec/requests/deck_proxies_spec.rb:254-256` (the Change page's sentence "To remove it, use Remove proxy.") is unaffected; `spec/system/design_system_deck_components_spec.rb:201` draws a static menu and is unaffected; `app/helpers/decks_helper.rb:55` (`proxy_item_label`'s comment) is replaced in this task; the comment at `app/assets/stylesheets/collector/additions.css:520-523` ("Pick list for AddToDeck and UseMyCopy") stays true; `app/models/deck/proxy.rb`'s header and `spec/models/lot_proxy_isolation_spec.rb`'s header change in T14; the design-system documents (`DeckPage.md` lines 5, 82, 83; `UseMyCopy.md`; the previews `DeckPage.html` and `DeckPagePhone.html`, whose row menus draw "Add a new copy" and "Move copies" without "Use my copy") change in T14; the area docs and `CLAUDE.md` in T15; `docs/roadmap.md`'s #257 line in T15. Record this list in `verification.md` (T17).

- [ ] **Step 2: The failing examples.** In `spec/requests/deck_pages_spec.rb` change the two examples to:

```ruby
      it "has a menu cell with the proxy items for a row with a proxy, and none for a row without (AC-1.1, AC-1.3)", :aggregate_failures do
        bolt = printing
        proxy = proxy_in("main", bolt)
        own("main", printing(name: "Spell Pierce"))

        get deck_path(deck)

        rows = card_rows(zone_section("Main"))
        with, without = rows.partition { it.at_css("a").text.include?("Lightning") }.map(&:first)
        trigger = with.at_css("td.c-table__actions summary")
        expect(trigger["aria-label"]).to match(/\AActions for Lightning Bolt /)
        items = with.css(".c-menu__item")
        expect(items.map { it.text.strip }).to eq([ "Use my copy", "Add a new copy", "Change proxy count", "Remove proxy" ])
        expect(items.map { it["href"] }).to eq([ new_deck_proxy_replacement_path(deck, proxy), new_deck_proxy_copy_path(deck, proxy),
                                                  edit_deck_proxy_path(deck, proxy), new_deck_proxy_removal_path(deck, proxy) ])
        expect(items.last["class"]).to include("c-menu__item--danger")
        expect(with.css(".c-menu__sep").size).to eq(1)
        expect(with.css("form, button")).to be_empty
        expect(without.at_css("td.c-table__actions").children.map(&:text).join.strip).to eq("")
        expect(without.at_css("summary")).to be_nil
        expect(html.css("th").map { it.text.strip }.first(6)).to eq([ "Card", "Cost", "Owned", "Proxy", "Total", "Actions" ])
      end

      it "names the finish in a row with proxies of two finishes (AC-1.2)", :aggregate_failures do
        bolt = printing
        foil = proxy_in("main", bolt, finish: "foil", quantity: 1)
        nonfoil = proxy_in("main", bolt, finish: "nonfoil", quantity: 2)

        get deck_path(deck)

        items = card_rows(zone_section("Main")).first.css(".c-menu__item")
        expect(items.map { it.text.strip }).to eq([ "Use my copy for Foil proxy", "Use my copy for Nonfoil proxy", "Add a new copy for Foil proxy",
                                                     "Add a new copy for Nonfoil proxy", "Change Foil proxy count", "Change Nonfoil proxy count",
                                                     "Remove Foil proxy", "Remove Nonfoil proxy" ])
        expect(items.first(2).map { it["href"] }).to eq([ new_deck_proxy_replacement_path(deck, foil), new_deck_proxy_replacement_path(deck, nonfoil) ])
        expect(items[2, 2].map { it["href"] }).to eq([ new_deck_proxy_copy_path(deck, foil), new_deck_proxy_copy_path(deck, nonfoil) ])
      end

      it "leaves the two replacement items out for a proxy whose printing's collectible the instance no longer registers, and keeps them for a registered printing in a deck of an unregistered type (AC-1.4)", :aggregate_failures do
        bolt = printing
        proxy_in("main", bolt)
        bolt.update_columns(collectible_type: "gone")

        get deck_path(deck)
        expect(card_rows(zone_section("Main")).first.css(".c-menu__item").map { it.text.strip }).to eq([ "Change proxy count", "Remove proxy" ])

        bolt.update_columns(collectible_type: "mtg")
        deck.update_columns(collectible_type: "gone") # a change of format can leave such a deck (spec 068 decision 19)
        get deck_path(deck)
        expect(card_rows(zone_section("Main")).first.css(".c-menu__item").map { it.text.strip }).to include("Use my copy", "Add a new copy")
      end
```

(the helper `proxy_in` returns the proxy already: it is `create(:deck_proxy, …)`.) Also add one example that the deck page's statements are unchanged by the items (AC-1.5): reuse the page's existing statement-count example and add a proxy row with two finishes to its data; the count must stay the same as before this task (run the existing example first and note the number).

- [ ] **Step 3: Run** `bin/rspec spec/requests/deck_pages_spec.rb`. Expected: the three examples FAIL (items, `NoMethodError` for the route helpers).

- [ ] **Step 4: The code.**

`config/routes.rb`, inside `resources :proxies, only: %i[edit update destroy] do`:

```ruby
        resource :removal, only: :new, module: :proxies
        resource :replacement, only: %i[new create], module: :proxies # spec 070: Use my copy
        resource :copy, only: %i[new create], module: :proxies # spec 070: Add a new copy
```

`app/models/deck/page.rb`, in `Row` (after `total`):

```ruby
    # Whether the replacement items of a proxy row are offered: they need the printing's collectible's vocabulary (spec 070
    # decision 1), so a printing whose collectible the instance no longer registers has Change and Remove only.
    def replaceable? = Deck::Proxy.replaceable?(entry)
```

`app/helpers/decks_helper.rb`, replace `proxy_item_label`:

```ruby
  # A row menu item's words (spec 068 decision 5, spec 070 decision 1): "Use my copy", "Add a new copy", "Change proxy count",
  # "Remove proxy", with the finish named when the row has proxies of more than one finish: "Use my copy for Foil proxy",
  # "Add a new copy for Foil proxy", "Change Foil proxy count", "Remove Foil proxy".
  #
  # @param verb [String] "Use", "Add", "Change" or "Remove"
  # @param line [Deck::Page::Line]
  # @param row [Deck::Page::Row]
  # @return [String]
  def proxy_item_label(verb, line, row)
    finish = line.finish && row.lines.size > 1 ? "#{proxy_finish_label(row.entry, line.finish)} " : ""
    case verb
    when "Use" then finish.empty? ? "Use my copy" : "Use my copy for #{finish}proxy"
    when "Add" then finish.empty? ? "Add a new copy" : "Add a new copy for #{finish}proxy"
    when "Change" then "Change #{finish}proxy count"
    else "Remove #{finish}proxy"
    end
  end
```

`app/views/decks/_proxy_menu.html.erb`: replace the list body:

```erb
    <div class="c-menu__list">
      <% if row.replaceable? %>
        <% row.lines.each do |line| %>
          <%= link_to proxy_item_label("Use", line, row), new_deck_proxy_replacement_path(deck, line.id), class: "c-menu__item" %>
        <% end %>
        <% row.lines.each do |line| %>
          <%= link_to proxy_item_label("Add", line, row), new_deck_proxy_copy_path(deck, line.id), class: "c-menu__item" %>
        <% end %>
      <% end %>
      <% row.lines.each do |line| %>
        <%= link_to proxy_item_label("Change", line, row), edit_deck_proxy_path(deck, line.id), class: "c-menu__item" %>
      <% end %>
      <div class="c-menu__sep"></div>
      <% row.lines.each do |line| %>
        <%= link_to proxy_item_label("Remove", line, row), new_deck_proxy_removal_path(deck, line.id), class: "c-menu__item c-menu__item--danger" %>
      <% end %>
    </div>
```

- [ ] **Step 5: Run** `bin/rspec spec/requests/deck_pages_spec.rb spec/system/deck_page_spec.rb`. Expected: PASS (the page's statement count unchanged). `bin/rubocop -a` on the files.
- [ ] **Step 6: Commit**: `feat(decks): Use my copy and Add a new copy in a proxy row's menu (spec 070, #257)`.

### T7: Use my copy, the page

- [ ] **Step 1: The failing spec** `spec/requests/deck_proxy_replacements_spec.rb` (GET part):

```ruby
require "rails_helper"

# Spec 070 Stories 2 and 3: Use my copy, GET /decks/:id/proxies/:id/replacement/new and its POST.
RSpec.describe "Use my copy", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:binder) { create(:location, account:, name: "Blue binder") }
  let(:box) { create(:location, account:, name: "Red box") }

  def html = Nokogiri::HTML5(response.body)
  def printing(set: "2x2", number: "117", language: "en", finishes: %w[foil nonfoil]) = create(:mtg_printing, finishes:, entry: create(:catalog_entry, name: "Lightning Bolt", identity: bolt, number:, language:, set: Catalog::Set.find_by(code: set) || create(:catalog_set, code: set))).entry
  def lot_in(location, entry, quantity = 1, **attrs) = create(:lot, account:, entry:, location:, quantity:, **attrs)
  def proxy_of(entry, quantity: 2, finish: "foil") = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish:, quantity:)

  let(:entry) { printing }
  let!(:proxy) { proxy_of(entry) }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-2.1 to AC-2.6)" do
      it "is a detail page that names the card and the proxy row, with a field of 0 per free lot", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Use my copy of Lightning Bolt · Collector")
        expect(html.at_css("header.c-appbar--detail a[aria-label='Back'][href='#{deck_path(deck)}']")).to be_present
        expect(html.at_css("main")["class"].split).to include("c-decks")
        expect(html.at_css("h1").text).to eq("Use my copy of Lightning Bolt")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Replaces 2 proxies in Izzet Tempo › Main · 2X2 · 117, Foil")
        field = html.at_css("input[name='lots[#{lot.id}]']")
        expect(field.attributes.slice("type", "min", "max", "value").transform_values(&:value)).to eq("type" => "number", "min" => "0", "max" => "2", "value" => "0")
        expect(html.at_css("input[name='shown[#{lot.id}]']")["value"]).to eq("2")
      end

      it "names each field by its lot's text: printing, finish, condition, price, place and the free count", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
        unplaced = lot_in(nil, printing(set: "mm3", number: "122", language: "de"), 1)

        get new_deck_proxy_replacement_path(deck, proxy)

        label = html.at_css("label[for='lot_#{lot.id}']").text.squish
        expect(label).to eq("2X2 · 117 Foil, Near mint, paid $1.25, Blue binder, ×2 free")
        expect(html.at_css("label[for='lot_#{unplaced.id}']").text.squish).to eq("MM3 · 122 · DE, No location, ×1 free")
        expect(html.at_css("label.c-input input[id='lot_#{lot.id}']")).to be_present
      end

      it "groups This printing (the proxy's printing and finish) before Other printings in the card page's order, leaving an empty group out", :aggregate_failures do
        same = lot_in(binder, entry, 1, finish: "foil")
        other_finish = lot_in(box, entry, 1, finish: "nonfoil")
        newer = lot_in(box, printing(set: "mm3", number: "122"), 1, finish: "foil")
        newer.entry.update_columns(released_on: Date.new(2030, 1, 1)) # `newest_first` sorts by the entry's own release date
        retired = lot_in(binder, create(:mtg_printing, entry: create(:catalog_entry, :retired, name: "Lightning Bolt", identity: bolt)).entry, 1)

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.css(".c-pick__group").map(&:text)).to eq([ "This printing", "Other printings" ])
        ids = html.css(".c-pick__lot input[type=number]").map { it["id"] }
        expect(ids.first).to eq("lot_#{same.id}")
        expect(ids.drop(1).first).to eq("lot_#{newer.id}") # newest printing first, whatever the finish
        expect(ids.drop(1)).to match_array([ "lot_#{newer.id}", "lot_#{other_finish.id}", "lot_#{retired.id}" ])

        same.destroy!
        other_finish.destroy!
        get new_deck_proxy_replacement_path(deck, proxy)
        expect(html.css(".c-pick__group").map(&:text)).to eq([ "Other printings" ])
      end

      it "lists only free lots of the card: no lot in a zone, in Considering, of another card or of another account", :aggregate_failures do
        free = lot_in(binder, entry, 1, finish: "foil")
        lot_in(deck.zone("main"), entry, 1, finish: "foil")
        lot_in(deck.zone("considering"), entry, 1, finish: "foil")
        lot_in(binder, create(:mtg_printing, entry: create(:catalog_entry, name: "Other card")).entry, 1)
        stranger = create(:user).account
        create(:lot, account: stranger, entry:, location: create(:location, account: stranger), quantity: 1, finish: "foil")
        other_deck = create(:deck, account:, name: "Other deck")
        lot_in(other_deck.zone("main"), entry, 1, finish: "foil") # a zone of another deck of the account

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.css(".c-pick__lot input[type=number]").map { it["id"] }).to eq([ "lot_#{free.id}" ])
      end

      it "reads a place with the zone's name as the place's name and the proxy line as Deck › Zone (AC-2.5)", :aggregate_failures do
        lot = lot_in(create(:location, account:, name: "Main"), entry, 1, finish: "foil")

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.at_css("label[for='lot_#{lot.id}']").text.squish).to eq("2X2 · 117 Foil, Main, ×1 free")
        expect(html.at_css(".c-pagehead__stats").text.squish).to start_with("Replaces 2 proxies in Izzet Tempo › Main")
      end

      it "says '1 proxy' and keeps a 60-character place name whole", :aggregate_failures do
        one = proxy_of(printing(set: "one"), quantity: 1)
        lot_in(create(:location, account:, name: "P" * 60), one.entry, 1, finish: "foil")

        get new_deck_proxy_replacement_path(deck, one)

        expect(html.at_css(".c-pagehead__stats").text.squish).to start_with("Replaces 1 proxy in Izzet Tempo › Main")
        expect(html.at_css(".c-pick__label").text).to include("P" * 60)
      end

      it "shows the empty sentence, a Back button and no form when no copy is free (AC-2.6)", :aggregate_failures do
        lot_in(deck.zone("main"), entry, 1, finish: "foil") # owned, but in the deck: the fixture could produce a free lot

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(html.at_css(".c-empty").text.squish).to eq("You have no free copy of Lightning Bolt to use.")
        expect(html.at_css("main a.c-btn[href='#{deck_path(deck)}']").text).to eq("Back to Izzet Tempo")
        expect(html.css("form")).to be_empty
      end

      it "runs the same number of statements for 1 lot and for 200 lots of 20 printings in 2 places (AC-2.7)", :aggregate_failures do
        lot_in(binder, entry, 1, finish: "foil")
        get new_deck_proxy_replacement_path(deck, proxy) # warm what the counts would otherwise differ by
        few = count_queries { get new_deck_proxy_replacement_path(deck, proxy) }

        20.times do |n|
          other = printing(set: "s#{n}", number: "#{n + 200}")
          10.times { |m| lot_in(m.even? ? binder : box, other, 1 + m, finish: "foil", price_paid_cents: m) } # 10 identities a printing
        end
        many = count_queries { get new_deck_proxy_replacement_path(deck, proxy) }

        expect(account.lots.free.count).to eq(201)
        expect(many).to eq(few)
      end
    end

    describe "who can open it (AC-2.8, AC-2.9)" do
      it "answers 404 for a proxy whose printing's collectible the instance no longer registers", :aggregate_failures do
        entry.update_columns(collectible_type: "gone")

        get new_deck_proxy_replacement_path(deck, proxy)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in" do
    get new_deck_proxy_replacement_path(deck, proxy)

    expect(response).to redirect_to(new_session_path)
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/requests/deck_proxy_replacements_spec.rb`. Expected: FAIL, `ActionController::RoutingError` / uninitialized controller.

- [ ] **Step 3: The controller** `app/controllers/decks/proxies/replacements_controller.rb`:

```ruby
# Spec 070 Stories 2 and 3: Use my copy, the page that replaces a proxy by free copies the collector owns. The deck is found by
# its location id through the account and the proxy among the deck's; nothing in a request names an account, a zone or a
# location (AC-3.13). A proxy whose printing's collectible the instance no longer registers is 404: the page needs its
# vocabulary (decision 1).
# @see file:collection-and-lots.md
class Decks::Proxies::ReplacementsController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }
  before_action :require_replaceable

  # The free copies of the proxy's card, each with a number field.
  def new
    @replacement = Deck::Proxy::UseCopies.new(proxy: @proxy)
  end

  # Replaces the proxy by the copies chosen (one transaction), or shows the page again with the sentences (422).
  def create
    @replacement = Deck::Proxy::UseCopies.new(proxy: @proxy, typed: submitted[:lots], shown: submitted[:shown])
    if @replacement.save
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Replaced #{helpers.pluralize(helpers.number_with_delimiter(@replacement.used), "proxy", "proxies")} of #{helpers.proxy_name(@proxy)} " \
                "in #{helpers.proxy_zone_label(@deck, @proxy.zone)} with copies you own."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_replaceable
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Deck::Proxy.replaceable?(@proxy.entry)
    end

    # The two hashes the page posts: lot id => text. Any other parameter is never read.
    def submitted = params.permit(lots: {}, shown: {})
end
```

Note: the proxy's `used` is the quantity; `proxy_name(@proxy)` reads the proxy after `lower_by!` (possibly destroyed): it reads the entry, which stays.

- [ ] **Step 4: The helpers** in `app/helpers/decks_helper.rb`:

```ruby
  # "Replaces 2 proxies in Izzet Tempo › Main · 2X2 · 117, Foil": the muted line of both replacement pages (spec 070 AC-2.1,
  # AC-4.1). The printing is `deck_set_line`'s (with ` · LANG` for a language other than English), the finish the vocabulary's
  # label, only when the proxy has one.
  #
  # @param deck [Deck]
  # @param proxy [Deck::Proxy] with its zone, entry and set loaded
  # @return [ActiveSupport::SafeBuffer]
  def replaces_line(deck, proxy)
    printing = safe_join([ tag.span(deck_set_line(proxy.entry), class: "is-data"), (", #{proxy.finish_label}" if proxy.finish) ])
    safe_join([ "Replaces #{pluralize(number_with_delimiter(proxy.quantity), "proxy", "proxies")} in #{proxy_zone_label(deck, proxy.zone)} · ", printing ])
  end

  # A free lot's row text on Use my copy (spec 070 decision 4): the printing, the finish and the condition as the vocabulary
  # labels them (each only when the lot has one), "paid $1.25" in the account's currency when it has a price, the place ("No
  # location" when unplaced) and "×N free". It names the row's number field.
  #
  # @param lot [Lot] with its entry and location loaded
  # @return [ActiveSupport::SafeBuffer]
  def lot_pick_label(lot)
    vocabulary = lot.vocabulary
    finish = vocabulary.finish_label(lot.finish) if lot.finish
    condition = vocabulary.conditions.fetch(lot.condition) { [ lot.condition.humanize ] }.first if lot.condition
    price = "paid #{number_to_currency(lot.price_paid, unit: Current.account.currency_unit.symbol)}" if lot.price_paid
    rest = [ condition, price, lot.place_label || "No location", "×#{number_with_delimiter(lot.quantity)} free" ].compact.join(", ")
    safe_join([ tag.span(deck_set_line(lot.entry), class: "is-data"), (" #{finish}" if finish), ", ", rest ])
  end
```

- [ ] **Step 5: The view** `app/views/decks/proxies/replacements/new.html.erb`:

```erb
<% content_for :title, "Use my copy of #{@proxy.entry.name} · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: deck_path(@deck) %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Use my copy of <%= @proxy.entry.name %></h1>
      <p class="c-pagehead__stats"><%= replaces_line(@deck, @proxy) %></p>
    </div>
  </div>
  <% if @replacement.groups.empty? %>
    <%= render "shared/field_errors", messages: @replacement.fieldset_errors, id: "replacement-error" %>
    <p class="c-empty">You have no free copy of <%= @proxy.entry.name %> to use.</p>
    <div class="c-form__actions">
      <%= link_to "Back to #{@deck.name}", deck_path(@deck), class: "c-btn c-btn--secondary" %>
    </div>
  <% else %>
    <% fieldset_errors = @replacement.fieldset_errors %>
    <%= form_with url: deck_proxy_replacement_path(@deck, @proxy), method: :post, class: "c-form" do |form| %>
      <%= tag.fieldset class: "c-choices c-pick", "aria-describedby": field_error_describedby("replacement-error", fieldset_errors) do %>
        <legend class="c-field__label">Which copies</legend>
        <% @replacement.groups.each do |name, rows| %>
          <p class="c-pick__group"><%= name %></p>
          <% rows.each do |row| %>
            <div class="c-pick__lot<%= " c-field--invalid" if row.errors.any? %>">
              <label class="c-pick__label" for="lot_<%= row.lot.id %>"><%= lot_pick_label(row.lot) %></label>
              <label class="c-input">
                <%= number_field_tag "lots[#{row.lot.id}]", row.typed, id: "lot_#{row.lot.id}", min: 0, max: row.lot.quantity, step: 1, inputmode: "numeric",
                      "aria-describedby": field_error_describedby("lot_#{row.lot.id}-error", row.errors) %>
              </label>
              <%= hidden_field_tag "shown[#{row.lot.id}]", row.shown, id: nil %>
              <%= render "shared/field_errors", messages: row.errors, id: "lot_#{row.lot.id}-error" %>
            </div>
          <% end %>
        <% end %>
        <%= render "shared/field_errors", messages: fieldset_errors, id: "replacement-error" %>
      <% end %>
      <div class="c-form__actions">
        <%= form.submit "Use these copies", class: "c-btn c-btn--primary" %>
        <%= link_to "Cancel", deck_path(@deck), class: "c-btn c-btn--secondary" %>
      </div>
    <% end %>
  <% end %>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

- [ ] **Step 6: Run** `bin/rspec spec/requests/deck_proxy_replacements_spec.rb`. Expected: PASS for the GET examples (the POST ones come in T8). If the label text differs by whitespace/case, fix the helper (`squish` is in the spec), not the spec's expectation.
- [ ] **Step 7: Commit**: `feat(decks): the Use my copy page, the free lots of a proxy's card (spec 070, #257)`.

### T8: Use these copies

- [ ] **Step 1: The failing examples**, added to the same spec file inside `context "when signed in"`:

```ruby
    describe "Use these copies (AC-3.1 to AC-3.13)" do
      def post_use(typed, shown = nil, to: proxy)
        shown ||= typed.keys.to_h { |id| [ id, account.lots.find(id).quantity.to_s ] }
        post deck_proxy_replacement_path(deck, to), params: { lots: typed, shown: }
      end

      it "moves the chosen copies into the zone, lowers the proxy and goes back to the deck page with the notice", :aggregate_failures do
        lot = lot_in(binder, entry, 3, finish: "foil", condition: "near_mint")
        original = proxy.updated_at

        post_use({ lot.id.to_s => "1" })

        expect(response).to redirect_to(deck_path(deck))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Replaced 1 proxy of Lightning Bolt (2X2 · 117, Foil) in Izzet Tempo › Main with copies you own.")
        expect(proxy.reload).to have_attributes(quantity: 1, id: proxy.id)
        expect(proxy.updated_at).to be > original
        expect(lot.reload).to have_attributes(quantity: 2, location: binder)
        expect(account.lots.find_by(location: deck.zone("main"))).to have_attributes(quantity: 1, finish: "foil", condition: "near_mint")
      end

      it "removes the proxy when the copies used equal its count, and the deck page then shows the owned row alone", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")

        post_use({ lot.id.to_s => "2" })
        follow_redirect!

        expect(Deck::Proxy.exists?(proxy.id)).to be(false)
        main = html.css("section.c-zone").find { it.at_css("h2").text == "Main" }
        expect(main.css(".c-proxy")).to be_empty
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 2 owned · 0 proxy")
      end

      it "uses copies of another printing: it enters as a row of its own and the card's Total on the deck page is unchanged (AC-3.3)", :aggregate_failures do
        other = lot_in(box, printing(set: "mm3", number: "122"), 1, finish: "foil")

        post_use({ other.id.to_s => "1" })
        follow_redirect!

        expect(proxy.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: deck.zone("main")).catalog_entry_id).to eq(other.catalog_entry_id)
        main = html.css("section.c-zone").find { it.at_css("h2").text == "Main" }
        rows = main.css("tbody tr:not(.c-zone__group)")
        expect(rows.size).to eq(2) # the proxy's printing keeps its row; the copy's printing has one of its own
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 1 owned · 1 proxy") # 2 cards before and after
      end

      it "judges a proxy lowered since the page was shown against its count now (AC-3.10)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")
        proxy.update!(quantity: 1) # lowered in another tab

        post_use({ lot.id.to_s => "2" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 1.")
        expect(lot.reload.location).to eq(binder)
      end

      it "agrees across the deck page, the card page's Your copies, the collection and the Decks page after a replacement (AC-3.12)", :aggregate_failures do
        lot = lot_in(binder, entry, 3, finish: "foil")

        post_use({ lot.id.to_s => "2" })

        get deck_path(deck)
        expect(html.at_css(".c-item__type").text).to eq("Modern · 2 cards · 2 owned · 0 proxy")
        get catalog_entry_path(entry)
        expect(html.text).to include("Izzet Tempo › Main")
        get collection_path(view: "table")
        expect(html.text).to include("Izzet Tempo › Main").and include("Blue binder")
        get decks_path
        row = html.at_css("tbody tr")
        expect(row.text.squish).to include("2 owned") # the phone line; Owned was 0 before the replacement
        expect(row.at_css(".c-proxy")).to be_nil
      end

      it "shows the changed-lots sentence above the empty state when every chosen lot stopped being free", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")
        lot.update!(location: deck.zone("sideboard")) # taken into a zone since the page was shown

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "2" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
        expect(html.at_css(".c-empty").text.squish).to eq("You have no free copy of Lightning Bolt to use.")
      end

      it "writes nothing and re-renders with every entry kept for a number outside the lot's copies (AC-3.5)", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")

        post_use({ lot.id.to_s => "3" })

        expect(response).to have_http_status(:unprocessable_content)
        error = html.at_css("#lot_#{lot.id}-error")
        expect(error.text).to eq("Enter a number from 0 to 2.")
        expect(html.at_css("input#lot_#{lot.id}")["aria-describedby"]).to eq("lot_#{lot.id}-error")
        expect(html.at_css("input#lot_#{lot.id}")["value"]).to eq("3")
        expect([ lot.reload.location, proxy.reload.quantity ]).to eq([ binder, 2 ])
      end

      it "refuses a total of 0 or over the proxy's count under the fieldset (AC-3.6)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")

        post_use({ lot.id.to_s => "" })
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 2.")
        expect(html.at_css("fieldset")["aria-describedby"]).to eq("replacement-error")

        post_use({ lot.id.to_s => "3" })
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Enter a number from 1 to 2.")
        expect(account.lots.where(location: deck.zone("main"))).to be_empty
      end

      it "refuses a lot that changed since the page was shown, and the refused page works as the next submit (AC-3.9)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "9" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
        expect(html.at_css("input[name='shown[#{lot.id}]']")["value"]).to eq("5")
        expect(html.at_css("input#lot_#{lot.id}")["value"]).to eq("1")
        expect(proxy.reload.quantity).to eq(2)

        post_use({ lot.id.to_s => "1" }, { lot.id.to_s => "5" }) # what the refused page posts again
        expect(response).to redirect_to(deck_path(deck))
        expect(proxy.reload.quantity).to eq(1)
      end

      it "moves once when the same form is submitted twice: the second is refused as changed (AC-3.11)", :aggregate_failures do
        lot = lot_in(binder, entry, 5, finish: "foil")
        params = { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "5" } }

        post deck_proxy_replacement_path(deck, proxy), params: params
        post deck_proxy_replacement_path(deck, proxy), params: params

        expect(response).to have_http_status(:unprocessable_content)
        expect(proxy.reload.quantity).to eq(1)
        expect(lot.reload.quantity).to eq(4)
        expect(account.lots.find_by(location: deck.zone("main")).quantity).to eq(1)
      end

      it "writes nothing when a later lot passes the cap, the earlier lot included, and names the lot (AC-3.7, AC-3.8)", :aggregate_failures do
        lot_in(deck.zone("main"), entry, 9_999, finish: "foil")
        first = lot_in(binder, entry, 1, finish: "nonfoil")
        second = lot_in(box, entry, 1, finish: "foil")

        post_use({ first.id.to_s => "1", second.id.to_s => "1" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_#{second.id}-error").text).to eq("One lot can hold at most 9,999 copies.")
        expect([ first.reload.location, second.reload.location, proxy.reload.quantity ]).to eq([ binder, box, 2 ])
      end

      it "ignores an account id, a zone id and a location id in the request (AC-3.13)", :aggregate_failures do
        lot = lot_in(binder, entry, 1, finish: "foil")

        post deck_proxy_replacement_path(deck, proxy), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "1" },
                                                                   account_id: create(:user).account.id, zone_id: deck.zone("sideboard").id, location_id: box.id }

        expect(response).to redirect_to(deck_path(deck))
        expect(lot.reload.location).to eq(deck.zone("main"))
      end

      it "answers 404 for a proxy removed meanwhile and writes nothing (AC-3.10)", :aggregate_failures do
        lot = lot_in(binder, entry, 1, finish: "foil")
        stale = proxy.id
        proxy.destroy!

        post deck_proxy_replacement_path(deck, stale), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "1" } }

        expect(response).to have_http_status(:not_found)
        expect(lot.reload.location).to eq(binder)
      end

      it "leaves the other proxies, other decks and the other account's lots as they were (AC-5.2)", :aggregate_failures do
        sibling = proxy_of(printing(set: "sib"), quantity: 2)
        stranger = create(:user).account
        theirs = create(:lot, account: stranger, entry:, location: create(:location, account: stranger), quantity: 4, finish: "foil")
        lot = lot_in(binder, entry, 1, finish: "foil")

        post_use({ lot.id.to_s => "1" })

        expect([ sibling.reload.quantity, theirs.reload.quantity ]).to eq([ 2, 4 ])
      end
    end
```

- [ ] **Step 2: Run** `bin/rspec spec/requests/deck_proxy_replacements_spec.rb`. Expected: the new examples PASS already except any that exercise a gap; the controller and the object exist. If any FAIL, it is a real gap in T4 or T7: fix the code (test-first means the failing example is the evidence; note which failed).

Note for the implementer: if every example passes at once, that is not "no red": the failing run of Step 2 for T7 was the red for the page, and T4's model spec was the red for the logic. In that case record that in the commit body and go on. If an example cannot fail (the lesson of spec 066), change one input to the value that should make the thing appear and check it fails: for "ignores an account id", post with a `lots` for a lot in the zone of sideboard and confirm the example would see it.

- [ ] **Step 3: Run the neighbours** `bin/rspec spec/requests/deck_proxies_spec.rb spec/requests/deck_pages_spec.rb spec/models/lot_proxy_isolation_spec.rb`. PASS. (`lot_proxy_isolation_spec` asserts no lot path changes a proxy: it must still pass, because it exercises the other paths.)
- [ ] **Step 4: Commit**: `test(decks): Use these copies moves the copies and lowers the proxy, once (spec 070, #257)`.

---

## Phase 3: Add a new copy

**Implements:** FR-2, decisions 5, 10, 11 | **Satisfies:** AC-4.1 to AC-4.9
**Files:** `app/views/lots/_form.html.erb`, `app/controllers/decks/proxies/copies_controller.rb`, `app/views/decks/proxies/copies/new.html.erb`, `spec/requests/deck_proxy_copies_spec.rb`
**Interfaces:** `lots/_form` gains the optional locals `fixed_place:`, `cancel_path:`, `quantity_max:`, `shown_quantity:`; produces `Decks::Proxies::CopiesController`.

### T9: The form's options and the page

- [ ] **Step 1: The failing spec** `spec/requests/deck_proxy_copies_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 Story 4: Add a new copy, GET /decks/:id/proxies/:id/copy/new and its POST.
RSpec.describe "Add a new copy", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil], entry: create(:catalog_entry, name: "Lightning Bolt", number: "138", set: create(:catalog_set, code: "mh2"))).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 3) }

  def html = Nokogiri::HTML5(response.body)
  def post_copy(lot = {}, shown: "3", to: proxy) = post(deck_proxy_copy_path(deck, to), params: { lot: { quantity: "1", finish: "foil" }.merge(lot), shown_quantity: shown })

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the page (AC-4.1)" do
      it "is the Add a copy form for the proxy's printing, with its finish chosen, the zone read-only and the count as the maximum", :aggregate_failures do
        get new_deck_proxy_copy_path(deck, proxy)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Add a new copy of Lightning Bolt · Collector")
        expect(html.at_css("header.c-appbar--detail a[aria-label='Back'][href='#{deck_path(deck)}']")).to be_present
        expect(html.at_css("main")["class"].split).to include("c-decks")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Replaces 3 proxies in Izzet Tempo › Main · MH2 · 138, Foil")
        quantity = html.at_css("input[name='lot[quantity]']")
        expect(quantity.attributes.slice("value", "min", "max").transform_values(&:value)).to eq("value" => "1", "min" => "1", "max" => "3")
        expect(html.at_css("select[name='lot[finish]'] option[selected]")["value"]).to eq("foil")
        expect(html.css("select[name='lot[condition]'], input[name='lot[price_paid]']").size).to eq(2)
        expect(html.at_css("select[name='lot[location_id]']")).to be_nil
        expect(html.at_css("p.c-field__label").text).to eq("Location")
        expect(html.at_css("p.c-field__label + p.c-field__value").text).to eq("Izzet Tempo › Main")
        expect(html.text).not_to include("Add a location")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("3")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Add copy")
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).to eq(deck_path(deck))
      end

      it "has no Finish select for a printing that lists none" do
        bare = create(:mtg_printing, finishes: []).entry
        bare_proxy = create(:deck_proxy, zone: deck.zone("main"), account:, entry: bare, finish: nil, quantity: 1)

        get new_deck_proxy_copy_path(deck, bare_proxy)

        expect(html.at_css("select[name='lot[finish]']")).to be_nil
      end

      it "answers 404 for a proxy whose printing's collectible the instance no longer registers" do
        entry.update_columns(collectible_type: "gone")

        get new_deck_proxy_copy_path(deck, proxy)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "the card page's own form and Edit copy (AC-4.9)" do
      it "are unchanged: a Quantity maximum of 9,999, a location select and their own Cancel", :aggregate_failures do
        place = create(:location, account:, name: "Blue binder")
        get new_catalog_entry_lot_path(entry.external_key)
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("9999")
        expect(html.at_css("select[name='lot[location_id]']")).to be_present
        expect(html.at_css("input[name=shown_quantity]")).to be_nil
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).to eq(catalog_entry_path(entry))

        lot = create(:lot, account:, entry:, location: place)
        get edit_lot_path(lot)
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("9999")
        expect(html.at_css("select[name='lot[location_id]']")).to be_present
        expect(html.css("a.c-btn").find { it.text == "Cancel" }["href"]).not_to eq(deck_path(deck))
      end
    end

    describe "adding the copy (AC-4.2 to AC-4.8)" do
      it "adds the lot to the proxy's zone, lowers the proxy and goes back to the deck page", :aggregate_failures do
        post_copy({ quantity: "2", condition: "near_mint", price_paid: "1.25" })

        expect(response).to redirect_to(deck_path(deck))
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies.")
        expect(proxy.reload.quantity).to eq(1)
        expect(account.lots.find_by(location: deck.zone("main"))).to have_attributes(entry:, quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
      end

      it "says '3 proxies' and removes the proxy when the quantity is its whole count, and '1 proxy' for one", :aggregate_failures do
        post_copy({ quantity: "3" })
        expect(flash[:notice]).to end_with("replacing 3 proxies.")
        expect(Deck::Proxy.exists?(proxy.id)).to be(false)

        one = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "nonfoil", quantity: 1)
        post_copy({ quantity: "1", finish: "nonfoil" }, shown: "1", to: one)
        expect(flash[:notice]).to end_with("replacing 1 proxy.")
      end

      it "lowers the proxy in the path whatever the copy's finish (AC-4.5)", :aggregate_failures do
        post_copy({ finish: "nonfoil" })

        expect(account.lots.find_by(location: deck.zone("main")).finish).to eq("nonfoil")
        expect(proxy.reload.quantity).to eq(2)
      end

      it "refuses a quantity over the proxy's count, keeping what was typed (AC-4.3)", :aggregate_failures do
        post_copy({ quantity: "4", price_paid: "2.5" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("Enter a number from 1 to 3.")
        expect(html.at_css("input[name='lot[quantity]']")["value"]).to eq("4")
        expect(html.at_css("input[name='lot[price_paid]']")["value"]).to eq("2.5")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("3")
        expect([ proxy.reload.quantity, account.lots.count ]).to eq([ 3, 0 ])
      end

      it "gives Add a copy's own sentence to a quantity that isn't a whole number from 1 to 9,999, and to a finish or price it refuses", :aggregate_failures do
        post_copy({ quantity: "10000" })
        expect(html.at_css("#lot_quantity-error").text).to eq("Quantity must be a whole number from 1 to 9,999")

        post_copy({ finish: "etched" })
        expect(html.at_css("#lot_finish-error").text).to include("isn't available for this printing")

        post_copy({ price_paid: "-1" })
        expect(response).to have_http_status(:unprocessable_content)
        expect(account.lots.count).to eq(0)
      end

      it "refuses a proxy that is not the count the form showed, writes the count now, and the next submit works (AC-4.6, AC-4.6a)", :aggregate_failures do
        post_copy({ quantity: "1" }, shown: "3")
        post_copy({ quantity: "1" }, shown: "3") # the second submit of one form

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to eq("This proxy changed. Check the quantity and try again.")
        expect(html.at_css("input[name=shown_quantity]")["value"]).to eq("2")
        expect(html.at_css("input[name='lot[quantity]']")["max"]).to eq("2")
        expect([ proxy.reload.quantity, account.lots.sum(:quantity) ]).to eq([ 2, 1 ])

        post_copy({ quantity: "1" }, shown: "2")
        expect(response).to redirect_to(deck_path(deck))
      end

      it "refuses a merge past 9,999 and changes nothing (AC-4.4)", :aggregate_failures do
        create(:lot, account:, entry:, location: deck.zone("main"), finish: "foil", quantity: 9_999)

        post_copy

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#lot_quantity-error").text).to include("9,999")
        expect(proxy.reload.quantity).to eq(3)
      end

      it "ignores an account id, a location id, a zone id and an entry key (AC-4.7)", :aggregate_failures do
        other_entry = create(:mtg_printing).entry
        post deck_proxy_copy_path(deck, proxy), params: { lot: { quantity: "1", finish: "foil", location_id: create(:location, account:).id, entry: other_entry.external_key },
                                                          shown_quantity: "3", account_id: create(:user).account.id, zone_id: deck.zone("sideboard").id }

        lot = account.lots.sole
        expect([ lot.location, lot.entry ]).to eq([ deck.zone("main"), entry ])
      end

      it "answers 404 for a proxy removed meanwhile and writes nothing", :aggregate_failures do
        stale = proxy.id
        proxy.destroy!

        post deck_proxy_copy_path(deck, stale), params: { lot: { quantity: "1" }, shown_quantity: "3" }

        expect(response).to have_http_status(:not_found)
        expect(account.lots.count).to eq(0)
      end
    end
  end

  it "sends a visitor who isn't signed in to sign in" do
    get new_deck_proxy_copy_path(deck, proxy)

    expect(response).to redirect_to(new_session_path)
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/requests/deck_proxy_copies_spec.rb`. Expected: FAIL (`RoutingError`: no controller).

- [ ] **Step 3: The partial** `app/views/lots/_form.html.erb`. Change the locals line and four places:

```erb
<%# locals: (form_model:, url:, method:, submit:, choices:, fixed_place: nil, cancel_path: nil, quantity_max: Lot::MAX_QUANTITY, shown_quantity: nil) %>
```
Quantity field: `max: quantity_max`. Location block:

```erb
  <% if fixed_place %>
    <div class="c-field">
      <p class="c-field__label">Location</p>
      <p class="c-field__value"><%= fixed_place %></p>
    </div>
  <% elsif choices.any? %>
    <div class="c-field">
      <%= form.label :location_id, "Location", class: "c-field__label" %>
      <%= form.select :location_id, location_options(choices, selected: form_model.location_id.to_s, leading: [ [ "No location", "" ] ]) %>
    </div>
  <% else %>
    <p class="c-field__hint"><%= link_to "Add a location", locations_path %> to keep copies in one.</p>
  <% end %>
  <%= hidden_field_tag :shown_quantity, shown_quantity, id: nil unless shown_quantity.nil? %>
```
and the Cancel link: `<%= link_to "Cancel", cancel_path || lot_return_path(entry), class: "c-btn c-btn--secondary" %>`.

- [ ] **Step 3a: The wrap rule for the read-only Location** (a deck name of 60 characters with no space plus " › Main" must not scroll the page sideways at 360px; no existing rule covers a bare `p` in a form). In `app/assets/stylesheets/collector/additions.css`, under its own heading comment, after the "Deck pages' selects (spec 068 AC-9.1)" block:

```css
/* ---------- Add a new copy's read-only Location (spec 070 AC-6.1) ---------- */
/* The zone's label ("Deck › Zone") names a deck of up to 60 characters with no space, so the read-only line breaks inside a
   word like the page head's stats line instead of widening the form. It is the value under a `c-field__label` paragraph. */
.c-decks .c-field__value { margin:0; overflow-wrap:anywhere; }
```

  Document the class in `AddProxy.md` (T14); The widths and the refused pages of T12 are what check the rule.

- [ ] **Step 4: The controller** `app/controllers/decks/proxies/copies_controller.rb`:

```ruby
# Spec 070 Story 4: Add a new copy, the Add a copy form for a proxy's printing whose copy lands in the proxy's zone while the
# proxy is lowered by the same quantity. The printing and the zone are the proxy's: no entry, location, zone or account is read
# from the request (AC-4.7). A proxy whose printing's collectible the instance no longer registers is 404 (decision 1).
# @see file:collection-and-lots.md
class Decks::Proxies::CopiesController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }
  before_action :require_replaceable

  # The form with the proxy's finish chosen, the zone read-only and Quantity from 1 to the proxy's count.
  def new
    @form = Lot::Form.new(entry: @proxy.entry, finish: @proxy.finish)
    @shown_quantity = @proxy.quantity
  end

  # Adds the copy to the zone and lowers the proxy (one transaction), or shows the form again with the sentences (422).
  def create
    @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @proxy.entry)
    copy = Deck::Proxy::AddCopy.new(proxy: @proxy, form: @form, shown_quantity: params[:shown_quantity])
    if copy.save
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Added #{helpers.number_with_delimiter(copy.added)} × #{@proxy.entry.name} (#{helpers.set_number(@proxy.entry)}) to " \
                "#{helpers.proxy_zone_label(@deck, @proxy.zone)}, replacing #{helpers.pluralize(helpers.number_with_delimiter(copy.added), "proxy", "proxies")}."
    else
      @shown_quantity = @proxy.quantity
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_replaceable
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Deck::Proxy.replaceable?(@proxy.entry)
    end

    # No location: the zone is the proxy's.
    def lot_params = params.expect(lot: %i[quantity finish condition price_paid])
end
```

- [ ] **Step 5: The view** `app/views/decks/proxies/copies/new.html.erb`:

```erb
<% content_for :title, "Add a new copy of #{@proxy.entry.name} · Collector" %>
<%= render "layouts/appbar", section: :decks, detail: true, back_path: deck_path(@deck) %>
<main class="c-main c-page c-decks">
  <div class="c-pagehead">
    <div>
      <h1 class="c-pagehead__title">Add a new copy of <%= @proxy.entry.name %></h1>
      <p class="c-pagehead__stats"><%= replaces_line(@deck, @proxy) %></p>
    </div>
  </div>
  <%= render "lots/form", form_model: @form, url: deck_proxy_copy_path(@deck, @proxy), method: :post, submit: "Add copy", choices: nil,
        fixed_place: proxy_zone_label(@deck, @proxy.zone), cancel_path: deck_path(@deck), quantity_max: @proxy.quantity, shown_quantity: @shown_quantity %>
</main>
<%= render "layouts/tabbar", section: :decks %>
```

- [ ] **Step 6: Run** `bin/rspec spec/requests/deck_proxy_copies_spec.rb spec/requests/lots_spec.rb spec/requests/lot_moves_spec.rb spec/design_system_files_spec.rb`. Expected: PASS, the card page's form and Edit copy unchanged. `bin/rubocop -a`.
- [ ] **Step 7: Commit**: `feat(decks): Add a new copy, the Add a copy form for a proxy's printing and zone (spec 070, #257)`.

### T10: Tenancy and the other 404s

- [ ] **Step 1: The failing spec** `spec/requests/deck_proxy_replacement_tenancy_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 AC-2.8, AC-4.8, AC-3.9: another account's anything is 404 on both pages and both verbs, and another account's lot in
# the form is no longer free.
RSpec.describe "Replacing a proxy: tenancy", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }
  let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2) }
  let(:other) { create(:user).account }
  let(:rival) { "Rival #{SecureRandom.hex(4)}" } # built at run time: the test 404 page prints the spec's source
  let(:other_deck) { create(:deck, account: other, name: rival) }
  let!(:other_proxy) { create(:deck_proxy, zone: other_deck.zone("main"), account: other, entry:, finish: "foil", quantity: 2) }
  let(:binder) { create(:location, account:, name: "Blue binder") }
  let!(:sibling_proxy) { create(:deck_proxy, zone: create(:deck, account:, name: "Sibling deck").zone("main"), account:, entry:, finish: "foil", quantity: 2) }

  before { sign_in_as(user) }

  [
    [ "another account's deck and proxy", ->(t) { [ t.other_deck, t.other_proxy ] } ],
    [ "this deck with another account's proxy", ->(t) { [ t.deck, t.other_proxy ] } ],
    [ "this deck with a proxy of another deck of the account", ->(t) { [ t.deck, t.sibling_proxy ] } ],
    [ "another account's deck with this proxy", ->(t) { [ t.other_deck, t.proxy ] } ],
    [ "a place's id as the deck", ->(t) { [ t.binder, t.proxy ] } ],
    [ "a zone's id as the deck", ->(t) { [ t.deck.zone("main"), t.proxy ] } ],
    [ "an id that isn't digits only as the proxy", ->(t) { [ t.deck, "12abc" ] } ]
  ].each do |name, pick|
    it "answers 404 for #{name} on both pages and both verbs, and writes nothing", :aggregate_failures do
      deck_arg, proxy_arg = pick.call(self)
      lot = create(:lot, account:, entry:, location: binder, quantity: 2, finish: "foil")

      get new_deck_proxy_replacement_path(deck_arg, proxy_arg)
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(rival)
      post deck_proxy_replacement_path(deck_arg, proxy_arg), params: { lots: { lot.id.to_s => "1" }, shown: { lot.id.to_s => "2" } }
      expect(response).to have_http_status(:not_found)
      get new_deck_proxy_copy_path(deck_arg, proxy_arg)
      expect(response).to have_http_status(:not_found)
      post deck_proxy_copy_path(deck_arg, proxy_arg), params: { lot: { quantity: "1", finish: "foil" }, shown_quantity: "2" }
      expect(response).to have_http_status(:not_found)

      expect([ lot.reload.location, proxy.reload.quantity, other_proxy.reload.quantity, sibling_proxy.reload.quantity, Lot.where(location: deck.zone("main")).count ]).to eq([ binder, 2, 2, 2, 0 ])
    end
  end

  it "shows the owner their own page for the same request, so the 404s above are not a bad fixture", :aggregate_failures do
    get new_deck_proxy_replacement_path(deck, proxy)
    expect(response).to have_http_status(:ok)
    get new_deck_proxy_copy_path(deck, proxy)
    expect(response).to have_http_status(:ok)
  end

  it "counts another account's lot of the card as no longer free: 422, nothing moved, and the page doesn't say it exists", :aggregate_failures do
    theirs = create(:lot, account: other, entry:, location: create(:location, account: other), quantity: 2, finish: "foil")

    post deck_proxy_replacement_path(deck, proxy), params: { lots: { theirs.id.to_s => "1" }, shown: { theirs.id.to_s => "2" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML5(response.body).at_css("#replacement-error").text).to eq("Those copies changed. Check the numbers and try again.")
    expect([ theirs.reload.quantity, proxy.reload.quantity ]).to eq([ 2, 2 ])
  end

  it "sends the signed-out visitor to sign in on all four" do
    delete session_path
    [ [ :get, new_deck_proxy_replacement_path(deck, proxy) ], [ :post, deck_proxy_replacement_path(deck, proxy) ],
      [ :get, new_deck_proxy_copy_path(deck, proxy) ], [ :post, deck_proxy_copy_path(deck, proxy) ] ].each do |verb, path|
      public_send(verb, path)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/requests/deck_proxy_replacement_tenancy_spec.rb`. Expected: PASS at once (the routes and `FindsDeck` give the 404s); the examples can fail: the owner's control example proves the fixture could produce a 200. If one fails, it is a gap in the controllers; fix there.
- [ ] **Step 3: Commit**: `test(decks): the replacement pages are 404 for another account's anything (spec 070, #257)`.

---

## Phase 4: System examples, the guard and the documents

**Implements:** Stories 5, 6, 7 | **Satisfies:** AC-3.3, AC-3.12, AC-5.1 to AC-5.4, AC-6.1 to AC-6.5, AC-7.1, AC-7.3, AC-7.4
**Files:** `spec/system/deck_proxy_replacements_spec.rb`, `spec/deck_core_spec.rb`, `app/models/deck/proxy.rb` (header), `spec/models/lot_proxy_isolation_spec.rb` (header), `docs/design-system/**`, `docs/architecture/**`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md`

### T11: The export, the round trip and the no-other-path examples

- [ ] **Step 1: The failing examples.** (a) In `spec/requests/deck_proxy_replacements_spec.rb`, two examples inside `describe "Use these copies"`:

```ruby
      it "leaves the export consistent: the moved lots in the zone's place and the lowered proxy, no new field (AC-5.3)", :aggregate_failures do
        lot = lot_in(binder, entry, 2, finish: "foil")
        post_use({ lot.id.to_s => "1" })

        data = CollectionExport.new(account:, at: Time.current).to_h

        expect(data["proxies"].map { it.slice("quantity", "finish") }).to eq([ { "quantity" => 1, "finish" => "foil" } ])
        expect(data["lots"].filter_map { it["location"]["zone"] if it["location"].is_a?(Hash) }).to include("main")
        expect(data.keys).to match_array(CollectionExport.new(account: create(:user).account, at: Time.current).to_h.keys)
      end

      it "changes no proxy when a copy reaches the zone by any other path (AC-5.1, the spec 068 rule stands)", :aggregate_failures do
        place_lot = lot_in(binder, entry, 2, finish: "foil")
        Lot::Move.new(lot: place_lot, to: deck.zone("main"), copies: "1").call!

        expect(proxy.reload.quantity).to eq(2)
      end
```


(b) The round trip (AC-5.3, "applying that export on a fresh instance gives the same deck page"): a new file `spec/models/deck_proxy_replacement_round_trip_spec.rb`, `type: :model`, built like `spec/models/collection_import/round_trip_spec.rb` (read its `export`, `same_collection?` and `apply!` helpers and copy them):

```ruby
require "rails_helper"

# Spec 070 AC-5.3: a collection after a replacement exports and restores on a fresh account as the same collection, the same
# deck page's counts included.
RSpec.describe "Export and import after replacing a proxy", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let(:target) { create(:user, name: "Target", email_address: "target@example.test") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }

  def export(user, at: Time.utc(2026, 11, 11, 12)) = JSON.parse(CollectionExport.new(account: user.account, at:).to_json)

  def same_collection?(one, other)
    ExportFormatRules.same_collection?(one.merge("profile" => one["profile"].except("name", "email_address")),
      other.merge("profile" => other["profile"].except("name", "email_address")))
  end

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  it "restores the deck with the lowered proxy and the moved copies as the same collection", :aggregate_failures do
    deck = create(:deck, account: source.account, name: "Izzet Tempo")
    proxy = create(:deck_proxy, zone: deck.zone("main"), account: source.account, entry:, finish: "foil", quantity: 3)
    lot = create(:lot, account: source.account, entry:, location: create(:location, account: source.account, name: "Blue binder"), quantity: 2, finish: "foil")
    Deck::Proxy::UseCopies.new(proxy:, typed: { lot.id.to_s => "2" }, shown: { lot.id.to_s => "2" }).save

    original = export(source)
    apply!(target, original)

    expect(original["proxies"].map { it["quantity"] }).to eq([ 1 ])
    expect(same_collection?(original, export(target))).to be(true)
    restored = Deck::Page.new(target.account.decks.includes(:location).sole)
    expect([ restored.owned, restored.proxy ]).to eq([ 2, 1 ])
  end
end
```

(c) In `spec/models/lot_proxy_isolation_spec.rb`, add `Lot::MoveIntoZone` to the paths that never change a proxy (AC-5.1; spec 071 reuses it): next to the `Lot::Move` call of its first example add

```ruby
    Lot::MoveIntoZone.new(account:, zone: deck.zone("main"), picks: [ [ Lot.find_by!(location: elsewhere), 1 ] ]).call!
    expect(unchanged?).to be(true)
```
Exact edit: after the example's first `Lot::Move.new(lot:, to: elsewhere, copies: "1").call!` (the main lot holds 1, `elsewhere` holds 1) insert the `MoveIntoZone` call above and its `expect(unchanged?)`, then the main lot holds 2 (the moved copy merged into it) and `elsewhere` none, so the example's next line must put a copy back first. The sequence reads:

```ruby
    Lot::Move.new(lot:, to: elsewhere, copies: "1").call!
    Lot::MoveIntoZone.new(account:, zone: deck.zone("main"), picks: [ [ Lot.find_by!(location: elsewhere), 1 ] ]).call!
    expect(unchanged?).to be(true)
    Lot::Move.new(lot: lot.reload, to: elsewhere, copies: "1").call!
    Lot::Move.new(lot: Lot.find_by!(location: elsewhere), to: deck.zone("main"), copies: "1").call!
    expect(unchanged?).to be(true)
```

- [ ] **Step 2: Run** `bin/rspec spec/requests/deck_proxy_replacements_spec.rb spec/models/deck_proxy_replacement_round_trip_spec.rb spec/models/lot_proxy_isolation_spec.rb`. Expected: PASS (nothing new in the app is needed); if the round trip fails the format rejects something the replacement wrote, which is a finding. Commit `test(decks): a replacement exports and restores as any collection and no other path changes a proxy (spec 070, #257)`.

### T12: The system examples

- [ ] **Step 1: The spec** `spec/system/deck_proxy_replacements_spec.rb`:

```ruby
require "rails_helper"

# Spec 070 Stories 3, 4 and 6: both flows from the deck page's row menu, with and without scripting, and both pages at 360px, 640px
# and 1280px in both themes with the worst-case names (AC-6.1), and the touch-floor rules read (AC-6.2).
RSpec.describe "Replacing a proxy", type: :system do
  def set_theme(name) = page.execute_script("document.documentElement.dataset.theme = #{name.to_json}")
  def fits? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def entry_of(name = "Lightning Bolt", set: "mh2", number: "138") = create(:mtg_printing, finishes: %w[foil nonfoil], entry: create(:catalog_entry, name:, set: create(:catalog_set, code: set), number:)).entry

  context "with scripting" do
    let(:user) { create(:user) }
    let(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
    let!(:entry) { entry_of }
    let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, finish: "foil", quantity: 2) }

    before do
      page.driver.browser.manage.window.resize_to(1280, 900)
      system_sign_in_as(user)
    end

    it "uses a free copy from the row's menu, and the zone shows the owned copy and the lowered proxy (AC-3.1)", :aggregate_failures do
      create(:lot, account: user.account, entry:, location: create(:location, account: user.account, name: "Blue binder"), quantity: 3, finish: "foil", condition: "near_mint")
      visit deck_path(deck)
      within(first("section.c-zone")) do
        find("summary[aria-label='Actions for Lightning Bolt MH2 · 138']").click
        click_link "Use my copy"
      end
      fill_in "MH2 · 138 Foil, Near mint, Blue binder, ×3 free", with: "1"
      click_button "Use these copies"

      expect(page).to have_content("Replaced 1 proxy of Lightning Bolt (MH2 · 138, Foil) in Izzet Tempo › Main with copies you own.")
      expect(first("section.c-zone")).to have_css(".c-proxy", text: /\AProxy\s+1\z/)
      expect(page).to have_css(".c-item__type", text: "2 cards · 1 owned · 1 proxy")
    end

    it "adds a new copy from the row's menu with the printing, finish and zone filled in (AC-4.1, AC-4.2)", :aggregate_failures do
      visit deck_path(deck)
      within(first("section.c-zone")) do
        find("summary[aria-label='Actions for Lightning Bolt MH2 · 138']").click
        click_link "Add a new copy"
      end
      expect(page).to have_select("Finish", selected: "Foil")
      expect(page).to have_text("Izzet Tempo › Main")
      fill_in "Quantity", with: "2"
      click_button "Add copy"

      expect(page).to have_content("Added 2 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 2 proxies.")
      expect(page).to have_css(".c-item__type", text: "2 cards · 2 owned · 0 proxy")
      expect(page).not_to have_css(".c-proxy")
    end
  end

  # AC-3.1, AC-4.2 "without scripting": rack_test runs no script, and the menu is a plain `details`. driven_by is declared before
  # the let! that signs in, so sign-in goes through rack_test too.
  context "without scripting" do
    before { driven_by :rack_test }

    let!(:user) { system_sign_in_as(create(:user)) }
    let!(:deck) { create(:deck, account: user.account, name: "Izzet Tempo") }
    let!(:entry) { entry_of }
    let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry:, finish: "foil", quantity: 2) }

    it "uses a copy and then adds a new one, through plain pages and forms", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario across both pages
      expect(page.driver).to be_a(Capybara::RackTest::Driver)
      lot = create(:lot, account: user.account, entry:, location: create(:location, account: user.account, name: "Blue binder"), quantity: 1, finish: "foil")
      visit deck_path(deck)
      click_link "Use my copy"
      fill_in "MH2 · 138 Foil, Blue binder, ×1 free", with: "1"
      click_button "Use these copies"
      expect(page).to have_content("Replaced 1 proxy of Lightning Bolt")
      expect(lot.reload.location).to eq(deck.zone("main"))

      click_link "Add a new copy"
      click_button "Add copy"
      expect(page).to have_content("Added 1 × Lightning Bolt (MH2 · 138) to Izzet Tempo › Main, replacing 1 proxy.")
      expect(Deck::Proxy.exists?(proxy.id)).to be(false)
      expect(page).to have_css(".c-item__type", text: "2 cards · 2 owned · 0 proxy")
    end
  end

  # The worst case for both pages: a deck name, a place name and a card name of 60 characters with no space.
  context "when every name is 60 characters with no space" do
    let(:user) { create(:user) }
    let(:deck) { create(:deck, account: user.account, name: "D" * 60) }
    let!(:long) { entry_of("W" * 60) }
    let!(:proxy) { create(:deck_proxy, zone: deck.zone("main"), account: user.account, entry: long, finish: "foil", quantity: 2) }

    before do
      create(:lot, account: user.account, entry: long, location: create(:location, account: user.account, name: "P" * 60), quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 125)
      page.driver.browser.manage.window.resize_to(1280, 900)
      system_sign_in_as(user)
    end

    %w[light dark].each do |theme|
      [ 360, 640, 1280 ].each do |width|
        it "fits Use my copy, its refusal and Add a new copy at #{width}px in the #{theme} theme (AC-6.1)", :aggregate_failures do
          paths = [ new_deck_proxy_replacement_path(deck, proxy), new_deck_proxy_copy_path(deck, proxy) ]
          paths.each do |path|
            visit deck_path(deck)
            open_in_narrow_frame(path, width:, ready: "main")
            within_narrow_frame do
              set_theme(theme)
              expect(fits?).to be(true), "#{path} at #{width}px in #{theme}"
            end
          end
        end

        # The refused pages (AC-6.1's "an error is shown with its field"): the form is submitted inside the frame.
        it "fits the refused Use my copy and Add a new copy at #{width}px in the #{theme} theme, each error read by its field (AC-6.1)", :aggregate_failures do
          # Refusals the browser lets through and the server makes (a field's `max` and `required` would stop a typed 9 first):
          # every field left at 0 (the sum), and a price the server refuses (the field has no pattern).
          [ [ new_deck_proxy_replacement_path(deck, proxy), -> { click_button "Use these copies" }, "fieldset[aria-describedby='replacement-error']" ],
            [ new_deck_proxy_copy_path(deck, proxy), -> { fill_in "Price paid per copy (USD)", with: "abc"; click_button "Add copy" }, "input[name='lot[price_paid]'][aria-describedby]" ] ].each do |path, submit, described|
            visit deck_path(deck)
            open_in_narrow_frame(path, width:, ready: "main")
            within_narrow_frame do
              set_theme(theme)
              instance_exec(&submit)
              expect(page).to have_css(".c-field__error")
              expect(page).to have_css(described)
              expect(fits?).to be(true), "#{path} refused at #{width}px in #{theme}"
            end
          end
        end
      end
    end

    # AC-6.2: the controls of both pages and the rule that gives each its 44px floor on a coarse pointer. Headless Firefox has a
    # fine pointer, so the example reads the stylesheets' rules (the media rule, its selectors, the resolved `--touch-floor`) and
    # measures what is drawn under the rules that apply at every pointer; a control under a coarse-only rule is read, not measured.
    it "gives each control of both pages the rule that lifts it to the touch floor on a coarse pointer (AC-6.2)", :aggregate_failures do
      visit new_deck_proxy_replacement_path(deck, proxy)
      expect(page.evaluate_script("document.querySelector('main').classList.contains('c-decks')")).to be(true)
      expect(top_level_rule(".c-pick__lot .c-input")).to include("minHeight" => "var(--touch-floor)") # the number fields, additions.css
      expect(top_level_rule(".c-decks .c-btn")).to include("minHeight" => "var(--touch-floor)")      # Use these copies, Cancel, the empty state's button
      expect(coarse_rule(".c-btn")).to include("minHeight" => "44px")                                 # components.css, and the app bar's back link (`c-btn`)
      expect(coarse_rule(".c-input")).to include("minHeight" => "44px")                               # Quantity and Price paid on Add a new copy
      expect(coarse_rule(".c-field select")).to include("minHeight" => "var(--touch-floor)") # Finish and Condition on Add a new copy, spec 068
      expect(page.evaluate_script("parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--touch-floor'))")).to be >= 44
      drawn = page.evaluate_script("[...document.querySelectorAll('main .c-btn, main .c-pick__lot .c-input')].map((el) => el.getBoundingClientRect().height)")
      expect(drawn.size).to be >= 3 # the field, Use these copies and Cancel
      expect(drawn).to all(be >= 44)

      visit new_deck_proxy_copy_path(deck, proxy)
      expect(page.evaluate_script("document.querySelector('main').classList.contains('c-decks')")).to be(true)
      buttons = page.evaluate_script("[...document.querySelectorAll('main .c-btn')].map((el) => el.getBoundingClientRect().height)")
      expect(buttons.size).to eq(2) # Add copy and Cancel
      expect(buttons).to all(be >= 44)
    end

    # AC-6.3: a field with focus shows the 2px focus ring: a number field's on its `c-input` wrapper (the pattern of spec 060's
    # `UseMyCopy` example, on the real page), the Finish select's own, reached by Tab from Quantity as a keyboard reaches it.
    it "shows the focus ring on a focused number field's wrapper and on the Finish select", :aggregate_failures do
      visit new_deck_proxy_replacement_path(deck, proxy)
      find("input[type=number]").click
      ring = page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement.closest('.c-input')); return [s.outlineStyle, s.outlineWidth]; })()")
      expect(ring).to eq([ "solid", "2px" ])

      visit new_deck_proxy_copy_path(deck, proxy)
      find("input[name='lot[quantity]']").send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.name")).to eq("lot[finish]")
      expect(page.evaluate_script("(() => { const s = getComputedStyle(document.activeElement); return [s.outlineStyle, s.outlineWidth]; })()")).to eq([ "solid", "2px" ])
    end

    # The first plain (not media) rule whose selector list contains +selector+.
    def top_level_rule(selector)
      page.evaluate_script(<<~JS)
        (() => { for (const sheet of document.styleSheets) for (const rule of sheet.cssRules)
          if (rule.selectorText?.split(",").map((s) => s.trim()).includes(#{selector.to_json})) return { minHeight: rule.style.minHeight }
          return null })()
      JS
    end

    # The first rule of a `pointer: coarse` media block whose selector list contains +selector+ (headless Firefox has a fine
    # pointer, so the example reads the stylesheet's rule, not a layout).
    def coarse_rule(selector)
      page.evaluate_script(<<~JS)
        (() => { for (const sheet of document.styleSheets) for (const media of sheet.cssRules)
          if (media instanceof CSSMediaRule && media.conditionText.includes("pointer: coarse"))
            for (const rule of media.cssRules)
              if (rule.selectorText?.split(",").map((s) => s.trim()).includes(#{selector.to_json})) return { minHeight: rule.style.minHeight }
          return null })()
      JS
    end
  end
end
```

- [ ] **Step 2: Run** `bin/rspec spec/system/deck_proxy_replacements_spec.rb`. Expected: PASS where the code is right; a FAIL is a finding: a width that overflows (the new Location line's wrap rule is T9's), a missing `c-decks`, a selector that is not in the stylesheet as written (`.c-pick__lot .c-input` is a plain rule at additions.css line 532; `.c-btn, .c-input` is the coarse-pointer rule at components.css line 171). Add no CSS for a measured control that already meets its rule.
- [ ] **Step 3: Commit**: `test(decks): both replacement flows with and without scripting, at three widths in both themes (spec 070, #257)`.

### T13: The core guard

- [ ] **Step 1: The failing example.** Run `bin/rspec spec/deck_core_spec.rb`: the "covers every file of the feature" example fails with the new count. The new files the globs match: `app/controllers/decks/proxies/replacements_controller.rb`, `copies_controller.rb`, `app/models/deck/proxy/use_copies.rb`, `add_copy.rb`, `app/views/decks/proxies/replacements/new.html.erb`, `copies/new.html.erb`: **6**. (`app/views/lots/_form.html.erb` is already in the list; `app/models/lot/move_into_zone.rb` is not and stays out: it is a `Lot` file.)
- [ ] **Step 2: Fix the count**: in `spec/deck_core_spec.rb` change `20 + 6 + 1 + 1 + 4 + 1 + 15` to `20 + 6 + 1 + 1 + 4 + 1 + 15 + 6` and append to its trailing comment `; spec 070 adds 6: the replacements and copies controllers, UseCopies and AddCopy, and the two new views (the globs already cover them)`. (Spec 071 adds its own term when both land: sum the counts.)
- [ ] **Step 3: Run** `bin/rspec spec/deck_core_spec.rb`. PASS: none of the new files names a game, a source, a format or a zone key but `considering` (the examples' words "Foil", "Lightning" are not in a file; check the comments of `use_copies.rb`).
- [ ] **Step 4: Guard the shared part.** `app/models/lot/move_into_zone.rb` is in no core guard (decision 8: "these shared files name no collectible"). In `spec/import_apply_core_spec.rb` add `app/models/lot/move_into_zone.rb` beside `app/models/lot/move.rb` in its `files` list; the example "never names a collectible type or a source" covers it. (This is the guard, not T2's commit: the shared files themselves stay as they were handed over.) Run `bin/rspec spec/import_apply_core_spec.rb`.
- [ ] **Step 5: Commit**: `test(decks): the deck core guard counts spec 070's six files and covers Lot::MoveIntoZone (#257)`.

### T14: Code comments and the design system

- [ ] **Step 1: Code comments that said only the old writers change a proxy.** `app/models/deck/proxy.rb` header: replace "(the add, change and remove pages, a format change, a deck's removal, an import that carries proxies)" with "(the add, change and remove pages, the two replacement pages of spec 070, a format change, a deck's removal, an import that carries proxies)". `spec/models/lot_proxy_isolation_spec.rb` header: add that the two replacement pages move or add a copy and lower the proxy in the same write (spec 070), and that every path this spec exercises still never does. Run `bin/yard doc 2>&1 | tail -3` (no warning) and `bin/rspec spec/models/lot_proxy_isolation_spec.rb`.
- [ ] **Step 2: The design system** (the supervisor writes these, reading `.claude/skills/collector-design-system/SKILL.md` and `docs/design-system/README.md` first): `UseMyCopy.md` (the built route `/decks/:deck_id/proxies/:id/replacement`, `c-decks` on `main`, the price in the lot's label, the finish as the vocabulary labels it, "×N free", the `shown` hidden fields, the new sentences "Those copies changed…", "Edit this copy first…", the empty state's secondary button, the order of the lots, "built as drawn"); `AddProxy.md` (a section "Add a new copy": the page, the read-only Location as a `c-field__label` paragraph and text, Quantity's `max` and its sentences, the hidden count, the refusals, Cancel to the deck); `DeckPage.md` lines 5, 82 and 83 (the menu's items, the finish naming); the README's Components line (`UseMyCopy` is built, "Add a new copy" is a use of `lots/_form`); the previews `UseMyCopy.html` and `UseMyCopyPhone.html` brought in line (price in a label, `c-decks`) the previews `DeckPage.html` and `DeckPagePhone.html` (a proxy row's open menu lists "Use my copy", "Add a new copy", "Change proxy count", then "Remove proxy"), and a new pair `AddNewCopy.html`, `AddNewCopyPhone.html` (copy `AddProxy.html`'s shell; the form of `lots/_form` with the fixed Location under `c-field__label` and `c-field__value`); `AddProxy.md` documents the `c-field__value` class and its wrap rule; the App additions line of the README names it. Run `bin/rspec spec/system/design_system_deck_components_spec.rb spec/design_system_files_spec.rb`; fix any list or count they pin (spec 060 AC-7.2's twelve previews becomes fourteen only if a spec pins the number: read the failure).
- [ ] **Step 3: Commit** each: `docs(design-system): Use my copy as built and Add a new copy (spec 070, #257)`; `refactor(decks): the writers of a proxy named in the comments (spec 070)`.

### T15: Area docs, CLAUDE.md, roadmap, index

- [ ] **Step 1:** `docs/architecture/collection-and-lots.md`: the Glossary gains "Free" (a lot in no deck zone, Considering included; `Lot.free`; spec 070 decision 2); the invariant "A proxy is never owned and changes only by hand" names the two replacement pages as the writers that move or add a copy and lower the proxy in one write; "A deck" gains two rows in the proxy table (Use my copy, Add a new copy) and the row menu's order; the Scope's decks line names `Lot.free`, `Lot::MoveIntoZone`, `Deck::Proxy::UseCopies`, `Deck::Proxy::AddCopy`, `Decks::Proxies::ReplacementsController` and `Decks::Proxies::CopiesController`; the "Moving copies" section says `Lot::MoveIntoZone` moves chosen copies into a zone through `Lot::Move`; the list-of-queries invariant mentions Use my copy's page statements; the Sources gain spec 070 and #257. `docs/architecture/tenancy-and-accounts.md`: the new routes' 404 rule and the lot id in the form being "no longer free". `CLAUDE.md`: the deck sentence adds "swaps a proxy for a copy they own (Use my copy) or a new one (Add a new copy), spec 070". `docs/roadmap.md`: the #257 line. `docs/specs/README.md`: the 070 row's Status, Areas and Plan columns when it freezes (the `distill-feature` skill does this at the end). Every new statement carries its source inline (a spec criterion or decision).
- [ ] **Step 2:** `git grep -n -i "use my copy\|add a new copy\|only by hand\|#257" -- docs/architecture CLAUDE.md docs/roadmap.md ':!.kamal/secrets'` shows no remaining sentence that says the two items are to come.
- [ ] **Step 3: Commit**: `docs(architecture): replacing a proxy with a copy, Lot.free and Lot::MoveIntoZone (spec 070, #257)`.

---

## Phase 5: Evidence, verification and review

### T16: Screenshots and GIFs (the supervisor, after T12 and before the review)

Following `.claude/memory/pr-screenshots-workflow.md`: an uncommitted throwaway system spec `spec/system/zz_070_screenshots_spec.rb` with factory data, `SHOTS_DIR=<scratchpad> bin/rspec spec/system/zz_070_screenshots_spec.rb`; set `data-theme` explicitly for both themes and pause 0.6s after each switch; phone widths through `open_in_narrow_frame` at 360 and 390; compress with `magick in.png -resize 1000x -quality 70 out.jpg`. Shots, desktop (1280) and phone, light and dark: the deck page with the row menu open; Use my copy (two groups, the empty state, a refused 422 with a field error and with "Those copies changed…", the cap refusal, a 60-character place name); Add a new copy (the form, the 422 over the count, "This proxy changed…"); the deck page after each replacement, with the lowered proxy and with the proxy gone. GIFs, each under about 1 MB (`ffmpeg -framerate 4 -pattern_type glob -i 'f-*.png' -vf "scale=960:-1,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse" -loop 0 <name>.gif`, a frame repeated to hold it): Use my copy end to end (the menu, the page, the numbers, the deck page with the proxy lowered), Add a new copy end to end, and a phone GIF of Use my copy. Look at every shot and frame; fix anything found test-first. Delete the throwaway spec; commit the images under `docs/specs/070-replace-proxy-with-copy/screenshots/` in one commit (`docs(specs): screenshots and GIFs of spec 070`); list them in `verification.md`.

### T17: verification.md, the full run and the review

- [ ] `verification.md`: each AC with the spec that proves it (file and example); the grep that listed the superseded examples (`git grep -n -i "use my copy\|add a new copy\|UseMyCopy\|#257\|writers\|only by hand\|changes a proxy\|Change proxy count\|Remove proxy" -- spec docs CLAUDE.md app`) and what each hit became; deviations; the screenshots list.
- [ ] Ask the coordinator for a CI slot, run `bin/ci` (the whole suite, YARD, the comment ratchet, Brakeman, RuboCop), report the count of examples and the result, release the slot with the SHA.
- [ ] Dispatch `sdd-review` Mode B on `opus`, read-only, given the spec, the diff and the screenshots; record it in `verification.md` under `## Implementation review` with the verdict first. At most two rounds; findings left after that go to the coordinator with options and a recommendation.
- [ ] `sdd-superpowers:session-wrap` and `distill-feature` (area docs before the PR is ready); push (a slot if the hook runs full CI); open the draft PR (`Closes #257`, "factory data, placeholder card images", SHA-pinned screenshot links); CI green; `gh pr ready`; `gh pr edit --add-assignee @me`; `worker_done`.

---

## Spec coverage

| Spec | Phase / task |
|------|--------------|
| FR-1 Use my copy; Stories 2, 3 | T4, T7, T8 |
| FR-2 Add a new copy; Story 4 | T5, T9 |
| FR-3 the shared parts; decision 8 | T1, T2 |
| Story 1 (the menu): AC-1.1 to AC-1.5 | T6 |
| AC-2.1 to AC-2.9 | T7 (2.8 and 2.9 also T10) |
| AC-3.1 to AC-3.13 | T4, T8 (3.10: T8's lowered-meanwhile example; 3.12: T8's agreement example); AC-3.14 T2, T4 (at the page: the model example is the proof); AC-3.15 T4 (a characterisation, see its note) and T8 |
| AC-4.1 to AC-4.9 | T5, T9, T10 |
| AC-5.1 to AC-5.4 | T8, T11 (5.3: the export and the round trip; 5.1: the isolation spec; 5.4 is spec 068 AC-4.3's example, which still passes: run in T8 Step 3) |
| AC-6.1 to AC-6.5 | T9 (the wrap rule), T12 (widths, the refused pages in the frame, the touch-floor rules, the focus ring), T14, T16 |
| AC-7.1 to AC-7.4 | T13, T2/T4/T5 comments with the ratchet in T17, T6 (the grep), T15 |
| Decisions 1–14 | 1: T3, T6; 2: T1; 3, 4: T4, T7; 5: T9; 6: T3, T4, T5; 7: T2, T4; 8: T1, T2; 9: T4, T8; 10: T5, T9; 11: T8, T9; 12: no task (nothing new in the data; T11 shows the export); 13: no script in any task; 14: no ADR |
