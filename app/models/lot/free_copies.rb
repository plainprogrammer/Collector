# The copies of one card an account can put in a deck: its lots, of every printing of the card, that are in no deck zone
# (`Lot.free`: spec 057's "Free to use", spec 071 decision 4), in the order a count takes them (decision 5) and the places they
# are in, for the "My copies" sentence (decision 7). Free is judged on the card, not the shown printing: a deck uses a card.
#
# Reads the account's lots when first asked (three statements however many lots there are: the lots with their entries and sets, their places, and the printings' order) and keeps them, so build a new one
# inside the transaction that writes. The order is made in Ruby from preloaded rows, so it doesn't depend on the SQL of
# `Lot.free`. Takes the account explicitly; never reads `Current.account`. Collectible-agnostic.
# @see file:collection-and-lots.md
class Lot::FreeCopies
  # Places named in the "My copies" sentence before "and N more places": a line or two on a phone, and an account with hundreds
  # of places can't make a page of it (spec 071 decision 7).
  PLACES_SHOWN = 5

  # A place the free copies are in and how many, `name` nil for copies with no location.
  Place = Data.define(:name, :count)

  # @param account [Account] whose lots are read
  # @param entry [Catalog::Entry] the shown printing; its card (identity) decides which lots count
  def initialize(account:, entry:)
    @account, @entry = account, entry
  end

  # The free lots in take order: the shown printing's first, then the other printings newest first, and within a printing as
  # "Your copies" lists them (finish, condition, price paid, with unspecified first, then a lot with no location before places
  # by name; spec 032 AC-4.1).
  #
  # @return [Array<Lot>] with `entry` (and its set) and `location` loaded
  def lots
    @lots ||= begin
      found = @account.lots.free.joins(:entry).where(catalog_entries: { catalog_identity_id: @entry.catalog_identity_id })
        .includes(entry: :set).preload(:location).to_a
      rank = Catalog::Entry.where(id: found.map(&:catalog_entry_id).uniq).newest_first.pluck(:id).each_with_index.to_h
      found.sort_by { |lot| order_key(lot, rank) }
    end
  end

  # The copies that are free, summed over {#lots}.
  #
  # @return [Integer]
  def total = lots.sum(&:quantity)

  # The places the free copies are in, for the "My copies" sentence: each once with its copies summed, in the order the copies would
  # be taken.
  #
  # @return [Array<Place>]
  def places
    lots.group_by(&:location_id).map { |_, group| Place.new(name: group.first.location&.name, count: group.sum(&:quantity)) }
  end

  # The lots and counts a request for `count` copies takes: whole lots from the front while a whole lot fits, then the rest
  # from the next lot, which splits.
  #
  # @param count [Integer] from 1 to {#total}
  # @return [Array<Array(Lot, Integer)>] the pairs `Lot::MoveIntoZone` takes
  def take(count)
    left = count
    lots.each_with_object([]) do |lot, picks|
      break picks if left.zero?

      taken = [ lot.quantity, left ].min
      picks << [ lot, taken ]
      left -= taken
    end
  end

  private
    def order_key(lot, rank)
      place = lot.location
      [ lot.catalog_entry_id == @entry.id ? 0 : 1, rank.fetch(lot.catalog_entry_id), lot.finish.to_s, lot.condition.to_s,
        lot.price_paid_cents || -1, place ? 1 : 0, place&.name_key.to_s, place&.name.to_s, lot.id ]
    end
end
