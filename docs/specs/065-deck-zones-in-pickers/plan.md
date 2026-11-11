# Plan: Deck Zones in Every Location Picker and in the Collection Filter

**Spec:** [spec.md](spec.md) v0.2.0 (approved at Gate A, 2026-11-10) | **Issue:** [#252](https://github.com/plainprogrammer/Collector/issues/252) | **Branch:** `065-deck-zones-in-pickers`
**Version:** 0.2.0 (from plan review round 1: nine major findings folded in; Gate B is the coordinator's)

## Global Constraints

- Test first: every phase writes the failing examples, runs them red, then implements. One Conventional Commit per task, each ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. `git add` and `git commit` in separate calls.
- Targeted `bin/rspec <file>` runs need no CI slot. Never run two test runs at once (shared test database). No full `bin/ci`, and no push, without asking the coordinator for a slot.
- Core files name no collectible, format or zone key but `considering` (`spec/deck_core_spec.rb`, `number_entry_core_spec.rb`, `import_apply_core_spec.rb`, `scanner_sitting_core_spec.rb`). `Location::Name` is untouched.
- A write path takes its location from `Current.account.locations.find_placeable!(id)` (`place` and `deck_zone` only; text that is not an id of at most 18 digits is 404 before any cast, so "12abc" is never read as 12), never `Location.find`, never a deck's own row. The bulk move's `update_all` is safe only because of that lookup.
- No migration, no export or import change, no new parameter beyond `deck:<id>` as a filter value, no proxy code or field. A picker's request shape is unchanged: a zone's id travels as the same `location_id`, `location` or `to`.
- UI follows the design system (`Form` and `FilterSelect` already describe the grouped select; `optgroup`/`option` rules exist in `additions.css`). Native selects, no script. The only CSS change is removing the now-unused `.c-field__static`.
- Comments follow `.claude/rules/code-documentation.md`: the new public class and helper carry summaries; every comment that says "places only" and is now false is updated in the same task (`Location.places`' comment says pickers use it until zones are offered: that part goes).
- Overlap: the #251 worker (spec 064) edits decks' format and `collection-and-lots.md`; the #297 worker edits `_table.html.erb`'s Set heading. Keep edits to pickers, the filter and the label. Do not touch `app/views/collections/_table.html.erb` or the CSS around `.c-table`.

## Goal

Every picker (lot form, Move copies, bulk Move to…, number entry, the scanner sitting) and the collection filter offer deck zones as "Deck › Zone" in native `optgroup`s, the filter also offering "<Deck> (all zones)". One object, `Location::Choices`, and one scope, `Location.placeable`, decide what is offered and what a write may name.

## Phase 1: The one source of choices

**Implements:** FR-1, decision 1, decision 2 | **Satisfies:** AC-8.2 (the one read), AC-8.3 (the guard list), AC-8.4 (the scope)
**Files:** `app/models/location.rb` (scope, class comment), `app/models/location/choices.rb` (new), `app/helpers/location_choices_helper.rb` (new), `spec/models/location/choices_spec.rb` (new), `spec/helpers/location_choices_helper_spec.rb` (new), `spec/models/location_spec.rb`, `spec/deck_core_spec.rb`
**Interfaces:**
- `Location.placeable` → relation of `place` and `deck_zone` rows. `Location.find_placeable!(id)` (callable on an account's relation) → the place or zone with that id text, its parent loaded; raises `ActiveRecord::RecordNotFound` for a deck's own row, another account's location (when called on the account's relation), a missing one and any text that is not `Location::ID_TEXT` (`/\A[1-9]\d{0,17}\z/`), which `find` would otherwise cast (`"12abc"` → 12).
- `Location::Choices.new(account)` (nil account is empty): `#places` (Array<Location>, comparison-key order), `#decks` (Array<`Choices::Group`>, a `Data.define(:location, :zones)` per deck that has at least one zone, comparison-key order, zones by id), `#any?(except: nil)`, `#decks?`, `#find(id)` (a place or a zone by id string or integer, else nil; never a deck's row), `#deck(id)` (the deck's `Group`, else nil). One statement; each zone's `parent` is set from it.
- `location_options(choices, selected: nil, leading: [], except: nil, deck_values: false)` → options markup: `leading` pairs, then (no deck in the account) the places flat, or (a deck) `optgroup` "Places" and `optgroup` "Decks"; a group with nothing is omitted; zones read `Location#label`; with `deck_values: true` each deck's group starts with "<Deck> (all zones)" whose value is `CollectionFilter::Place.deck_value(id)`; `except` leaves out the place or zone with that id.

### Task 1.1: Failing examples for the scope, the object and the helper

- [ ] Add to `spec/models/location_spec.rb` (inside `RSpec.describe Location`, a new `describe ".placeable"`):

```ruby
describe ".placeable" do
  it "is the places and the zones of decks, never a deck's own row" do
    account = create(:user).account
    place = create(:location, account:)
    deck = create(:deck, account:)
    expect(account.locations.placeable).to contain_exactly(place, *deck.zones)
    expect(account.locations.placeable).not_to include(deck.location)
  end

  describe ".find_placeable!" do
    let(:account) { create(:user).account }

    it "finds a place or a zone with its parent loaded", :aggregate_failures do
      deck = create(:deck, account:)
      zone = account.locations.find_placeable!(deck.zone("main").id.to_s)
      expect(zone).to eq(deck.zone("main"))
      expect(zone.association(:parent)).to be_loaded
      expect(account.locations.find_placeable!(create(:location, account:).id)).to be_present
    end

    it "is not found for a deck's own row, another account's location, or text that merely starts with an id", :aggregate_failures do
      deck = create(:deck, account:)
      foreign = create(:deck, account: create(:user).account)
      zone_id = deck.zone("main").id
      [ deck.location_id, foreign.zone("main").id, "#{zone_id}abc", "0#{zone_id}", "", nil, "9" * 19 ].each do |bad|
        expect { account.locations.find_placeable!(bad) }.to raise_error(ActiveRecord::RecordNotFound), bad.inspect
      end
    end
  end
end
```

- [ ] Create `spec/models/location/choices_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Location::Choices, type: :model do
  let(:account) { create(:user).account }

  it "lists the places in comparison-key order and the decks with their zones in zone order", :aggregate_failures do
    create(:location, account:, name: "Zed box")
    create(:location, account:, name: "Alpha binder")
    beta = create(:deck, account:, name: "Beta deck")
    alpha = create(:deck, account:, name: "Alpha deck", format: "commander")
    choices = described_class.new(account)
    expect(choices.places.map(&:name)).to eq([ "Alpha binder", "Zed box" ])
    expect(choices.decks.map { it.location.name }).to eq([ "Alpha deck", "Beta deck" ])
    expect(choices.decks.first.zones.map(&:zone)).to eq(alpha.zones.map(&:zone))
    expect(choices.decks.last.zones.map(&:label)).to eq(beta.zones.map { "Beta deck › #{it.name}" })
  end

  it "reads the account's locations in one statement and sets each zone's parent from it", :aggregate_failures do
    create(:location, account:)
    create(:deck, account:)
    other = create(:user).account
    create(:deck, account: other)
    choices = described_class.new(account)
    queries = count_queries { choices.places; choices.decks; choices.any?; choices.decks.flat_map(&:zones).map(&:label) }
    expect(queries).to eq(1)
  end

  it "has nothing for an account with no location and for no account", :aggregate_failures do
    expect(described_class.new(account).any?).to be(false)
    expect(described_class.new(nil).any?).to be(false)
  end

  it "has something for a place alone and for a deck alone", :aggregate_failures do
    create(:location, account:)
    expect(described_class.new(account)).to be_any
    expect(described_class.new(account)).not_to be_decks
    other = create(:user).account
    create(:deck, account: other)
    expect(described_class.new(other)).to be_any
    expect(described_class.new(other)).to be_decks
  end

  it "finds a place or a zone by id, and never a deck's row, another account's location or a malformed id", :aggregate_failures do
    place = create(:location, account:)
    deck = create(:deck, account:)
    foreign = create(:deck, account: create(:user).account)
    choices = described_class.new(account)
    expect(choices.find(place.id)).to eq(place)
    expect(choices.find(deck.zone("main").id.to_s)).to eq(deck.zone("main"))
    expect([ deck.location_id, foreign.zone("main").id, "12abc", "", nil ].map { choices.find(it) }).to all(be_nil)
  end

  it "finds a deck's group by its location's id only", :aggregate_failures do
    deck = create(:deck, account:)
    choices = described_class.new(account)
    expect(choices.deck(deck.location_id.to_s).location).to eq(deck.location)
    expect(choices.deck(deck.zone("main").id)).to be_nil
  end

  it "leaves out a place or a zone with except, for any?", :aggregate_failures do
    place = create(:location, account:)
    expect(described_class.new(account).any?(except: place.id)).to be(false)
    create(:deck, account:)
    expect(described_class.new(account).any?(except: place.id)).to be(true)
  end
end
```

- [ ] Create `spec/helpers/location_choices_helper_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe LocationChoicesHelper, type: :helper do
  let(:account) { create(:user).account }

  def options_of(html) = Nokogiri::HTML5.fragment("<select>#{html}</select>")

  it "is flat with no deck: the leading options then the places", :aggregate_failures do
    create(:location, account:, name: "Box")
    html = options_of(helper.location_options(Location::Choices.new(account), leading: [ [ "No location", "" ] ]))
    expect(html.css("optgroup")).to be_empty
    expect(html.css("option").map(&:text)).to eq([ "No location", "Box" ])
  end

  it "groups Places then Decks, the leading options outside any group, zones as Deck › Zone", :aggregate_failures do
    create(:location, account:, name: "Box")
    deck = create(:deck, account:, name: "Izzet Tempo")
    html = options_of(helper.location_options(Location::Choices.new(account), selected: deck.zone("main").id.to_s, leading: [ [ "No location", "" ] ]))
    expect(html.css("select > option").map(&:text)).to eq([ "No location" ])
    expect(html.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
    expect(html.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
    expect(html.at_css("option[selected]").text).to eq("Izzet Tempo › Main")
  end

  it "omits the Places group when there is no place", :aggregate_failures do
    create(:deck, account:)
    html = options_of(helper.location_options(Location::Choices.new(account)))
    expect(html.css("optgroup").map { it["label"] }).to eq([ "Decks" ])
  end

  it "adds each deck's all-zones option first, valued deck:<id>, only for the filter", :aggregate_failures do
    deck = create(:deck, account:, name: "Izzet Tempo")
    plain = options_of(helper.location_options(Location::Choices.new(account)))
    all = options_of(helper.location_options(Location::Choices.new(account), deck_values: true))
    expect(plain.css("option").map(&:text)).not_to include("Izzet Tempo (all zones)")
    expect(all.css("optgroup[label=Decks] option").first.text).to eq("Izzet Tempo (all zones)")
    expect(all.css("optgroup[label=Decks] option").first["value"]).to eq("deck:#{deck.location_id}")
  end

  it "leaves out the except id and a deck left with no zone, and escapes names", :aggregate_failures do
    deck = create(:deck, account:, name: "A <b>&\" deck")
    html = options_of(helper.location_options(Location::Choices.new(account), except: deck.zone("main").id))
    expect(html.css("option").map(&:text)).not_to include("A <b>&\" deck › Main")
    expect(html.css("option").map(&:text)).to include("A <b>&\" deck › Sideboard")
    expect(html.css("b")).to be_empty
  end
end
```

- [ ] Run `bin/rspec spec/models/location_spec.rb spec/models/location/choices_spec.rb spec/helpers/location_choices_helper_spec.rb`. Expected: failures (`undefined method placeable`, `uninitialized constant Location::Choices`, `undefined method location_options`).

### Task 1.2: The scope, the object, the helper, and the guard

- [ ] `app/models/location.rb`: add under `scope :places`

```ruby
  # What a copy can be in: a place or a zone of a deck, never a deck's own row. Every picker, the filter and every write that
  # names a location go through this (spec 065 decision 1; ADR 0028's "a lot sits in a zone only").
  scope :placeable, -> { where(kind: %w[place deck_zone]) }

  # An id as text: at most 18 digits, no leading zero (a longer id overflows SQLite's 64-bit bind; spec 037 0.2.2). The one
  # definition for a filter value and for a write's location id.
  ID_TEXT = /\A[1-9]\d{0,17}\z/

  # The place or zone with this id, for a write that names one, its parent loaded so a message can read its label. Call it on
  # the account's relation (`Current.account.locations.find_placeable!(id)`), so another account's id is not found either.
  # Text is checked before it is cast: `find("12abc")` would read it as 12.
  #
  # @param id [Integer, String, nil]
  # @return [Location]
  # @raise [ActiveRecord::RecordNotFound] for a deck's own row, a missing id, another account's and anything but an id
  def self.find_placeable!(id)
    raise ActiveRecord::RecordNotFound, "not a location id" unless id.to_s.match?(ID_TEXT)

    placeable.includes(:parent).find(id)
  end
```

and change the comment above `scope :places` and the class header's "Every list of "places" must say which kind it means: `places` for a picker or a filter" to say: `places` for the Locations page and the export; `placeable` for a picker or the filter or a write; `top_level` for everything the collector names; no scope when the reader follows a lot to where it is.

- [ ] Create `app/models/location/choices.rb`:

```ruby
# What a collector can choose a location from, for one account: its places, and its decks with their zones (spec 065
# decision 1). One statement reads every location of the account, so a picker, the collection filter and a message that
# names a zone cost one read between them, and each zone's `parent` is set from that read so `Location#label` costs nothing.
#
# This is for showing a choice. A write that names a location still looks it up through `Current.account.locations.placeable`
# (404 when it isn't one), because a request's id is untrusted. Collectible-agnostic: a deck is a location and a zone is its
# child; no format or zone key is named here.
# @see file:collection-and-lots.md
class Location::Choices
  # A deck (its location) and its zones in zone order (`Deck#zones`: by id, the format's order).
  Group = Data.define(:location, :zones)

  # @param account [Account, nil] whose locations are offered; nil offers none
  def initialize(account)
    @account = account
  end

  # The account's places, in the Locations page's order.
  #
  # @return [Array<Location>] the places, by comparison key then name
  def places = loaded.first

  # The account's decks that have a zone, each with its zones.
  #
  # @return [Array<Group>] the decks that have a zone, by comparison key then name; a deck with no zone (only an import's
  #   repair can leave one) is not offered, so no group is ever drawn empty
  def decks = loaded.last

  # Whether a picker has anything to offer: a place or a zone.
  #
  # @param except [Integer, String, nil] a place or zone that doesn't count (Move copies' own place)
  def any?(except: nil)
    skip = except&.to_s
    places.any? { it.id.to_s != skip } || decks.any? { |group| group.zones.any? { it.id.to_s != skip } }
  end

  # Whether the account has a deck to group zones under.
  #
  # @return [Boolean]
  def decks? = decks.any?

  # A place or a zone of the account by id; nil for anything else, a deck's own row included.
  #
  # @param id [Integer, String, nil]
  # @return [Location, nil] with its parent set when it is a zone
  def find(id)
    key = id.to_s
    return unless key.match?(/\A\d+\z/)

    places.find { it.id.to_s == key } || decks.flat_map(&:zones).find { it.id.to_s == key }
  end

  # A deck of the account by its location's id.
  #
  # @param id [Integer, String, nil]
  # @return [Group, nil]
  def deck(id) = decks.find { it.location.id.to_s == id.to_s }

  private
    def loaded
      @loaded ||= begin
        rows = @account ? @account.locations.ordered.order(:id).to_a : []
        zones = rows.select(&:zone?).group_by(&:parent_id)
        groups = rows.select(&:deck?).filter_map do |deck|
          in_deck = zones.fetch(deck.id, []).sort_by(&:id)
          next if in_deck.empty?

          in_deck.each { it.association(:parent).target = deck }
          Group.new(location: deck, zones: in_deck)
        end
        [ rows.select(&:place?), groups ]
      end
    end
end
```

- [ ] Create `app/helpers/location_choices_helper.rb`:

```ruby
# The options of a location select (spec 065 decision 2): every picker and the collection filter render one, so they cannot
# disagree. Native `optgroup`s, no script.
module LocationChoicesHelper
  # The options of a location select.
  #
  # With no deck in the account the select is flat (the leading options, then the places). With a deck it is the leading
  # options, an `optgroup` "Places" and an `optgroup` "Decks" whose options read "Deck › Zone"; a group with nothing in it is
  # omitted. Values are location ids as text.
  #
  # @param choices [Location::Choices]
  # @param selected [String, nil] the value to mark selected
  # @param leading [Array<Array(String, String)>] options outside any group, such as `[["No location", ""]]`
  # @param except [Integer, String, nil] the place or zone to leave out (the one a move starts from)
  # @param deck_values [Boolean] the filter's form: each deck's group starts with "<Deck> (all zones)", valued
  #   `CollectionFilter::Place.deck_value`
  # @return [ActiveSupport::SafeBuffer] `option` and `optgroup` tags
  def location_options(choices, selected: nil, leading: [], except: nil, deck_values: false)
    skip = except&.to_s
    places = choices.places.reject { it.id.to_s == skip }.map { [ it.name, it.id.to_s ] }
    base = options_for_select(leading, selected)
    return base + options_for_select(places, selected) unless choices.decks?

    decks = choices.decks.flat_map do |group|
      zones = group.zones.reject { it.id.to_s == skip }.map { [ it.label, it.id.to_s ] }
      next [] if zones.empty?

      deck_values ? [ [ "#{group.location.name} (all zones)", CollectionFilter::Place.deck_value(group.location.id) ], *zones ] : zones
    end
    groups = []
    groups << [ "Places", places ] if places.any?
    groups << [ "Decks", decks ] if decks.any?
    base + grouped_options_for_select(groups, selected)
  end
end
```

- [ ] `CollectionFilter::Place.deck_value` is added in Phase 5 (Task 5.2); to keep this phase green, add it now in `app/models/collection_filter/place.rb` only as `def self.deck_value(id) = "deck:#{id}"` with its comment, and set `ID = Location::ID_TEXT` there (same value, one definition); Phase 5 completes the module.
- [ ] `spec/deck_core_spec.rb`: add `app/models/location/choices.rb app/helpers/location_choices_helper.rb` to `patterns`, and change `expect(files.size).to eq(17)` to `19`. Check `grep -n "scanner\|number" ` guards' globs do not match the new files (`spec/number_entry_core_spec.rb`, `spec/scanner_sitting_core_spec.rb` list their own files).
- [ ] Run the three new/changed spec files and `bin/rspec spec/deck_core_spec.rb`. Expected: all pass.
- [ ] Commit: `feat(locations): Location.placeable and Location::Choices, the one source of what a picker offers (#252)`.

## Phase 2: The lot form and Move copies

**Implements:** FR-2 (lot form, Move copies), decisions 6, 7, 9 | **Satisfies:** AC-1.1–AC-1.8, AC-2.1–AC-2.4, AC-8.4
**Files:** `app/controllers/lots_controller.rb`, `app/views/lots/_form.html.erb`, `app/views/lots/new.html.erb`, `app/views/lots/edit.html.erb`, `app/controllers/lots/moves_controller.rb`, `app/views/lots/moves/new.html.erb`, `app/assets/stylesheets/collector/additions.css` (remove `.c-field__static` and its coarse-pointer rule, lines about 539–540), `spec/requests/lots_spec.rb`, `spec/requests/lot_moves_spec.rb`
**Interfaces:** the form takes `choices:` (a `Location::Choices`) in place of `locations:` and `zone_label:`; `LotsController#chosen_location` and `Lots::MovesController#destination` look up through `placeable.includes(:parent)`.

### Task 2.1: Failing examples (rewrite the spec 062 examples that say "places only")

- [ ] `spec/requests/lots_spec.rb`, inside `describe "with a deck (spec 062)"`: replace the AC-5.1 example, the "refuses a zone's id…" examples and the AC-5.8a example with:

```ruby
it "lists No location, Places, then Decks as Deck › Zone, on the new and the edit form (spec 065 AC-1.1)", :aggregate_failures do
  lot = create(:lot, account:, entry:, location: box)
  [ new_catalog_entry_lot_path(entry), edit_lot_path(lot) ].each do |path|
    get path
    select = page_html.at_css('select[name="lot[location_id]"]')
    expect(select.xpath("./option").map(&:text)).to eq([ "No location" ])
    expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
    expect(select.css('optgroup[label="Places"] option').map(&:text)).to eq(%w[Binder Box])
    expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
  end
end

it "adds copies to the zone chosen and names it in the notice (AC-1.5)", :aggregate_failures do
  post catalog_entry_lots_path(entry), params: { lot: { quantity: "2", location_id: zone.id } }
  expect(response).to have_http_status(:see_other)
  expect(account.lots.sole.attributes.values_at("location_id", "quantity")).to eq([ zone.id, 2 ])
  expect(flash[:notice]).to end_with("to Izzet Tempo › Main.")
end

it "refuses a deck's own id and another account's place, zone and deck, adding nothing (AC-1.7)", :aggregate_failures do
  foreign = create(:deck, account: create(:user).account)
  other_place = create(:location, account: create(:user).account)
  [ deck.location_id, foreign.zone("main").id, foreign.location_id, other_place.id, "12abc" ].each do |id|
    post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", location_id: id } }
    expect(response).to have_http_status(:not_found), id.to_s
  end
  expect(account.lots.count).to eq(0)
end

it "refuses a deck's own id on Edit copy, changing nothing, and moves a lot to a zone (AC-1.6, AC-1.7)", :aggregate_failures do
  lot = create(:lot, account:, entry:, quantity: 3, location: box)
  patch lot_path(lot), params: { lot: { quantity: "4", location_id: deck.location_id } }
  expect(response).to have_http_status(:not_found)
  expect(lot.reload.attributes.values_at("location_id", "quantity")).to eq([ box.id, 3 ])
  patch lot_path(lot), params: { lot: { quantity: "3", location_id: zone.id } }
  expect(lot.reload.location).to eq(zone)
end

it "offers the select to an account with a deck and no place (AC-1.2)", :aggregate_failures do
  Location.places.where(account:).delete_all
  get new_catalog_entry_lot_path(entry)
  select = page_html.at_css('select[name="lot[location_id]"]')
  expect(select.css("optgroup").map { it["label"] }).to eq([ "Decks" ])
  expect(response.body).not_to include("to keep copies in one.")
end

it "is flat for an account with places and no deck, and keeps the hint for one with neither (AC-1.3, AC-1.4)", :aggregate_failures do
  account.decks.find_each { it.remove! }
  get new_catalog_entry_lot_path(entry)
  expect(page_html.css('select[name="lot[location_id]"] optgroup')).to be_empty
  expect(page_html.css('select[name="lot[location_id]"] option').map(&:text)).to eq([ "No location", "Binder", "Box" ])
  Location.places.where(account:).delete_all
  get new_catalog_entry_lot_path(entry)
  expect(page_html.at_css('select[name="lot[location_id]"]')).to be_nil
  expect(response.body).to include("to keep copies in one.")
end
```

  (The `before` block there already creates `box`, "Binder" and `deck`. `account.decks.find_each { it.remove! }` removes the empty deck.)

- [ ] In the same file replace `describe "editing a lot in a zone (spec 062 AC-5.5)"` first two examples with one that shows the select and the saved zone, and keep the "keeps the lot in its zone when the form is saved as the page sends it" and the merge examples unchanged except the header comment:

```ruby
it "shows the select with the zone chosen, not read-only text (spec 065 AC-1.6)", :aggregate_failures do
  get edit_lot_path(lot)
  expect(page_html.at_css("p.c-field__static")).to be_nil
  select = page_html.at_css("select#lot_location_id")
  expect(select.at_css("option[selected]").text).to eq("Izzet Tempo › Main")
end

it "shows it to an account with a deck and no place too (AC-1.2)", :aggregate_failures do
  expect(account.locations.places).to be_empty
  get edit_lot_path(lot)
  expect(page_html.at_css("select#lot_location_id option[selected]").text).to eq("Izzet Tempo › Main")
  expect(page_html.at_css(".c-field__hint a")).to be_nil
end
```

  The existing "keeps the lot in its zone when the form is saved as the page sends it" example's `submitted(form)` already reads `option[selected]`, so it now proves the select keeps the zone.
- [ ] `spec/requests/lot_moves_spec.rb`, the examples at about line 165 (spec 062 AC-5.1, AC-5.2, AC-5.6): replace "offers the places and No location, never a deck or a zone" with:

```ruby
it "offers No location, Places and Decks, the lot's own zone left out (spec 065 AC-2.1)", :aggregate_failures do
  lot = create(:lot, account:, entry:, quantity: 2, location: deck.zone("main"))
  get new_lot_move_path(lot)
  select = page_html.at_css('select[name="move[location_id]"]')
  expect(select.xpath("./option").map(&:text)).to eq([ "No location" ])
  expect(select.css('optgroup[label="Decks"] option').map(&:text)).not_to include("Izzet Tempo › Main")
  expect(select.css('optgroup[label="Decks"] option').map(&:text)).to include("Izzet Tempo › Sideboard")
end

it "moves some copies into a zone, merging as for a place, and names the label (AC-2.2)", :aggregate_failures do
  lot = create(:lot, account:, entry:, quantity: 3, location: box)
  post lot_move_path(lot), params: { move: { copies: "2", location_id: deck.zone("main").id } }
  expect(response).to have_http_status(:see_other)
  expect(flash[:notice]).to end_with("to Izzet Tempo › Main.")
  expect(account.lots.where(location: deck.zone("main")).sum(:quantity)).to eq(2)
  expect(lot.reload.quantity).to eq(1)
end

it "refuses a lot's own zone and 404s a deck's own id and another account's location (AC-2.3, AC-2.4)", :aggregate_failures do
  lot = create(:lot, account:, entry:, quantity: 2, location: deck.zone("main"))
  post lot_move_path(lot), params: { move: { copies: "1", location_id: deck.zone("main").id } }
  expect(response).to have_http_status(:unprocessable_content)
  expect(response.body).to include("Those copies are already there.")
  foreign = create(:deck, account: create(:user).account)
  [ deck.location_id, foreign.zone("main").id ].each do |id|
    post lot_move_path(lot), params: { move: { copies: "1", location_id: id } }
    expect(response).to have_http_status(:not_found)
  end
  expect(lot.reload.attributes.values_at("location_id", "quantity")).to eq([ deck.zone("main").id, 2 ])
end
```

  Use the file's own `let`s for `entry`, `deck` and `account` (read the neighbouring examples at about line 150–200 and name the same ones); change the old 404 example (zone id) to keep only the deck's own id and a foreign zone.
- [ ] Also rewrite what Phase 2 makes false (open each range and rewrite it to say what spec 065 says):
  - `spec/requests/lots_spec.rb` about lines 508–515, "ignores a location in the request: the zone is not changed through Edit copy": a zone lot now moves through the select. Replace with "moves a lot in a zone to a place, another zone or none through Edit copy's select, and answers 404 for a deck's own row (AC-1.6, AC-1.7)", with `"#{zone.id}abc"` among the 404 ids (text that merely starts with an id is 404, AC-1.7).
  - `spec/system/lot_edit_zone_spec.rb` (the whole file asserts `.c-field__static`, which goes): header says spec 065 AC-1.6; example one asserts `have_select("Location", selected: "Izzet Tempo › Main")`, fills Quantity 5, saves, and checks the lot is still in the zone; example two sets a 60-character deck name and uses `open_in_narrow_frame(edit_lot_path(lot), width: 360, ready: "select#lot_location_id")` expecting `[ 360, true ]` (no sideways scroll: a select never widens its form).
  - `spec/requests/lot_moves_spec.rb` about lines 170–175 (the exact list `["No location", "Binder", "Long box"]`): the lists now include the Decks group when the account has a deck; assert the groups as in the new example above (a lot in a place: No location, Places without its own, Decks with every zone).
  - New examples in `lots_spec.rb` for AC-1.8 (a request with `account_id`, `kind` and `parent_id` among the lot's params is permitted only `quantity finish condition price_paid location_id`: the lot is the signed-in account's and its location the one named) and for the AC-1.6 race (the zone's deck is removed before a PATCH that names the zone: 404, `lot.reload.location` unchanged).
- [ ] Run `bin/rspec spec/requests/lots_spec.rb spec/requests/lot_moves_spec.rb spec/system/lot_edit_zone_spec.rb`. Expected: the new and rewritten examples fail (no optgroups, a zone's id still 404, the system example still looks for the select).
- [ ] Commit: `test(lots): spec 065 examples for zones in the lot form and Move copies (#252)`.

### Task 2.2: The lot form and Move copies offer zones

- [ ] `app/controllers/lots_controller.rb`: replace `before_action :set_locations` and `:set_zone_label` with `before_action :set_choices, only: %i[new create edit update]`; delete `set_zone_label`; replace `set_locations`, `chosen_location` and `lot_params`:

```ruby
    # What the form's Location select offers: the account's places and the zones of its decks (spec 065 decision 2).
    def set_choices = @choices = Location::Choices.new(Current.account)

    # The place or zone the form names, nil for none; a deck's own row, another account's location, a missing one and text that
    # isn't an id are 404 (spec 065 AC-1.7). Its parent is loaded so the notice can read "Deck › Zone".
    def chosen_location
      id = lot_params[:location_id].presence
      Current.account.locations.find_placeable!(id) if id
    end

    def lot_params = params.expect(lot: %i[quantity finish condition price_paid location_id])
```

  In `update` delete the comment line about a lot in a zone keeping it and keep `place = lot_params.key?(:location_id) ? chosen_location : @lot.location # absent keeps the place; blank is "No location" (spec 032 O3)`. In `create` the notice becomes `to #{location ? location.label : "your collection"}`. Rewrite the `set_lot` comment: its "the form's label needs them" is stale (the form no longer shows a label); keep `eager_load(location: :parent)` and the reason that stays true, that a separate lookup of the lot's place would come before the lookup of the place the form names (spec 032 AC-6.7's race).
- [ ] `app/views/lots/_form.html.erb`: first line `<%# locals: (form_model:, url:, method:, submit:, choices:) %>`; replace the `<% if zone_label %> … <% elsif locations.any? %> … <% else %>` block by:

```erb
  <% if choices.any? %>
    <div class="c-field">
      <%= form.label :location_id, "Location", class: "c-field__label" %>
      <%= form.select :location_id, location_options(choices, selected: form_model.location_id.to_s, leading: [ [ "No location", "" ] ]) %>
    </div>
  <% else %>
    <p class="c-field__hint"><%= link_to "Add a location", locations_path %> to keep copies in one.</p>
  <% end %>
```

  In `new.html.erb` pass `choices: @choices` (drop `locations:`); in `edit.html.erb` pass `choices: @choices` (drop `locations:` and `zone_label:`).
- [ ] `app/controllers/lots/moves_controller.rb`: replace `set_destinations` and `destination`, and the success notice:

```ruby
    # The To field's choices: "No location" first unless the lot is already unplaced, then Places and Decks, the lot's own place or
    # zone left out (spec 065 decision 7). @offered says whether there is anything to move to.
    def set_destinations
      @choices = Location::Choices.new(Current.account)
      @leading = @lot.location_id ? [ [ "No location", "" ] ] : []
      @offered = @lot.location_id.present? || @choices.any?(except: @lot.location_id)
    end

    # The place or zone the To field names, nil for none; a deck's own row and any other id are 404 (spec 065 AC-2.4).
    def destination
      id = move_params[:location_id].presence
      Current.account.locations.find_placeable!(id) if id
    end
```

  notice: `to #{to ? to.label : "no location"}`. Fix the comment above `set_destinations`.
- [ ] `app/views/lots/moves/new.html.erb`: `<% if @destinations.empty? %>` → `<% unless @offered %>` (and `<% else %>` stays: write `<% if !@offered %>`), and the select: `form.select :location_id, location_options(@choices, selected: @move.location_id, leading: @leading, except: @lot.location_id), {}, { "aria-describedby": … }`.
- [ ] `app/assets/stylesheets/collector/additions.css`: delete the two `.c-field__static` lines (and the comment block above them if it only describes it). `git grep -n 'c-field__static' -- app docs ':!.kamal/secrets'` must then show only docs (updated in Phase 6).
- [ ] Run `bin/rspec spec/requests/lots_spec.rb spec/requests/lot_moves_spec.rb spec/models/lot/move_spec.rb spec/system/lot_edit_zone_spec.rb spec/models/location_spec.rb`. Expected: pass.
- [ ] Commit: `feat(lots): the lot form and Move copies offer deck zones in grouped selects (#252)`.

## Phase 3: Bulk Move to…

**Implements:** FR-2 (bulk Move to…), decisions 7, 9, 12 | **Satisfies:** AC-3.1–AC-3.4, AC-6.11 (the move half)
**Files:** `app/controllers/collections/moves_controller.rb`, `app/views/collections/moves/new.html.erb`, `app/controllers/collections/selections_controller.rb`, `app/models/lot/bulk_move.rb` (message, comments), `app/helpers/collections_helper.rb` (`moved_message`), `app/models/collection_filter.rb` and `app/views/collections/_bulk.html.erb`, `_filter_bar.html.erb` (the renamed gate, see Task 3.2 note), `spec/requests/bulk_move_spec.rb`, `spec/models/lot/bulk_move_spec.rb`
**Interfaces:** `CollectionFilter#choices` (a `Location::Choices`, memoized) and `#choices?` replace `#locations` and `#places?` (Phase 5 finishes the filter; this phase adds `choices`/`choices?` and the view gates, keeping the old names until Task 5.3 removes them).

### Task 3.1: Failing examples

- [ ] `spec/requests/bulk_move_spec.rb`, in the spec 062 describe near line 540: replace the AC-5.1 and AC-5.2 examples with (reuse the file's `select_lots`, `own`, `in_zone`, `zone`, `deck`, `box`, `blue`, `twin` helpers):

```ruby
it "offers Choose…, No location, Places and Decks as Deck › Zone (spec 065 AC-3.1)", :aggregate_failures do
  select_lots(own("Placed", location: box))
  get new_collection_move_path
  select = page_html.at_css("select#to")
  expect(select.xpath("./option").map(&:text)).to eq([ "Choose…", "No location" ])
  expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
  expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
end

it "leaves out the filter's own zone, and nothing under a deck filter (AC-3.1)", :aggregate_failures do
  zoned = in_zone
  select_lots(zoned, location: zone.id.to_s) # starts the selection under the zone filter and ticks the lot, as the file's own helper does
  get new_collection_move_path
  expect(page_html.css('select#to optgroup[label="Decks"] option').map(&:text)).not_to include("Izzet Tempo › Main")
  select_lots(zoned, location: CollectionFilter::Place.deck_value(deck.location_id)) # passes only once Task 5.2 parses deck:<id>
  get new_collection_move_path
  expect(page_html.css('select#to optgroup[label="Decks"] option').map(&:text)).to include("Izzet Tempo › Main", "Izzet Tempo › Sideboard")
end

it "moves every selected lot into the zone, merging where an identity meets, and names the label (AC-3.2)", :aggregate_failures do
  placed = own("Card B", location: box, quantity: 3)
  unplaced = own("Card C", quantity: 1)
  select_lots(placed, unplaced)
  post collection_move_path, params: { to: zone.id }
  expect(response).to have_http_status(:see_other)
  expect(flash[:notice]).to eq("Moved 4 items to Izzet Tempo › Main.")
  expect([ placed.reload.location, unplaced.reload.location ]).to all(eq(zone))
end

it "answers 404 for a deck's own id and another account's location, changing nothing (AC-3.3)", :aggregate_failures do
  zoned = in_zone
  select_lots(zoned)
  foreign = create(:deck, account: create(:user).account)
  [ deck.location_id, foreign.zone("main").id ].each do |id|
    post collection_move_path, params: { to: id }
    expect(response).to have_http_status(:not_found)
  end
  expect(zoned.reload.location).to eq(zone)
end

it "refuses a move to where every selected lot already is, naming the label (AC-3.3)", :aggregate_failures do
  select_lots(in_zone)
  post collection_move_path, params: { to: zone.id }
  expect(response).to have_http_status(:unprocessable_content)
  expect(response.body).to include("The selected items are already in Izzet Tempo › Main.")
end
```

  Read the file's helpers near its top first: `select_lots(*lots)` ticks lots under all locations; if it takes no `location:` keyword, extend it (`post collection_selection_path, params: { location: }` before the `patch`) or use `bulk_zone_filter_spec.rb`'s `select_under(filter, *lots, go: "move")`, which shows the raw requests. The existing "answers 404 for a zone's id and a deck's id" example becomes the deck-and-foreign one above; the "moves a zone lot, a place lot and an unplaced lot to a place" example (AC-5.7a) stays.
- [ ] `spec/models/lot/bulk_move_spec.rb`: add

```ruby
it "names the destination's label when every selected lot is already there" do
  deck = create(:deck, account:, name: "Izzet Tempo")
  zone = Location.placeable.includes(:parent).find(deck.zone("main").id)
  expect(Lot::BulkMove::NothingToMove.new(zone).message).to eq("The selected items are already in Izzet Tempo › Main.")
end
```

  (`account` as the file defines it; adapt the `let`.)
- [ ] Also rewrite what Phase 3 makes false:
  - `spec/requests/bulk_move_spec.rb` about lines 587–598 (an account with a deck and no place gets "You have no locations yet."): it now gets the Move page, with the Decks group only; keep a sibling example for an account with neither a place nor a deck.
  - `spec/requests/collection_places_spec.rb` about lines 227–246 (a deck-only account has no select, no Move to…): it now shows the select and Move to… (spec 065 AC-6.10, decision 3).
  - `spec/requests/bulk_zone_filter_spec.rb` about lines 59–61 (a move whose destination is a zone's id answers 404): the destination is a zone now, so moving lots that are all in it answers 422 "The selected items are already in Izzet Tempo › Main."; keep a 404 case for a deck's own id.
- [ ] The deck half of the filter-own-zone example passes only once Phase 5 parses `deck:<id>` as a filter value; write it in Task 5.1 with the filter examples and keep the zone half here.
- [ ] Run `bin/rspec spec/requests/bulk_move_spec.rb spec/models/lot/bulk_move_spec.rb`. Expected: new examples fail.
- [ ] Commit: `test(bulk): spec 065 examples for zones in bulk Move to… (#252)`.

### Task 3.2: Bulk Move to… offers zones

- [ ] `app/models/collection_filter.rb`: add (keeping the old methods for now)

```ruby
  # Everything the account can choose a location from, read once (spec 065 decision 1).
  def choices = @choices ||= Location::Choices.new(@account)

  # Whether the account has a place or a zone: the gate of the select, the filter and Move to… (spec 065 decision 3).
  def choices? = choices.any?
```

  and change `app/views/collections/_bulk.html.erb` lines using `table.places?` to `table.choices?`, and `_filter_bar.html.erb`'s `listing.places?` to `listing.choices?` (the filter select itself is Phase 5; the gate moves now so a deck-only account sees both together).
- [ ] `app/controllers/collections/selections_controller.rb`: replace the comment and `offered?` with

```ruby
    # "Move to…" is offered only while the account has a place or a zone; asked for without one it is a navigation (spec 041
    # AC-1.2; spec 065 decision 3).
    def offered?(action) = action != "move" || Location::Choices.new(Current.account).any?
```

- [ ] `app/controllers/collections/moves_controller.rb`: `before_action :set_choices` then `:require_choices` (replace `require_locations` and `set_destinations`); `destination_for` ends `Current.account.locations.find_placeable!(value)` (its own `ID` check stays: it also answers 404 for a `deck:` value) with its comment saying a deck's own row is 404 (the move writes with `update_all`); and

```ruby
    # What the To field offers: the prompt, "No location" (left out under the "No location" filter), Places and Decks, the
    # selection's own place or zone left out (spec 065 decision 7; a deck filter leaves out nothing, its value is no id).
    def set_choices
      @choices = Location::Choices.new(Current.account)
      @own = @selection ? @selection.location_filter : ""
      @leading = [ [ "Choose…", "" ] ] + (@own == CollectionFilter::Place::NONE ? [] : [ [ "No location", CollectionFilter::Place::NONE ] ])
    end

    # An account with no place and no deck has nothing to move to, whatever was submitted. The selection is kept.
    def require_choices
      redirect_to @bulk_path, status: :see_other, alert: Lot::BulkMove::NO_LOCATIONS unless @choices.any?
    end
```

- [ ] `app/views/collections/moves/new.html.erb`: `select_tag :to, location_options(@choices, selected: @to, leading: @leading, except: @own), required: true, "aria-describedby": …`.
- [ ] `app/models/lot/bulk_move.rb`: `NothingToMove` message `#{to.label}` (comment: `to` is loaded with its parent when a zone); the header comment's "+to+ is a place of +account+ … (never a deck or a zone, spec 062 …)" becomes "a place or a zone of +account+, never a deck's own row". `app/helpers/collections_helper.rb#moved_message`: `to.label`.
- [ ] Run `bin/rspec spec/requests/bulk_move_spec.rb spec/models/lot/bulk_move_spec.rb spec/requests/bulk_mode_spec.rb spec/requests/edit_many_spec.rb spec/requests/collection_places_spec.rb spec/requests/bulk_zone_filter_spec.rb spec/import_apply_core_spec.rb`. Expected: pass (`bulk_zone_filter_spec.rb`'s header comment and first example are rewritten in Task 5.1).
- [ ] Commit: `feat(bulk): Move to… offers deck zones and names the label (#252)`.

## Phase 4: Number entry and the scanner sitting

**Implements:** FR-2 (number entry, sitting), decisions 8, 9 | **Satisfies:** AC-4.1–AC-4.4, AC-5.1–AC-5.5
**Files:** `app/models/number_entry/line_form.rb`, `app/views/collections/number_entries/_line_form.html.erb`, `app/controllers/concerns/scanner_sitting.rb`, `app/controllers/scanner/sittings_controller.rb`, `app/helpers/scanners_helper.rb`, `app/views/scanners/_picker.html.erb`, `_sitting.html.erb`, `_summary.html.erb`, `_scanner.html.erb`, `spec/models/number_entry/line_form_spec.rb`, `spec/requests/number_entries_spec.rb`, `spec/requests/scanner/sittings_spec.rb`
**Interfaces:** `NumberEntry::LineForm#choices` (a `Location::Choices`) replaces `#locations`; the sitting partials take `choices:` in place of `locations:` (including `sitting_locals`' hash key); `account_locations` becomes `account_choices`.

### Task 4.1: Failing examples

- [ ] `spec/models/number_entry/line_form_spec.rb` (the example at about line 157): replace with

```ruby
it "offers places and zones, and refuses a deck's own row and another account's ids with the field's error (spec 065 AC-4.1, AC-4.3)", :aggregate_failures do
  deck = create(:deck, account:)
  place = create(:location, account:)
  foreign = create(:deck, account: create(:user).account)
  expect(line(location: deck.zone("main").id.to_s).location_record).to eq(deck.zone("main"))
  expect(line(location: place.id.to_s).location_record).to eq(place)
  [ deck.location_id, foreign.zone("main").id ].each do |id|
    form = line(location: id.to_s)
    expect(form).not_to be_valid
    expect(form.errors[:location]).to eq([ "That location isn't one of yours any more. Choose again." ])
  end
end
```

  (`line(...)` / `account` stand for whatever the neighbouring examples use to build a valid `LineForm`; copy the construction from the example being replaced.)
- [ ] `spec/requests/number_entries_spec.rb` (the spec 062 block at about line 306): replace "lists No location and the places, never a deck or a zone (AC-5.1)" with grouped-list, add-into-zone and carry-over examples:

```ruby
it "lists No location, Places and Decks as Deck › Zone (spec 065 AC-4.1)", :aggregate_failures do
  get number_entry_url_for_set
  select = page_html.at_css("select#line_location")
  expect(select.xpath("./option").map(&:text)).to eq([ "No location" ])
  expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
  expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
end

it "adds into the zone chosen, and shows it chosen after the add (AC-4.2, AC-4.4)", :aggregate_failures do
  post collection_number_entry_lines_path, params: line_params(location: deck.zone("main").id)
  expect(account.lots.sole.location).to eq(deck.zone("main"))
  expect(flash[:notice]).to include("in Izzet Tempo › Main")
  follow_redirect!
  expect(page_html.at_css("select#line_location option[selected]").text).to eq("Izzet Tempo › Main")
end

it "refuses a deck's own id and another account's zone as typed, adding nothing (AC-4.3)", :aggregate_failures do
  foreign = create(:deck, account: create(:user).account)
  [ deck.location_id, foreign.zone("main").id ].each do |id|
    post collection_number_entry_lines_path, params: line_params(location: id)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("That location isn&#39;t one of yours any more. Choose again.").or include("That location isn't one of yours any more. Choose again.")
  end
  expect(account.lots.count).to eq(0)
end
```

  The helper names `number_entry_url_for_set`, `line_params`, `deck`, `account` are placeholders for what the file already defines for its neighbouring examples (read lines 1–80 and 300–340 and use those; for the carry-over, follow how the existing spec 034 example reads the redirect's `location` param). Also change the AC-5.8a example there (an account with a deck and no place) to expect the select, with the Decks group only.
- [ ] `spec/requests/scanner/sittings_spec.rb` (the example at about line 341): replace "lists No location and the places in the picker, never a deck or a zone" with the grouped list, and add

```ruby
it "sets a zone, scans into it and says so (spec 065 AC-5.2)", :aggregate_failures do
  patch scanner_sitting_path, params: { sitting: { location_id: deck.zone("main").id } }, as: :turbo_stream
  expect(response).to have_http_status(:ok)
  expect(response.body).to include("Cards you scan now: condition not specified, in Izzet Tempo › Main.")
  expect(account.scanner_sitting.location).to eq(deck.zone("main"))
end

it "refuses a deck's own id and another account's zone with 422 and the sentence, changing nothing (AC-5.3)", :aggregate_failures do
  foreign = create(:deck, account: create(:user).account)
  [ deck.location_id, foreign.zone("main").id, "12abc" ].each do |id|
    patch scanner_sitting_path, params: { sitting: { location_id: id } }, as: :turbo_stream
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("That location isn&#39;t one of yours any more. Choose again.").or include("That location isn't one of yours any more. Choose again.")
  end
  expect(account.scanner_sitting).to be_nil
end

it "unplaces a sitting whose zone goes with a removed deck (AC-5.4)", :aggregate_failures do
  Scanner::Sitting.choose!(account:, location: deck.zone("main"))
  deck.remove!
  expect(account.reload.scanner_sitting.location_id).to be_nil
end
```

  (`deck`, `account` as the file defines them; the sitting picker examples there show the way to read the panel's HTML. `deck.remove!` works because the deck is empty.)
- [ ] Also rewrite what Phase 4 makes false:
  - `spec/models/number_entry/line_form_spec.rb` about lines 151–155 (calls `#locations`): use `#choices.places` / `#choices.any?`.
  - `spec/requests/number_entries_spec.rb` about lines 329–338 (a zone's id is refused): a zone's id is added to; keep the refusal for a deck's own row and another account's zone. Its AC-5.8a example (deck and no place: no select) now expects the select with the Decks group only.
  - `spec/requests/scanner/sittings_spec.rb` about lines 349–354 (AC-5.8a: a deck-only account has no control) and 356–365 (a zone's id is refused): the control is there with the Decks group; a zone's id is accepted; keep the 422 for a deck's own row.
  - Extend the "adds into the zone" example to check the list's line reads "in Izzet Tempo › Main" and that the line's Undo removes the copies and keeps the lot's zone for the rest (spec 062 AC-5.7 is re-proved), and check the sitting panel's select in each state (none open, open, after "Set") for AC-5.1.
- [ ] Run `bin/rspec spec/models/number_entry/line_form_spec.rb spec/requests/number_entries_spec.rb spec/requests/scanner/sittings_spec.rb`. Expected: new examples fail.
- [ ] Commit: `test(entry): spec 065 examples for zones in number entry and the scanner sitting (#252)`.

### Task 4.2: Number entry and the sitting offer zones

- [ ] `app/models/number_entry/line_form.rb`: replace `locations` and `location_record`:

```ruby
  # What the Location select offers (spec 065 decisions 2, 8): the account's places and the zones of its decks; nothing for a
  # form without an account. A deck's own row and another account's ids are not among them, so they are the field's error too.
  def choices = @choices ||= Location::Choices.new(account)

  # The place or zone the field names, when it is one of the account's (spec 034 decision 5).
  def location_record = choices.find(location.to_s.strip)
```

  Update the comment on `location_known` if it says "places".
- [ ] `app/views/collections/number_entries/_line_form.html.erb`: `<% if line.choices.any? %>` and
  `select_tag "line[location]", location_options(line.choices, selected: line.location_record&.id.to_s, leading: [ [ "No location", "" ] ]), id: …` keeping the other attributes.
- [ ] `app/controllers/concerns/scanner_sitting.rb`: `sitting_locals` hash key `locations: account_locations` → `choices: account_choices`; replace `account_locations` with

```ruby
    # What the sitting's Location select offers, read once per request (spec 065 decision 8): the account's places and zones.
    def account_choices = @account_choices ||= Location::Choices.new(Current.account)
```

  and fix the module header comment's "The account's locations come along for the sitting's place".
- [ ] `app/controllers/scanner/sittings_controller.rb`: lookup `location = Current.account.locations.placeable.includes(:parent).find_by(id: value) if value.match?(/\A\d+\z/)` (the digits guard already keeps "12abc" from being cast) with the comment saying a deck's own row is not a place; `chosen_message`: `if account_choices.any?` and `"in #{sitting.location.label}"`; header comment "a place among the account's places" → "a place or a zone among the account's".
- [ ] `app/helpers/scanners_helper.rb#sitting_choices`: `"in #{sitting.location.label}"`. A label needs the zone's parent, so `sitting_locals` hands the sitting its location from the one read instead of letting the association load it (decision 1: a label costs no further query):

```ruby
    def sitting_locals(sitting = Current.account.scanner_sitting)
      sitting.association(:location).target = account_choices.find(sitting.location_id) if sitting&.location_id
      { sitting:, entries: sitting ? sitting.kept_entries.to_a : [], conditions: scanner_conditions, choices: account_choices,
        added_any: sitting.present? && sitting.entries.exists? }
    end
```

  (This replaces the `sitting_locals` line change above; `find` returns nil for a location that is gone, which leaves the association to load lazily and read nil.)
- [ ] `app/views/scanners/_picker.html.erb` (`locals: (condition:, location_id:, conditions:, choices:)`): `<% if choices.any? %>` and `form.select :location_id, location_options(choices, selected: location_id.to_s, leading: [ [ "No location", "" ] ])`. In `_sitting.html.erb`, `_summary.html.erb` and `_scanner.html.erb` rename the local `locations` to `choices` in the `locals:` line and every `render "scanners/…", …, locations:` call (`git grep -n 'locations' app/views/scanners` shows them all; `app/controllers/scanner/measurements_controller.rb` and `scanners_controller.rb` pass `sitting_locals(...)` as a whole, so need no change).
- [ ] Run `bin/rspec spec/models/number_entry spec/requests/number_entries_spec.rb spec/requests/scanner spec/requests/scanners_spec.rb spec/number_entry_core_spec.rb spec/scanner_sitting_core_spec.rb`. Expected: pass.
- [ ] Commit: `feat(entry): number entry and the scanner sitting offer deck zones (#252)`.

## Phase 5: The collection filter

**Implements:** FR-3, decisions 4, 5, 9, 12, 13 | **Satisfies:** AC-6.1–AC-6.11, AC-7.1, AC-8.1 (filter side)
**Files:** `app/models/collection_filter/place.rb`, `app/models/collection_filter.rb`, `app/views/collections/_location_select.html.erb`, `app/views/collections/_no_match.html.erb`, `app/models/collection_grid.rb` (comment), `spec/models/collection_filter/place_spec.rb`, `spec/requests/collection_location_select_spec.rb`, `spec/requests/bulk_zone_filter_spec.rb`, `spec/requests/collection_deck_filter_spec.rb` (new), `spec/requests/collection_places_spec.rb`, `spec/requests/query_counts_spec.rb`
**Interfaces:** `CollectionFilter::Place::DECK` (`/\Adeck:([1-9]\d{0,17})\z/`), `.deck_value(id)`, `.parse` accepting it, `.apply` turning it into a predicate on the account's lots; `CollectionFilter#chosen_location` returns a place, a zone or a deck's location (all with the right `label`).

### Task 5.1: Failing examples

- [ ] `spec/models/collection_filter/place_spec.rb` (read the existing file and add inside it):

```ruby
describe "the deck value (spec 065 decision 4)" do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }

  it "parses deck:<id> and refuses malformed ones", :aggregate_failures do
    expect(described_class.parse("deck:12")).to eq("deck:12")
    expect([ "deck:", "deck:012", "deck:12abc", "Deck:12", " deck:12", "deck:#{'9' * 19}" ].map { described_class.parse(it) }).to all(eq(""))
  end

  it "matches the lots in any zone of the deck and no other lot", :aggregate_failures do
    entry = create(:mtg_printing).entry
    main = create(:lot, account:, entry:, location: deck.zone("main"))
    side = create(:lot, account:, entry:, finish: "foil", location: deck.zone("sideboard"))
    elsewhere = create(:lot, account:, entry:, condition: "near_mint", location: create(:location, account:))
    unplaced = create(:lot, account:, entry:, condition: "played")
    other_deck = create(:deck, account:, name: "Other")
    stray = create(:lot, account:, entry:, condition: "heavily_played", location: other_deck.zone("main"))
    scope = described_class.apply(account.lots, described_class.deck_value(deck.location_id))
    expect(scope).to contain_exactly(main, side)
    expect([ elsewhere, unplaced, stray ]).to all(satisfy { !scope.include?(it) })
  end

  it "matches no lot of the account for another account's deck id" do
    foreign = create(:deck, account: create(:user).account)
    create(:lot, account:, entry: create(:mtg_printing).entry)
    expect(described_class.apply(account.lots, described_class.deck_value(foreign.location_id))).to be_empty
  end
end
```

  (Use the condition and finish values the lot factory and vocabulary accept; `spec/factories/lots.rb` shows them.)
- [ ] Create `spec/requests/collection_deck_filter_spec.rb` (`type: :request`, the helpers `owned_printing`, `create_lot_in_zone`, `sign_in_as`):

```ruby
require "rails_helper"

# Spec 065 Story 6: the collection's Location select offers zones and "<Deck> (all zones)", and filters by them.
RSpec.describe "The collection's location filter with decks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let!(:box) { create(:location, account:, name: "Long box") }
  let!(:in_main) { owned_printing("Lightning Bolt", account:, number: "146", location: deck.zone("main")) }
  let!(:in_side) { owned_printing("Counterspell", account:, number: "50", location: deck.zone("sideboard")) }
  let!(:in_box) { owned_printing("Opt", account:, number: "60", location: box) }
  let!(:loose) { owned_printing("Shock", account:, number: "70") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)
  def select = page_html.at_css('select[name="location"]')
  def names = page_html.css(".c-tile__name").map { it.text.squish } # the grid is the default view
  def deck_value = CollectionFilter::Place.deck_value(deck.location_id)

  it "lists All locations and No location, then Places, then Decks with each deck's all-zones option first (AC-6.1)", :aggregate_failures do
    get collection_path
    expect(select.xpath("./option").map(&:text)).to eq([ "All locations", "No location" ])
    expect(select.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
    expect(select.css('optgroup[label="Decks"] option').map(&:text)).to eq([ "Izzet Tempo (all zones)", *deck.zones.map { "Izzet Tempo › #{it.name}" } ])
    expect(select.css('optgroup[label="Decks"] option').first["value"]).to eq(deck_value)
  end

  it "is flat with no deck (AC-6.1)", :aggregate_failures do
    account.decks.each { |d| d.zones.each { |z| z.lots.destroy_all } }
    account.decks.each(&:remove!)
    get collection_path
    expect(select.css("optgroup")).to be_empty
  end

  it "narrows to one zone: its lots, quantities and count, no place line (AC-6.2)", :aggregate_failures do
    get collection_path(location: deck.zone("main").id)
    expect(names).to eq([ "Lightning Bolt" ])
    expect(page_html.css(".c-tile__place-name")).to be_empty
    expect(response.body).to include("1 of 4 items")
    expect(select.at_css("option[selected]").text).to eq("Izzet Tempo › Main")
  end

  it "narrows to every zone of a deck, tiles with no place line, rows with each zone (AC-6.3)", :aggregate_failures do
    get collection_path(location: deck_value)
    expect(names).to contain_exactly("Lightning Bolt", "Counterspell")
    expect(page_html.css(".c-tile__place-name")).to be_empty
    get collection_path(location: deck_value, view: "table")
    expect(page_html.css("tbody .c-table__place-name").map { it.text.squish }).to contain_exactly("Izzet Tempo › Main", "Izzet Tempo › Sideboard")
    expect(select.at_css("option[selected]").text).to eq("Izzet Tempo (all zones)")
  end

  it "says so when a zone or a deck holds nothing (AC-6.4)", :aggregate_failures do
    get collection_path(location: deck.zone("considering").id)
    expect(response.body).to include("No cards in your collection are in “Izzet Tempo › Considering”.")
    in_side.destroy!
    in_main.destroy!
    get collection_path(location: deck_value)
    expect(response.body).to include("No cards in your collection are in “Izzet Tempo”.")
    get collection_path(location: deck_value, q: "zzz")
    expect(response.body).to include('No cards in your collection match "zzz" in “Izzet Tempo”.')
  end

  it "reads anything it can't resolve as all, naming nothing of another account (AC-6.5, AC-8.1)", :aggregate_failures do
    foreign = create(:deck, account: create(:user).account, name: "Secret deck")
    values = [ foreign.zone("main").id.to_s, "deck:#{foreign.location_id}", deck.location_id.to_s, "deck:#{deck.zone('main').id}",
               "deck:99999", "deck:", "deck:0#{deck.location_id}", "012", "x" ]
    values.each do |value|
      get collection_path(location: value)
      expect(response).to have_http_status(:ok), value
      expect(select.at_css("option[selected]").text).to eq("All locations"), value
      expect(names.size).to eq(4), value
      expect(response.body).not_to include("Secret deck")
    end
  end

  it "keeps the filter through the view switch, a sort header and Edit many, and doesn't save it (AC-6.6)", :aggregate_failures do
    get collection_path(location: deck_value, view: "table")
    expect(page_html.css("a, form, input").map { [ it["href"], it["action"], it["value"] ] }.flatten.compact.join(" ")).to include("deck%3A#{deck.location_id}").or include("deck:#{deck.location_id}")
    get collection_path
    expect(select.at_css("option[selected]").text).to eq("All locations")
  end

  it "gives an account with a deck and no place the select, the column and the place line (AC-6.10)", :aggregate_failures do
    solo = create(:user)
    sign_in_as(solo)
    create(:deck, account: solo.account)
    owned_printing("Opt", account: solo.account, number: "60")
    get collection_path
    expect(select).not_to be_nil
    get collection_path(view: "table")
    expect(page_html.css("thead th").map { it.text.squish }).to include("Location")
  end

  it "escapes a deck's name in the options and sentences (AC-6.9)", :aggregate_failures do
    odd = create(:deck, account:, name: "A <i>&\" deck")
    get collection_path(location: CollectionFilter::Place.deck_value(odd.location_id))
    expect(response.body).not_to include("<i>")
    expect(response.body).to include("A &lt;i&gt;&amp;&quot; deck")
  end
end
```

  `account.decks.each …` in the flat example relies on `Account has_many :decks`; zones' `lots` association: `Location has_many :lots`. Adapt a name or two to the helpers' real signatures when the red run shows them (`owned_printing` takes `location:`; read `spec/support` around line 513 for its options).
- [ ] Bulk examples in the same file (AC-6.7, AC-6.8, AC-6.11):

```ruby
describe "bulk mode under a zone or a deck (AC-6.7, AC-6.8, AC-6.11)" do
  def select_under(filter, *lots, go:)
    post collection_selection_path, params: { location: filter }
    patch collection_selection_path, params: { go:, q: "", rendered_q: "", rendered_location: filter, all_rendered: "0",
      shown_ids: lots.map(&:id), ticked_ids: lots.map(&:id) }
  end

  it "sets a condition on exactly the deck's lots; a lot outside it whose id is sent is ignored", :aggregate_failures do
    lots = [ in_main, in_side ]
    outsider = in_box
    select_under(deck_value, *lots, outsider, go: "set_condition")
    post collection_condition_change_path, params: { condition: "lightly_played" }
    expect(lots.map { it.reload.condition }).to eq(%w[lightly_played lightly_played])
    expect(outsider.reload.condition).not_to eq("lightly_played")
  end

  it "restarts the selection empty after a move to another zone of the same deck (decision 12)", :aggregate_failures do
    lot = in_main
    select_under(deck_value, lot, go: "move")
    post collection_move_path, params: { to: deck.zone("sideboard").id }
    expect(response).to have_http_status(:see_other)
    expect(flash[:notice]).to eq("Moved 1 item to Izzet Tempo › Sideboard.")
    expect(lot.reload.location).to eq(deck.zone("sideboard"))
    follow_redirect!
    expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
  end

  it "moves lots selected under a deck's value to a place (AC-3.4)", :aggregate_failures do
    lots = [ in_main, in_side ]
    select_under(deck_value, *lots, go: "move")
    post collection_move_path, params: { to: box.id }
    expect(response).to have_http_status(:see_other)
    expect(lots.map { it.reload.location }).to all(eq(box))
  end

  it "removes exactly the deck's lots when every matching lot is selected (AC-6.7)", :aggregate_failures do
    post collection_selection_path, params: { location: deck_value }
    patch collection_selection_path, params: { go: "remove", q: "", rendered_q: "", rendered_location: deck_value, all_rendered: "1", all: "1", shown_ids: [ in_main.id, in_side.id ], ticked_ids: [ in_main.id, in_side.id ] }
    delete collection_bulk_removal_path
    expect(account.lots.pluck(:id)).to contain_exactly(in_box.id, loose.id)
  end

  it "shows nothing selected when the value changes between the page and the action (AC-6.7)", :aggregate_failures do
    post collection_selection_path, params: { location: deck_value }
    get collection_path(bulk: 1, location: deck.zone("main").id)
    expect(page_html.css("tbody tr[aria-selected=true]")).to be_empty
  end

  it "acts on nothing under a deck that was removed in another tab (AC-6.8)", :aggregate_failures do
    ghost = create(:deck, account:, name: "Ghost")
    select_under(CollectionFilter::Place.deck_value(ghost.location_id), in_main, go: "remove")
    ghost.remove!
    post collection_selection_path, params: { location: CollectionFilter::Place.deck_value(ghost.location_id) }
    patch collection_selection_path, params: { go: "remove", q: "", rendered_q: "", rendered_location: CollectionFilter::Place.deck_value(ghost.location_id), all_rendered: "1", all: "1" }
    expect(response.body).to include("None of the selected items are in your collection any more.")
    expect(account.lots.count).to eq(4)
  end
end
```

  Adapt `select_under` and the removal sequence to `bulk_zone_filter_spec.rb`'s own helper and its examples (same requests; read it first). `owned_printing` returns the Lot (`zone_place_label_spec.rb` reads `zone_lot.entry`), so `in_main`, `in_side`, `in_box` and `loose` are lots.
- [ ] `spec/requests/bulk_zone_filter_spec.rb`: its header says a zone's id or a deck's id can only be stored by a crafted request because the page offers places only. Update the header and the first example: a zone's id now is a filter value (the page shows it selected and filters to it), a deck's own id without the prefix is still all. The other examples (stored selection acts on the zone's lots, never unplaces) stay as they are, and stay true.
- [ ] `spec/requests/collection_location_select_spec.rb`: replace the `describe "with a deck (spec 062)"` AC-5.1 example with the grouped expectation and the AC-5.2 example with: a zone's id shows that zone selected, a deck's own id reads as all.
- [ ] `spec/requests/collection_places_spec.rb`: about line 255 (a place and a deck, "shows the select with places only…"): the flat list gains the Decks group; about line 266 (a deck with no lot in a zone: no column, no select) is superseded by decision 3: it now shows both (AC-6.10).
- [ ] Specs that call removed methods or assert the old resolution: `spec/models/collection_grid_spec.rb` (about lines 55, 164, 167 call `places?`) and `spec/models/collection_table_spec.rb` (about lines 105–109 and 135 call `places?` and `filter.locations`): use `choices?` and `choices.places`; line 135's "one statement" still holds. `spec/requests/collection_location_filter_spec.rb` about lines 258–266 ("reads a zone's id and a deck's id as all"): a zone's id is a value now; keep the deck's own id as all.
- [ ] `spec/requests/query_counts_spec.rb`: add an example that a collection page (grid and table) of an account with one place and three decks issues no more statements than the same page with the decks removed plus none for the decks (the decks are read by the one `Location::Choices` statement the filter already made): follow the file's `queries_for(path)` helper.
- [ ] The query-count example is a regression proof (the old filter also made one read of the account's locations), not a red-first one; say so in a comment on it.
- [ ] Run `bin/rspec spec/models/collection_filter spec/requests/collection_deck_filter_spec.rb spec/requests/bulk_zone_filter_spec.rb spec/requests/collection_location_select_spec.rb spec/requests/collection_places_spec.rb spec/requests/query_counts_spec.rb`. Expected: the new and rewritten examples fail.
- [ ] Commit: `test(filter): spec 065 examples for zones and deck:<id> in the collection filter (#252)`.

### Task 5.2: The filter value, the select and the sentences

- [ ] Stale comment: `app/models/bulk_selection.rb` (about line 43) says the location is "`""`, `"none"` or an id": add `deck:<id>`.
- [ ] `app/models/collection_filter/place.rb`:

```ruby
module CollectionFilter::Place
  NONE = "none".freeze
  ID = /\A[1-9]\d{0,17}\z/ # at most 18 digits: a longer id would overflow SQLite's 64-bit bind (spec 037 0.2.2)
  # A whole deck: `deck:` and its location's id, at most 18 digits (spec 065 decision 4).
  DECK = /\Adeck:([1-9]\d{0,17})\z/

  # The value of the "<Deck> (all zones)" option.
  #
  # @param id [Integer] the deck's location id
  # @return [String]
  def self.deck_value(id) = "deck:#{id}"

  # Anything that isn't "none", an id or `deck:<id>` (a non-string, "017", " 17", "17abc", "deck:") is "".
  def self.parse(raw) = raw.is_a?(String) && (raw == NONE || raw.match?(ID) || raw.match?(DECK)) ? raw : ""

  # A plain predicate on the lots' own column: another account's or a removed id matches no lot of this account's. A deck's value
  # matches the lots in its zones; the subquery is tied to the lot's own account, so another account's deck id matches nothing
  # even if it were applied to a wider relation (spec 065 AC-8.4).
  #
  # @param scope [ActiveRecord::Relation] the account's lots
  # @param place [String] a parsed value
  def self.apply(scope, place)
    case place
    when "" then scope
    when NONE then scope.where(location_id: nil)
    when DECK then scope.where(location_id: zones_of(place.match(DECK)[1].to_i))
    else scope.where(location_id: place.to_i)
    end
  end

  # The ids of a deck's zones, correlated to the lot's account.
  def self.zones_of(deck_id)
    Location.zones_of_decks.where(parent_id: deck_id).where(Location.arel_table[:account_id].eq(Lot.arel_table[:account_id])).select(:id)
  end
  private_class_method :zones_of
end
```

  (Keep the existing header comment, extended: the canonical values are now `""`, `"none"`, an id and `deck:<id>`.)
- [ ] `app/models/collection_filter.rb`: delete `locations` and `places?` (their callers moved in Task 3.2 and below); keep `choices`/`choices?`; replace `place_column?`, `chosen_location`, `resolved_location` with

```ruby
  # Whether a lot's place is shown, on the tile's line, the table's Location column and the phone line: the account has a place
  # or a zone (spec 065 decision 3; supersedes spec 062 AC-5.8a, so no second read is made for an account with no place).
  def place_column? = choices?

  # The location filter as the page shows and queries it: "" unless the account has a place or a zone and the value is "none" or
  # names one of its own (spec 037 decisions 6 and 7; spec 065 decision 4).
  def location = @location ||= resolved_location

  # The place, zone or deck the filter names, nil for all and none; a zone's label reads "Deck › Zone".
  def chosen_location = (choice_for(location) unless location.in?([ "", Place::NONE ]))
```

  and in `private`:

```ruby
    def resolved_location
      requested = @requested_location.to_s
      return "" unless choices?

      requested == Place::NONE || choice_for(requested) ? requested : ""
    end

    # The location a canonical value names among the account's choices (never a deck's own id without its prefix, never a zone's
    # id with one).
    def choice_for(value)
      match = Place::DECK.match(value)
      match ? choices.deck(match[1])&.location : choices.find(value)
    end
```

  Update the file's comments that say "Places only" and the module header (`@requested_location`).
- [ ] `app/views/collections/_location_select.html.erb`:

```erb
<label class="c-select c-select--wide"><span class="c-sr">Location</span><%= select_tag :location,
      location_options(listing.choices, selected: listing.location, leading: [ [ "All locations", "" ], [ "No location", CollectionFilter::Place::NONE ] ], deck_values: true),
      form:, id: nil %></label>
```

  (keep the file's comment, saying all, none, then Places and Decks).
- [ ] `app/views/collections/_no_match.html.erb`: replace both `listing.chosen_location.name` with `listing.chosen_location.label` (a deck's label is its name; a zone's is "Deck › Zone").
- [ ] `app/models/collection_grid.rb#places_of` comment: "Nil for every printing while the account has no place and no lot in a zone (spec 062 AC-5.8a)" → "…while the account has no place and no deck (spec 065 decision 3)"; the condition is `place_column? && location.empty?` and stays.
- [ ] Run the Task 5.1 spec files, then `bin/rspec spec/models/collection_grid_spec.rb spec/models/collection_table_spec.rb spec/requests/collection_table_spec.rb spec/requests/collections_spec.rb spec/requests/bulk_mode_spec.rb spec/requests/bulk_condition_spec.rb spec/requests/bulk_removal_spec.rb spec/requests/collection_location_filter_spec.rb spec/requests/collection_location_filter_timing_spec.rb spec/requests/zone_place_label_spec.rb`. Expected: pass. If a count in `collection_location_filter_timing_spec.rb` or a query count moves, the cause is the dropped `place_column?` read (one fewer): update the expected number with a comment citing spec 065 AC-8.2.
- [ ] Commit: `feat(filter): the collection filter offers deck zones and Deck (all zones) (#252)`.

## Phase 6: Cross-cutting proofs, documents and screenshots

**Implements:** Stories 7, 8 | **Satisfies:** AC-7.1, AC-8.1, AC-8.2, AC-8.3, AC-8.5, and the spec's "Updates" list
**Files:** `spec/requests/deck_zone_pickers_spec.rb` (new), `docs/specs/README.md`, `docs/architecture/collection-and-lots.md`, `docs/architecture/scanner.md`, `docs/design-system/README.md`, `docs/design-system/components/Form.md`, `FilterSelect.md`, `DecksIndex.md`, `docs/specs/065-deck-zones-in-pickers/verification.md`, `docs/specs/065-deck-zones-in-pickers/screenshots/`

### Task 6.1: The cross-surface examples

- [ ] Create `spec/requests/deck_zone_pickers_spec.rb`:

```ruby
require "rails_helper"

# Spec 065 AC-7.1, AC-8.1, AC-8.5: a copy put into a zone by each picker is shown as "Deck › Zone" on the collection page, no
# picker names another account's place, deck or zone, and the export still writes the zone by deck and key.
RSpec.describe "Deck zones in the pickers, across surfaces", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:rival) { create(:user) }
  let!(:rival_deck) { create(:deck, account: rival.account, name: "Rival deck") }
  let!(:rival_box) { create(:location, account: rival.account, name: "Rival box") }
  let(:entry) { create(:mtg_printing).entry }
  let(:zone) { deck.zone("main") }

  before { sign_in_as(user) }

  def page_html = Nokogiri::HTML5(response.body)

  it "shows a copy put into a zone by the lot form, number entry and the scanner as Deck › Zone on the collection page (AC-7.1)", :aggregate_failures do
    post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", location_id: zone.id } }
    second = create(:mtg_printing, name: "Second Card").entry
    post collection_number_entry_lines_path, params: { line: { set: second.set.code, number: second.number, quantity: "1", finish: "nonfoil", location: zone.id, line_key: SecureRandom.hex(16) }, type: "mtg", language: second.language }
    third = create(:mtg_printing, name: "Third Card").entry
    patch scanner_sitting_path, params: { sitting: { location_id: zone.id } }, as: :turbo_stream
    post scanner_sitting_entries_path, params: { entry: { printing: third.external_key, finish: "nonfoil", reading_key: SecureRandom.hex(16) } }, as: :turbo_stream
    get collection_path(view: "table")
    expect(page_html.css("tbody .c-table__place-name").map { it.text.squish }).to eq([ "Izzet Tempo › Main" ] * 3)
    expect(page_html.css("tbody .c-table__sub").map(&:text).join).to include("Izzet Tempo › Main")
  end

  it "names none of another account's locations on any picker, and refuses their ids (AC-8.1)", :aggregate_failures do
    lot = create(:lot, account:, entry:, location: create(:location, account:))
    pages = [ new_catalog_entry_lot_path(entry), edit_lot_path(lot), new_lot_move_path(lot), collection_path, scanner_path ]
    pages.each do |path|
      get path
      expect(response.body).not_to include("Rival"), path
    end
    post collection_selection_path
    patch collection_selection_path, params: { go: "move", q: "", rendered_q: "", rendered_location: "", all_rendered: "0", shown_ids: [ lot.id ], ticked_ids: [ lot.id ] }
    get new_collection_move_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Rival")
    [ rival_deck.zone("main").id, rival_deck.location_id, rival_box.id ].each do |id|
      post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", location_id: id } }
      expect(response).to have_http_status(:not_found)
      post lot_move_path(lot), params: { move: { copies: "1", location_id: id } }
      expect(response).to have_http_status(:not_found)
    end
    expect(account.lots.count).to eq(1)
  end

  it "keeps the export's locations to places and writes a lot in a zone by deck and key (AC-8.5)", :aggregate_failures do
    create(:lot, account:, entry:, location: zone)
    data = CollectionExport.new(account:, at: Time.current).to_h
    expect(data["locations"]).to eq([])
    expect(data["lots"].sole["location"]).to eq({ "deck" => "Izzet Tempo", "zone" => "main" })
  end
end
```

  The number-entry and scanner requests above copy the parameter shapes of `spec/requests/number_entries_spec.rb` and `spec/requests/scanner/sittings/entries_spec.rb` (read the neighbouring examples and use their exact params, finish values and route helpers: the names above are what those files use at the time of writing). `CollectionExport.new(account:, at:).to_h` is the entry point; the `data["lots"]` key names are in the format document. Expected: pass at once (the behaviour exists after Phases 2–5); these examples, and the query-count example of Task 5.1 (the filter read the same one statement for places before), are regression proofs added last, so they cannot "fail first": record that in `verification.md`.
- [ ] Commit: `test(pickers): spec 065 cross-surface examples for labels, tenancy and the export (#252)`.

### Task 6.2: Area docs and design-system docs

- [ ] `docs/architecture/collection-and-lots.md` (keep to the sections about pickers, the filter and the label; the #251 worker edits the deck sections):
  - Scope bullets: add spec 065 to the lot form, Move copies, bulk Move to…, number entry and the collection page bullets' source lists, and name `Location::Choices`, `LocationChoicesHelper` and `Location.placeable`.
  - Glossary "Location filter": values are `""`, `none`, an id of a place or a zone, or `deck:<id>` (a whole deck), and unknown values read as all (`CollectionFilter::Place`; spec 065 decision 4). "Destination": a place, a zone or none.
  - Invariants: replace "A lot is in one of its account's places or zones…" so the forms and Move look the place up through `placeable` (404 for a deck's own row and another account's); replace "Every list of locations says which kind it means" so it says: the Locations page, its counts, the export's `locations`, the import's held and file locations are places only; **every picker and the filter now list places and zones through `Location::Choices`, on purpose widening what spec 062 decision 1 kept to places only until #252 (spec 065 decision 1)**, and a write names its location through `Location.placeable`; add that a copy that reaches a zone through a picker never changes a proxy (spec 065 decision 11; proxies come with #254). Update "No path unplaces a lot in a zone by accident" (Edit copy shows the select with the zone chosen; Move copies and bulk Move to… offer zones and places and "No location"). Update the queries bullet (the filter's and the pickers' one read; `place_column?` makes no second read).
  - States tables: the "Edit copy" row (select with the zone chosen, no read-only text), Move copies' To field, "Add a copy"'s Location field and the paragraph under the table (gate: a place or a zone), the location filter bullet (groups, "Deck (all zones)", sentences, tiles show no place line under any filter, the table shows each zone), the place line bullet (gate), Move to… (offered while the account has a place or a zone; groups; own place or zone left out), number entry's line (Location groups), and every "#252" sentence: the deck refusal page's missing bulk-mode shortcut is "not built; a follow-up".
  - Sources: spec 065 and issue #252.
- [ ] `docs/architecture/scanner.md`: the sitting's "Location select" (line about "None open" and the "Set" paragraph): "No location" first, then Places and Decks (zones as "Deck › Zone"), shown while the account has a place or a zone; the 422 sentence also covers a deck's own row; the answer's "in <place>" names the label. Sources: spec 065.
- [ ] `docs/design-system/README.md` ("What is live", line about the grouped picker, the App additions line): the grouped picker, "Deck (all zones)" and the zone label are live (spec 065); `c-field__static` is gone. `components/Form.md`: drop "not built until #252" and the "A read-only value" bullet; the Location picker bullet is now what the app does. `FilterSelect.md`: unchanged unless a sentence says "when built". `DecksIndex.md` line about `.c-field__static`: remove it from the CSS list. Confirm nothing else mentions `c-field__static` (`git grep`).
- [ ] `docs/specs/README.md`: row 065 stays Approved (distillation marks it later); add to 062's "Superseded by" cell: `065: AC-5.1, AC-5.2, AC-5.5, AC-5.6, AC-5.7a, AC-5.8a, decision 1's places-only surface list, decision 6's read-only field`, and to 037, 040, 041 and 034's cells the matching entries from the spec's "Supersedes" list, each citing spec 065.
- [ ] Run the guard specs that read these docs only by existing means (`bin/rspec spec/requests/design_system_spec.rb`), then `bin/yard doc` is run by CI (no `{…}` in the new comments: check `git grep -n '{' app/models/location/choices.rb app/helpers/location_choices_helper.rb` for stray braces outside code).
- [ ] Commit: `docs: area docs and design system for deck zones in the pickers (#252)` (the area docs and the design-system docs may be two commits).

### Task 6.3: Before and after screenshots

- [ ] Follow `.claude/memory/pr-screenshots-workflow.md` and `.claude/memory/headless-firefox-narrow-frame.md`: "before" shots from `main` (checkout a second worktree state, or `git stash`-free: run the app from `origin/main` is not allowed in this worktree, so take "before" from the design previews and from a build of `origin/main` in a throwaway worktree under the scratchpad), "after" from this branch, with one runner script in its own call that seeds an account with a place, a deck "Izzet Tempo", a lot in its Main and one in a box. Shots (1280px and a 390px frame in light; the lot form's select open or its option list read as text, the collection filter bar, the scanner sitting panel, the Move to… page) saved under `docs/specs/065-deck-zones-in-pickers/screenshots/`. The headless browser can't draw a native open select, so the shots show the closed select and the options are listed in the PR text from the page's HTML.
- [ ] Commit: `docs(specs): screenshots for spec 065 (#252)`.

### Task 6.4: Verification

- [ ] `bin/rubocop -a` on the changed Ruby, `bin/rspec` for every file changed in the branch (`git diff --name-only origin/main -- spec`), `bin/rspec --dry-run` count for the PR. The full `bin/ci` is the coordinator's slot, asked for once before the push.
- [ ] `verification.md` records, per AC, the example that proves it (file and example name), the AC-8.x examples added after the code (Task 6.1) as regression proofs, the screenshots, and the implementation review (Mode B, Opus, read-only) under `## Implementation review` with its verdict on the first line.

## Integration Verification

1. As a collector with a place and a deck "Izzet Tempo" (format Modern): open Add a copy, choose "Izzet Tempo › Main", submit; the card page's "Your copies" reads "Izzet Tempo › Main".
2. On that row choose Move copies: To offers No location, Places and Decks without Main; move to "Izzet Tempo › Sideboard".
3. Collection page: choose "Izzet Tempo (all zones)" and Filter; the grid shows the card; the table shows "Izzet Tempo › Sideboard"; Edit many, select all, Move to… "Izzet Tempo › Main".
4. Add by number into Main; scan with the sitting set to Main (`/scanner`): the notice names "Izzet Tempo › Main".
5. A second account sees none of it.

## Spec coverage

| Spec | Phase / task |
|---|---|
| FR-1 | 1.2 |
| FR-2 | 2.2 (lot form, Move copies), 3.2 (bulk Move to…), 4.2 (number entry, sitting) |
| FR-3 | 5.2 |
| FR-4 | 2.2, 3.2, 4.2, 5.2 (labels in notices and sentences) |
| AC-1.1–1.8 | 2.1, 2.2 |
| AC-2.1–2.4 | 2.1, 2.2 |
| AC-3.1–3.4 | 3.1, 3.2 (the deck half of AC-3.1 and AC-3.4 are in 5.1: they need the filter's `deck:<id>`) |
| AC-4.1–4.4 | 4.1, 4.2 |
| AC-5.1–5.5 | 4.1, 4.2 (AC-5.5 by `spec/scanner_sitting_core_spec.rb` in the run) |
| AC-6.1–6.11 | 5.1, 5.2 |
| AC-7.1 | 6.1 (lot form, number entry, scanner; Move and bulk move are proved by their own phases' label examples) |
| AC-8.1 | 5.1, 6.1 |
| AC-8.2 | 1.1 (one read), 5.1 (query counts) |
| AC-8.3 | 1.2 (guard list), runs in 3.2, 4.2 |
| AC-8.4 | 1.2, every write controller in 2.2, 3.2, 4.2, 5.2 |
| AC-8.5 | 6.1 |

## Complexity tracking

- Simplicity: two new files in the app (`Location::Choices`, `LocationChoicesHelper`) and one scope. No new dependency, table or route. The alternative, a list per controller, is what the spec's decision 1 rejects.
- Anti-abstraction: `Choices` is a plain object over the framework's relations; the helper uses `options_for_select` and `grouped_options_for_select` directly.
- Risk: the number of existing examples that say "places only" (listed per task). Each is rewritten in the red task of its phase, so none is deleted to make a phase green.
