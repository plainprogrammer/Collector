# What an account holds of one card, seen from one of its printings (spec 004 AC-8.4, AC-8.5, AC-8.7).
class Catalog::CardOverview
  NEWEST = 10
  Row = Data.define(:entry, :owned, :shown)
  # A zone's parent, for the order of the copies (a place has none).
  PARENT_JOIN = "LEFT JOIN locations parents ON parents.id = locations.parent_id".freeze

  attr_reader :entry

  def initialize(account:, entry:)
    @account, @entry = account, entry
  end

  def identity = entry.identity
  def vocabulary = Catalog.collecting_for(entry.collectible_type)

  # A visitor (no account) holds nothing, and nothing is queried (spec 023 FR-3).
  def lots
    return [] unless @account

    # The place order reads a zone under its deck's name, so a deck's zones sort together (spec 062 AC-5.4); `location: :parent` is
    # preloaded because the label of a zone names its deck, and costs one query however many lots there are.
    @lots ||= @account.lots.joins(:entry).left_joins(:location).joins(PARENT_JOIN).where(catalog_entries: { catalog_identity_id: identity.id })
      .includes(entry: :set).preload(location: :parent).merge(Catalog::Entry.newest_first).order(:finish, :condition, :price_paid_cents)
      .order(Arel.sql("COALESCE(parents.name_key, locations.name_key)"), Location.arel_table[:name_key].asc, Location.arel_table[:name].asc).to_a # unplaced first: NULL sorts first (spec 032 AC-4.1)
  end

  def owned_count = lots.sum(&:quantity)
  def printings_owned = lots.map(&:catalog_entry_id).uniq.size
  def total_printings = @total_printings ||= identity.entries.searchable.count

  # The copies of the card the account can put in a deck: `Lot.free` read through `Lot::FreeCopies`, the one definition of
  # "free" (specs 070, 071 and 073). Built on first use; a visitor never builds it.
  #
  # @return [Lot::FreeCopies]
  def free_copies = @free_copies ||= Lot::FreeCopies.new(account: @account, entry:)

  # The copies of the card that are free to use (spec 073 decision 2): in no deck zone, Considering counted as in a deck.
  #
  # @return [Integer] 0 for a visitor
  def free_count = @account ? free_copies.total : 0

  # The card's lots that are in a deck zone: the card's lots that are not among the free ones, so "in a deck" is the
  # complement of `Lot.free` and is never tested on a location's kind here. A proxy is not a lot and is not among them.
  #
  # @return [Array<Lot>] empty for a visitor
  def deck_lots
    @deck_lots ||= begin
      free = @account ? free_copies.lots.to_set(&:id) : Set.new
      lots.reject { free.include?(it.id) }
    end
  end

  # The copies of the card in deck zones, so that Owned is this plus {#free_count}.
  #
  # @return [Integer]
  def in_decks_count = deck_lots.sum(&:quantity)

  # The zones of the account's decks that hold a copy or a proxy of the card, for the "In decks" section and the stats' deck
  # count.
  #
  # @return [Deck::CardUses]
  def uses = @uses ||= Deck::CardUses.new(account: @account, entry:, lots: deck_lots)

  def rows
    @rows ||= begin
      owned = lots.group_by(&:catalog_entry_id).transform_values { |group| group.sum(&:quantity) }
      owned_entries = Catalog::Entry.where(id: owned.keys).where.not(id: entry.id).newest_first.includes(:set).to_a
      listed = [ entry.id, *owned_entries.map(&:id) ]
      newest = identity.entries.searchable.where.not(id: listed).newest_first.includes(:set).limit(NEWEST).to_a
      [ entry, *owned_entries, *newest ].map { |row_entry| Row.new(entry: row_entry, owned: owned.fetch(row_entry.id, 0), shown: row_entry == entry) }
    end
  end
end
