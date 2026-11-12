# Copies of one catalog entry with the same finish, condition, price paid and location, owned by an account
# (spec 004 FR-6; the location is part of the identity, spec 032, ADR 0025). Finish and condition are values the collectible's vocabulary defines
# (Catalog.collecting_for); the core doesn't interpret them.
#
# A lot sits in a place or in a zone of a deck (spec 062, ADR 0028), never in a deck's own row: a deck holds copies only through
# its zones. The database can't state that (a foreign key names the table, and SQLite would need a trigger to look at the
# row's kind), so `location_is_the_accounts` does. A zone's id is part of the identity exactly as a place's is.
class Lot < ApplicationRecord
  MAX_QUANTITY = 9_999
  FULL_MESSAGE = "One lot can hold at most 9,999 copies.".freeze

  belongs_to :account
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id
  belongs_to :location, optional: true # nil is unplaced (spec 032 decision 2)

  normalizes :finish, :condition, with: ->(value) { value.presence }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :price_paid_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :quantity_within_cap, :finish_offered, :condition_known
  validate :location_is_the_accounts, if: :location_id_changed? # only a new place is checked: a bulk condition change saves many lots

  # The joins that put a lot's place, and for a zone its deck, on the lot's own row (spec 062 AC-6.4): the place, the place's
  # parent (a zone's deck, nothing for a place) and the parent's `decks` row. `LEFT` joins, so an unplaced lot stays.
  PLACE_JOIN = "LEFT JOIN locations ON locations.id = lots.location_id " \
               "LEFT JOIN locations parents ON parents.id = locations.parent_id " \
               "LEFT JOIN decks ON decks.location_id = parents.id".freeze
  # What a lot's place is made of, in the order `Location::Placement` reads it: the place's kind, name, comparison key and
  # zone key, then its deck's name and comparison key, and the deck's collectible type and format. A reader that plucks these
  # takes them as one slice of the row, `row.last(PLACE_COLUMNS.size)`, and passes them to `Location::Placement`.
  PLACE_COLUMNS = %w[locations.kind locations.name locations.name_key locations.zone parents.name parents.name_key
                     decks.collectible_type decks.format].freeze

  # The lots with their place's own columns and, for a zone, its deck's, from one statement: what the export and the import
  # read, so a lot never names a place the account's lists lack (spec 062 AC-6.4). Pluck {PLACE_COLUMNS} with it; the SQL
  # joins the tables by name, so no other join of the caller may alias `locations`, `parents` or `decks`.
  #
  # @return [ActiveRecord::Relation<Lot>]
  scope :with_place, -> { joins(PLACE_JOIN) }

  # The lots that are free to use: in no deck zone, so unplaced or in a place. A lot in any zone of any deck, Considering
  # included, is in a deck and is not free (spec 057's "Free to use"; spec 070 decision 2). Proxies never change it. Written as
  # "no place or a place" and not as "not in a zone" because `NOT IN` over a NULL location is never true in SQL.
  #
  # Chain it on the account's lots (`account.lots.free`): it names no account itself, and the subselect is over places of any
  # account, which is safe because a lot's place is always its own account's (`location_is_the_accounts`).
  #
  # @return [ActiveRecord::Relation<Lot>]
  scope :free, -> { where(location_id: nil).or(where(location_id: Location.places.select(:id))) }

  before_validation { self.lot_key = self.class.key_for(finish, condition, price_paid_cents, location_id) }

  # The lot's identity as text (ADR 0025): an unplaced lot's key is what it was before locations; a placed lot's ends in the
  # location's id, not its name, so renaming a location keeps every key.
  def self.key_for(finish, condition, price_paid_cents, location_id = nil)
    key = [ finish, condition, price_paid_cents ].join("|")
    location_id ? "#{key}|#{location_id}" : key
  end

  # Adds copies, merging into the lot with the same identity (spec 004 AC-7.4, AC-9.3). SQLite
  # IMMEDIATE transactions serialise writers; the unique index backs that up, and a lost race
  # retries once so it merges instead of failing (AC-12.5).
  def self.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil, location: nil)
    retried = false
    begin
      transaction do
        lot = find_or_initialize_by(account:, entry:, lot_key: key_for(finish.presence, condition.presence, price_paid_cents, location&.id))
        lot.assign_attributes(finish:, condition:, price_paid_cents:, location:, quantity: lot.quantity.to_i + quantity.to_i)
        lot.save!
        lot
      end
    rescue ActiveRecord::RecordNotUnique
      raise if retried

      retried = true
      retry
    end
  end

  def self.owned_quantities(account, entry_ids)
    account.lots.where(catalog_entry_id: entry_ids).group(:catalog_entry_id).sum(:quantity)
  end

  # Edits this lot. If the new identity matches another lot of the same printing, the two merge and
  # the other survives with the summed quantity (spec 004 AC-10.2). Errors always end up on self.
  def revise!(attributes)
    transaction do
      assign_attributes(attributes)
      validate!
      other = self.class.where(account_id:, catalog_entry_id:, lot_key:).where.not(id:).first
      next tap(&:save!) unless other

      other.quantity += quantity
      other.save!
      destroy!
      other
    end
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors) unless error.record == self
    raise ActiveRecord::RecordInvalid, self
  end

  # Where the lot is, for people: nil when unplaced, the place's name, or "Deck › Zone" for a zone. The one reader of a lot's
  # place label (spec 062 decision 6); a list preloads `location: :parent` so it costs no query per lot.
  #
  # @return [String, nil]
  def place_label = location&.label

  def price_paid = price_paid_cents && format("%.2f", price_paid_cents / 100r)

  def vocabulary = Catalog.collecting_for(entry.collectible_type)

  private
    def quantity_within_cap
      errors.add(:quantity, :too_many, message: FULL_MESSAGE) if quantity.to_i > MAX_QUANTITY
    end

    def finish_offered
      errors.add(:finish, "isn't available for this printing") if finish && vocabulary.finishes_for(entry).exclude?(finish)
    end

    def location_is_the_accounts
      errors.add(:location, "isn't one of your locations") if location && (location.account_id != account_id || location.deck?)
    end

    def condition_known
      errors.add(:condition, "isn't a known condition") if condition && vocabulary.conditions.exclude?(condition)
    end
end
