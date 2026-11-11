# One account's collection as a collector-export file, format version 4 (spec 022, spec 029, spec 032, spec 062,
# docs/export-format/README.md). Version 4 adds `decks` (name, collectible type and format: the zones are not written, they
# come from the format) and lets a lot's `location` be a deck's zone, `{ "deck" => name, "zone" => key }`; `locations` stays
# the places only; and `proxies`, the cards a deck's zones need and the collector doesn't own (spec 068): a deck's name, a
# zone's key, the entry, a finish and a quantity, read from `deck_proxies` and never from the lots.
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
  # What a proxy is written from: its entry and set, its finish and quantity, then its zone's key and its deck's name, type and
  # format as the same statement saw them.
  PROXY_COLUMNS = [ "catalog_entries.collectible_type", "catalog_entries.external_key", "catalog_entries.name", "catalog_sets.code",
    "catalog_entries.number", "catalog_entries.language", "deck_proxies.finish", "deck_proxies.quantity",
    "parents.name", "locations.zone", "decks.collectible_type", "decks.format" ].freeze

  def initialize(account:, at:)
    @account = account
    @at = at
  end

  # The whole export as a Hash ready for JSON: the profile, the currency, the places, the decks, the proxies and every lot, one
  # consistent read of the account (see `places_decks_and_lots`).
  # @return [Hash{String => Object}] the version 4 document
  # @raise [Unsettled] when the account's places and decks kept changing through every read
  def to_h
    user = @account.user
    locations, decks, proxies, lots = places_decks_and_lots
    { "format" => FORMAT, "format_version" => FORMAT_VERSION, "exported_at" => time(@at),
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => @account.currency,
      "locations" => locations,
      "decks" => decks,
      "proxies" => proxies,
      "lots" => lots }
  end

  def to_json(*) = JSON.generate(to_h)

  def filename = "collector-export-#{@at.getutc.to_date.iso8601}.json"

  private
    # The lots, with their place from the same statement, then the proxies in one statement of their own, then the places and
    # the decks: the names only for a place, the name, type and format for a deck, in the order of spec 029 decision 2
    # (comparison key, then name, in code-point order), so two exports of one collection are the same file apart from their
    # time. A rename or a removal of a place or a deck between the reads leaves a lot or a proxy naming one the lists lack
    # (spec 032 AC-8.3, spec 062 AC-6.4, spec 068 AC-7.2), and a change of a deck's format leaves a lot in a zone the listed
    # format may lack, so the reads are repeated; a read transaction would hold SQLite's write lock for the whole export.
    def places_decks_and_lots
      TRIES.times do
        rows = lot_rows
        proxies = proxy_rows
        names = @account.locations.places.ordered.pluck(:name)
        decks = @account.decks.listing_order.pluck("locations.name", :collectible_type, :format)
        deck_map = decks.to_h { |name, type, format| [ name, [ type, format ] ] }
        next unless settled?(rows, names.to_set, deck_map) && proxies_settled?(proxies, deck_map)

        return [ names.map { |name| { "name" => name } },
                 decks.map { |name, type, format| { "name" => name, "collectible_type" => type, "format" => format } },
                 proxies.map { |row| proxy_hash(row) },
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

    # Every proxy's deck is one the list names, with the type and format the proxy's own statement saw.
    def proxies_settled?(rows, decks)
      rows.all? { |row| decks[row[8]] == row.last(2) }
    end

    # The proxies, in one statement with their zone, its deck and the entry's set, in the order two exports of one collection
    # share: the deck's comparison key and name, the zone key, the entry's type and source id, the finish (no finish first).
    # A proxy is never a lot: this reads `deck_proxies` only (spec 068 decision 1).
    def proxy_rows
      @account.deck_proxies.joins(entry: :set)
        .joins("JOIN locations ON locations.id = deck_proxies.location_id " \
               "JOIN locations parents ON parents.id = locations.parent_id " \
               "JOIN decks ON decks.location_id = parents.id")
        .order("parents.name_key", "parents.name", "locations.zone", "catalog_entries.collectible_type", "catalog_entries.external_key", "deck_proxies.finish")
        .pluck(*PROXY_COLUMNS)
    end

    def proxy_hash(row)
      type, source_id, name, set_code, number, language, finish, quantity, deck_name, zone = row.first(10)
      { "deck" => deck_name, "zone" => zone,
        "entry" => { "collectible_type" => type, "source_id" => source_id, "name" => name, "set_code" => set_code,
                     "collector_number" => number, "language" => language },
        "finish" => finish, "quantity" => quantity }
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
