# One deck's page (spec 066): its zones in the format's order, each with the printings the account owns in it grouped as the
# collectible's vocabulary groups them, and the counts. Reads only; needs the deck, which came from the signed-in account's
# decks, so every read is scoped to it by value and costs no extra statement.
#
# Reads in a bounded number of statements however many zones, rows and lots the deck has: the zones, the lots' copies summed
# per zone and printing, the printings with their sets, and the extension records once per collectible type (5 in all
# when the deck's location is loaded; spec 066 AC-2.10). A row is one printing in one zone: its lots of every finish,
# condition and price are summed (decision 2).
# @see file:collection-and-lots.md
class Deck::Page
  # One printing in one zone: the entry (its set and extension loaded), the copies owned and the vocabulary's answer.
  Row = Data.define(:entry, :owned, :answer)
  # The rows under one group's name; a nil name is the flat group of a collectible that answers nothing.
  Group = Data.define(:name, :rows) do
    # The copies in the group.
    def owned = rows.sum(&:owned)
  end
  # One zone: its location and its groups in the extension's order.
  Zone = Data.define(:location, :groups) do
    # The zone location's id.
    def id = location.id

    # The zone's shown name.
    def name = location.name

    # The copies in the zone.
    def owned = groups.sum(&:owned)

    # Whether the zone holds no lot.
    def empty? = groups.empty?
  end

  attr_reader :deck

  # @param deck [Deck] a deck of the signed-in account, its location loaded to keep the read count
  def initialize(deck)
    @deck = deck
  end

  # The zones in the format's order; a zone the format does not list, and every zone of a format the instance no longer
  # registers, follows by id. Read once.
  #
  # @return [Array<Zone>]
  def zones = @zones ||= build_zones

  # The copies in every zone, Considering included.
  #
  # @return [Integer]
  def owned = zones.sum(&:owned)

  private
    def build_zones
      locations = ordered_locations
      copies = copies_by_zone_and_entry(locations)
      entries = entries_for(copies.keys.map(&:last).uniq)
      locations.map { |location| Zone.new(location:, groups: groups_for(location, entries, copies)) }
    end

    def ordered_locations
      keys = Catalog::Formats.zones_for(deck.collectible_type, deck.format)&.map(&:key) || []
      deck.zones.to_a.sort_by { |zone| [ keys.index(zone.zone) || keys.size, zone.id ] }
    end

    # One grouped statement: { [zone id, entry id] => copies }. The account is the deck's, by value.
    def copies_by_zone_and_entry(locations)
      Lot.where(account_id: deck.account_id, location_id: locations.map(&:id)).group(:location_id, :catalog_entry_id).sum(:quantity)
    end

    # The printings in the order a zone lists them, with sets and extension records: two statements and one per type.
    def entries_for(ids)
      return [] if ids.empty?

      entries = Catalog::Entry.where(id: ids).joins(:set).preload(:set).order(
        Catalog::Entry::DISPLAY_NAME_SQL, Catalog::Set.arel_table[:code].asc,
        Catalog::Entry::NUMBER_HAS_DIGITS_FIRST, Catalog::Entry::NUMBER_VALUE,
        Catalog::Entry.arel_table[:number].asc, Catalog::Entry.arel_table[:language].asc
      ).to_a
      Catalog::Entry.preload_extensions(entries.select { Catalog.sources.key?(it.collectible_type) }) # a type with no source has no extension model to ask
      entries # preload_extensions returns what it was given, so the entries of a type with no source are not dropped
    end

    # The zone's rows in the printings' order, grouped by the vocabulary's position (a row with none last), each group
    # named by its answer.
    def groups_for(location, entries, copies)
      rows = entries.filter_map do |entry|
        owned = copies[[ location.id, entry.id ]] or next
        Row.new(entry:, owned:, answer: Catalog::DeckCards.answer(deck.collectible_type, entry, deck.format))
      end
      rows.group_by { it.answer.position }.sort_by { |position, _| position || Float::INFINITY }
        .map { |_position, in_group| Group.new(name: in_group.first.answer.group, rows: in_group) }
    end
end
