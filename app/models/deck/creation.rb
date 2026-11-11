# The New deck form's object (spec 062 FR-1): checks the name and the format and writes the deck, its location and one zone
# per zone of the format, in one transaction, or writes nothing. The form's value for the format is `<type>/<key>`, the pair
# `Catalog::Formats` registers, because a key is unique within a collectible type only.
#
# Needs no `Current.account`: the account is given. A refusal is `false` with `errors[:name]` (the sentences of
# `Location::MESSAGES` and `Location::FULL`) and/or `errors[:format]`; the form shows `typed` and `format` again.
# @see file:collection-and-lots.md
class Deck::Creation
  include ActiveModel::Model

  CHOOSE_A_FORMAT = "Choose a format.".freeze

  # RecordInvalid looks its message up under the model's i18n scope, and ActiveModel's scope has no such entry.
  def self.i18n_scope = :activerecord

  attr_accessor :account, :name, :format
  # @return [Deck, nil] the deck written by a successful {#save}
  attr_reader :deck

  # The name as it was typed, for a refused form to show again.
  def typed = name.to_s

  # Writes the deck and its zones. The name is checked inside the write transaction (`Location`'s validations count the
  # account's places and decks, and the unique index backs the name), so two creations racing for one name or the last free
  # place leave one deck and one refusal, never an error page and never 501 (AC-1.9). The zones go in with one INSERT,
  # which skips their validations on purpose: their keys and names come from a registration `Catalog::Formats.verify!`
  # checked at boot, and the unique index on (deck, name key) backs them. A failure while writing them rolls the whole
  # creation back and is raised (AC-1.11).
  #
  # @return [Boolean] false when the name or the format is refused; nothing is written then
  def save
    errors.clear
    option = Catalog::Formats.find_pair(format)
    location = Location.new(account:, kind: "deck", name:)
    unless option
      errors.add(:format, CHOOSE_A_FORMAT)
      location.validate
      location.errors[:name].each { errors.add(:name, it) }
      return false
    end

    deck = nil
    Location.transaction do
      unless location.save
        location.errors[:name].each { errors.add(:name, it) }
        raise ActiveRecord::Rollback
      end

      deck = Deck.create!(account:, location:, collectible_type: option.type, format: option.format.key)
      Location.insert_all!(self.class.zone_rows(location, option.format.zones))
    end
    @deck = deck if errors.empty?
    errors.empty?
  end

  # (see #save)
  # @raise [ActiveRecord::RecordInvalid] when {#save} is false
  def save! = save || raise(ActiveRecord::RecordInvalid, self)

  # The rows of a deck's zones, ready for one `Location.insert_all!` (which skips validations on purpose: the keys and names
  # come from a registration `Catalog::Formats.verify!` checked at boot, and the unique index on (deck, name key) backs
  # them). The one place a zone row's shape is written: creating a deck and changing its format both use it.
  #
  # @api private
  # @param location [Location] the deck's location
  # @param zones [Array<Catalog::Formats::Zone>] the zones to write, in order
  # @return [Array<Hash>]
  def self.zone_rows(location, zones)
    now = Time.current
    zones.map do |zone|
      normal = Location::Name.normalise(zone.name)
      { account_id: location.account_id, parent_id: location.id, kind: "deck_zone", zone: zone.key, name: normal,
        name_key: Location::Name.key(normal), created_at: now, updated_at: now }
    end
  end
end
