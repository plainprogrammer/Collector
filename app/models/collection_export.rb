# One account's collection as a collector-export file, format version 4 (spec 022, spec 029, spec 032, spec 062,
# docs/export-format/README.md). Version 4 adds `decks` (name, collectible type and format: the zones are not written, they
# come from the format) and lets a lot's `location` be a deck's zone, `{ "deck" => name, "zone" => key }`; `locations` stays
# the places only.
# Collectible-agnostic: every field comes from a core column, and the registry is never asked about a type or a format, so a
# lot or a deck of a type the instance no longer has still exports. The lots are read in one statement, one consistent
# snapshot, so a change made during the export can't put two lots of one identity in the file (decision 8).
# @see file:data-portability.md
class CollectionExport
  FORMAT = "collector-export".freeze
  FORMAT_VERSION = 4
  TRIES = 3
  Unsettled = Class.new(StandardError)
  LOT_COLUMNS = [ "catalog_entries.collectible_type", "catalog_entries.external_key", "catalog_entries.name",
    "catalog_sets.code", "catalog_entries.number", "catalog_entries.language", "lots.quantity", "lots.finish",
    "lots.condition", "lots.price_paid_cents", "lots.created_at", "lots.updated_at" ].freeze

  def initialize(account:, at:)
    @account = account
    @at = at
  end

  # The whole export as a Hash ready for JSON: the profile, the currency, the places, the decks and every lot, one consistent
  # read of the account (see `places_decks_and_lots`).
  # @return [Hash{String => Object}] the version 4 document
  # @raise [Unsettled] when the account's places and decks kept changing through every read
  def to_h
    user = @account.user
    locations, decks, lots = places_decks_and_lots
    { "format" => FORMAT, "format_version" => FORMAT_VERSION, "exported_at" => time(@at),
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => @account.currency,
      "locations" => locations,
      "decks" => decks,
      "lots" => lots }
  end

  def to_json(*) = JSON.generate(to_h)

  def filename = "collector-export-#{@at.getutc.to_date.iso8601}.json"

  private
    # The lots, with their place from the same statement, then the places and the decks: the names only for a place, the name,
    # type and format for a deck, in the order of spec 029 decision 2 (comparison key, then name, in code-point order), so two
    # exports of one collection are the same file apart from their time. A rename or a removal of a place or a deck between the
    # two reads leaves a lot naming one the lists lack (spec 032 AC-8.3, spec 062 AC-6.4), and a change of a deck's format
    # leaves a lot in a zone the listed format may lack, so the reads are repeated; a read transaction would hold SQLite's
    # write lock for the whole export.
    def places_decks_and_lots
      TRIES.times do
        rows = lot_rows
        names = @account.locations.places.ordered.pluck(:name)
        decks = @account.decks.listing_order.pluck("locations.name", :collectible_type, :format)
        next unless settled?(rows, names.to_set, decks.to_h { |name, type, format| [ name, [ type, format ] ] })

        return [ names.map { |name| { "name" => name } },
                 decks.map { |name, type, format| { "name" => name, "collectible_type" => type, "format" => format } },
                 rows.map { |row| lot_hash(row) } ]
      end
      raise Unsettled, "the account's locations and decks kept changing while its collection was read"
    end

    # Whether every lot's place is one the lists name: a place by its name, a zone by its deck's name and the deck's type and
    # format as the lot's own statement saw them, which must be the listed deck's.
    def settled?(rows, places, decks)
      rows.all? do |row|
        kind, name, _key, _zone, deck_name, _deck_key, type, format = row.last(Lot::PLACE_COLUMNS.size)
        case kind
        when nil then true
        when "place" then places.include?(name)
        else decks[deck_name] == [ type, format ]
        end
      end
    end

    def lot_rows = @account.lots.joins(entry: :set).with_place.order(:id).pluck(*LOT_COLUMNS, *Lot::PLACE_COLUMNS)

    def lot_hash(row)
      type, source_id, name, set_code, number, language, quantity, finish, condition, cents, added, changed = row.first(LOT_COLUMNS.size)
      kind, place, _key, zone, deck_name = row.last(Lot::PLACE_COLUMNS.size).first(5)
      { "entry" => { "collectible_type" => type, "source_id" => source_id, "name" => name, "set_code" => set_code,
                     "collector_number" => number, "language" => language },
        "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price(cents),
        "location" => Location::Placement.written(kind:, name: place, zone:, deck_name:),
        "added_at" => time(added), "changed_at" => time(changed) }
    end

    # As Lot#price_paid: exact through Rational, two places.
    def price(cents) = cents && format("%.2f", cents / 100r)

    # RFC 3339 in UTC with the fraction dropped, not rounded.
    def time(value) = value.getutc.iso8601
end
