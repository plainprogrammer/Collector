# One account's collection as a collector-export file, format version 2 (spec 022, spec 029, docs/export-format/README.md).
# Collectible-agnostic: every field comes from a core column, and the registry is never asked about a type, so a lot
# of a type the instance no longer has still exports. The lots are read in one statement, one consistent snapshot,
# so a change made during the export can't put two lots of one identity in the file (decision 8).
class CollectionExport
  FORMAT = "collector-export".freeze
  FORMAT_VERSION = 2
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
      "locations" => locations,
      "lots" => lots }
  end

  def to_json(*) = JSON.generate(to_h)

  def filename = "collector-export-#{@at.getutc.to_date.iso8601}.json"

  private
    # The names only, in the order of spec 029 decision 2 (comparison key, then name, in code-point order), so two
    # exports of one collection are the same file apart from their time. One query.
    def locations = @account.locations.ordered.pluck(:name).map { |name| { "name" => name } }

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
    def time(value) = value.getutc.iso8601
end
