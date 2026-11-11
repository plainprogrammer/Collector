# A card a deck's zone needs that the collector doesn't own (spec 068): a printing and a finish with a quantity, in one zone.
# It is never a lot: it is in no count of owned copies, and it changes only by hand (the add, change and remove pages, a
# format change, a deck's removal, an import that carries proxies). One row per zone, printing and finish (the unique index,
# which also holds when the finish is NULL).
#
# The finish and entry rules are creation-time rules (decisions 2, 19): a stored proxy is never revalidated against the
# catalog, so a refresh that changes a printing's finishes leaves its proxies editable and exportable.
# @see file:collection-and-lots.md
class Deck::Proxy < ApplicationRecord
  MAX_QUANTITY = Lot::MAX_QUANTITY
  FULL_MESSAGE = "A zone can hold at most 9,999 proxies of one printing and finish.".freeze
  CHOOSE_A_FINISH = "Choose a finish.".freeze
  FINISH_UNAVAILABLE = "That finish isn't available for this printing.".freeze

  self.table_name = "deck_proxies"

  belongs_to :account
  belongs_to :zone, class_name: "Location", foreign_key: :location_id
  belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

  normalizes :finish, with: ->(value) { value.presence }

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :quantity_within_cap
  validate :zone_is_a_zone_of_the_account, if: :location_id_changed?
  validate :entry_is_of_the_decks_type, on: :create
  validate :finish_is_offered, if: -> { new_record? || finish_changed? }

  # Adds +quantity+ proxies of +entry+ in +finish+ to +zone+: into the proxy that zone already has of that printing and
  # finish (it survives, with the quantities added) or as a new one. All or nothing at the cap. A request that loses a race on
  # the unique index retries once and merges, as `Lot.add!` does.
  #
  # @param account [Account] the signed-in account; the zone must be one of its zones
  # @param zone [Location] a zone of one of the account's decks
  # @param entry [Catalog::Entry]
  # @param finish [String, nil] one of the printing's finishes; nil only for a printing that lists none
  # @param quantity [Integer]
  # @return [Deck::Proxy] the new or the merged proxy
  # @raise [ActiveRecord::RecordInvalid] on any rule above, with the sentence on the attribute (`quantity` for the cap)
  def self.add!(account:, zone:, entry:, finish:, quantity:)
    tries = 0
    begin
      transaction(requires_new: true) { merge_or_create!(account:, zone:, entry:, finish: finish.presence, quantity:) }
    rescue ActiveRecord::RecordNotUnique
      retry if (tries += 1) < 2
      raise
    end
  end

  # (see .add!)
  # @api private
  def self.merge_or_create!(account:, zone:, entry:, finish:, quantity:)
    existing = find_by(account_id: account.id, location_id: zone.id, catalog_entry_id: entry.id, finish:)
    return create!(account:, zone:, entry:, finish:, quantity:) unless existing

    existing.update!(quantity: existing.quantity + quantity)
    existing
  end
  private_class_method :merge_or_create!

  # A quantity as typed: a whole number from 1 to 9,999, or nil (text, a fraction, 0, a negative number, over the cap).
  #
  # @param text [String, nil]
  # @return [Integer, nil]
  def self.parse_quantity(text) = Integer(text.to_s.strip, 10, exception: false)&.then { it if it.between?(1, MAX_QUANTITY) }

  # The finish as the printing's vocabulary labels it, nil for a proxy with none.
  # @return [String, nil]
  def finish_label
    return unless finish

    Catalog.collecting.key?(entry.collectible_type) ? Catalog.collecting_for(entry.collectible_type).finish_label(finish) : finish.humanize
  end

  private
    def quantity_within_cap
      errors.add(:quantity, FULL_MESSAGE) if quantity.to_i > MAX_QUANTITY
    end

    def zone_is_a_zone_of_the_account
      errors.add(:zone, "must be a zone of the account") unless zone&.zone? && zone.account_id == account_id
    end

    # The zone's deck is the one whose collectible the printing must be of (decision 19). A deck row is read through the zone's
    # parent; a zone without one was refused above.
    def entry_is_of_the_decks_type
      deck = zone&.parent&.deck
      errors.add(:entry, "isn't of the deck's collectible") unless deck && entry && deck.collectible_type == entry.collectible_type
    end

    def finish_is_offered
      return if entry.nil?
      return errors.add(:finish, FINISH_UNAVAILABLE) unless Catalog.collecting.key?(entry.collectible_type)

      offered = Catalog.collecting_for(entry.collectible_type).finishes_for(entry)
      if finish.nil?
        errors.add(:finish, CHOOSE_A_FINISH) if offered.any?
      elsif offered.exclude?(finish)
        errors.add(:finish, FINISH_UNAVAILABLE)
      end
    end
end
