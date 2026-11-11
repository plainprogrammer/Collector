# One deck's own data (spec 062, ADR 0028): the collectible type and format the collector chose. A deck is a location of
# kind `deck` (`location`: its name, its limit and its place in the name space) plus this row; its zones are the child
# locations of that location, one per zone of the format, and they hold the copies. A deck never holds a lot itself.
#
# Collectible-agnostic: the type and the format are stored as text, and `Catalog::Formats` says what they mean.
#
# This class has an attribute called `format`, so Kernel#format is not callable here without `Kernel.format`.
# @see file:collection-and-lots.md
class Deck < ApplicationRecord
  belongs_to :account
  belongs_to :location
  validates :collectible_type, :format, presence: true
  validate :location_is_a_deck_of_the_account

  delegate :name, to: :location

  # Routes name a deck by its location's id (spec 062 decision 4), so a zone's or a place's id is never a deck's.
  def to_param = location_id.to_s

  # The account's decks by their locations' comparison keys, then names: the order every list of decks uses.
  def self.listing_order = joins(:location).order("locations.name_key", "locations.name")

  # The deck's zones, by id: a deck's zones are written together in the format's order, so their ids run in that order, except
  # that a zone an import's repair adds later (a release gave the format another zone) gets a later id and is listed last.
  #
  # @return [ActiveRecord::Relation<Location>]
  def zones = location.zones.order(:id)

  # One zone by its stable key.
  #
  # @param key [String]
  # @return [Location]
  # @raise [ActiveRecord::RecordNotFound] when the deck has no zone of that key
  def zone(key) = location.zones.find_by!(zone: key)

  # What the deck's zones hold together (see Location::Holdings), for the page that refuses a removal and the Decks page.
  def holdings = location.holdings

  # The deck's proxies, in every zone, as one relation read by value (the account and the zones' parent), so a caller adds no
  # query to find them (spec 068).
  #
  # @return [ActiveRecord::Relation<Deck::Proxy>]
  def proxies = Deck::Proxy.where(account_id:, location_id: Location.where(parent_id: location_id, kind: "deck_zone").select(:id))

  # The format's shown name, or its key when the extension no longer registers it.
  def format_name = Catalog::Formats.name_for(collectible_type, format)

  # Gives the deck's location a new name; the zones, the format and the lots stay as they are.
  #
  # @param name [String] as typed
  # @return [Boolean] false, with the sentence on the location's `errors[:name]`, when the name is refused
  def rename(name)
    location.name = name
    location.save
  end

  # Removes the deck with its zones: one DELETE of the location, which the foreign keys cascade to the zones and this row.
  # A zone that holds a lot refuses it (the lots' foreign key is RESTRICT), so a lot placed after the caller's check is
  # caught here and nothing is left half removed (spec 062 AC-3.5).
  #
  # @raise [ActiveRecord::InvalidForeignKey] when a lot is in one of the zones
  def remove! = location.destroy!

  private
    def location_is_a_deck_of_the_account
      errors.add(:location, "must be a deck of the account") unless location&.deck? && location.account_id == account_id
    end
end
