# One deck's page (spec 066, spec 068): its zones in the format's order, each with the printings the account owns in it, or has
# a proxy of in it, grouped as the collectible's vocabulary groups them, and the counts. Reads only; needs the deck, which came
# from the signed-in account's decks, so every read is scoped to it by value and costs no extra statement.
#
# Reads in a bounded number of statements however many zones, rows, lots and proxies the deck has: the zones, the lots' copies
# summed per zone and printing, the proxies, the printings with their sets, and the extension records once per collectible
# type (at most 6 statements with the deck's location loaded, 3 for a deck with no lots and no proxies; spec 068 AC-2.10). A row
# is one printing in one zone: its lots of every finish, condition and price are summed, and its proxies of every finish are
# listed as lines (spec 066 decision 2).
# @see file:collection-and-lots.md
class Deck::Page
  # One proxy of a card row: its id (the menu's links), its finish (nil when the printing lists none) and its quantity.
  Line = Data.define(:id, :finish, :quantity)
  # One printing in one zone: the entry (its set and extension loaded), the copies owned, the zone's proxies of it (one line
  # per finish) and the vocabulary's answer.
  Row = Data.define(:entry, :owned, :lines, :answer) do
    # The proxies of the printing in the zone, every finish added up.
    def proxy = lines.sum(&:quantity)

    # Owned plus proxy: the Total column.
    def total = owned + proxy

    # Whether the replacement items of a proxy row are offered: they need the printing's collectible's vocabulary (spec 070
    # decision 1), so a printing whose collectible the instance no longer registers has Change and Remove only.
    def replaceable? = Deck::Proxy.replaceable?(entry)
  end
  # The rows under one group's name; a nil name is the flat group of a collectible that answers nothing.
  Group = Data.define(:name, :rows) do
    # The copies in the group.
    def owned = rows.sum(&:owned)

    # The proxies in the group.
    def proxy = rows.sum(&:proxy)

    # Owned plus proxy: the group row's count.
    def total = owned + proxy
  end
  # One zone: its location and its groups in the extension's order.
  Zone = Data.define(:location, :groups) do
    # The zone location's id.
    def id = location.id

    # The zone's shown name.
    def name = location.name

    # The copies in the zone.
    def owned = groups.sum(&:owned)

    # The proxies in the zone.
    def proxy = groups.sum(&:proxy)

    # Owned plus proxy.
    def total = owned + proxy

    # Whether the zone holds no lot and no proxy.
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

  # The proxies in every zone, Considering included (quantities).
  #
  # @return [Integer]
  def proxy = zones.sum(&:proxy)

  # The deck's cards: owned copies plus proxies (spec 060 decision 12).
  #
  # @return [Integer]
  def total = owned + proxy

  private
    def build_zones
      locations = ordered_locations
      copies = copies_by_zone_and_entry(locations)
      proxies = proxies_by_zone_and_entry(locations)
      entries = entries_for((copies.keys + proxies.keys).map(&:last).uniq)
      locations.map { |location| Zone.new(location:, groups: groups_for(location, entries, copies, proxies)) }
    end

    def ordered_locations
      keys = Catalog::Formats.zones_for(deck.collectible_type, deck.format)&.map(&:key) || []
      deck.zones.to_a.sort_by { |zone| [ keys.index(zone.zone) || keys.size, zone.id ] }
    end

    # One grouped statement: { [zone id, entry id] => copies }. The account is the deck's, by value.
    def copies_by_zone_and_entry(locations)
      Lot.where(account_id: deck.account_id, location_id: locations.map(&:id)).group(:location_id, :catalog_entry_id).sum(:quantity)
    end

    # One statement: { [zone id, entry id] => [Line] }, the proxies of the deck's zones by value (the account and the zones'
    # ids), in id order.
    def proxies_by_zone_and_entry(locations)
      Deck::Proxy.where(account_id: deck.account_id, location_id: locations.map(&:id)).order(:id)
        .pluck(:location_id, :catalog_entry_id, :id, :finish, :quantity)
        .group_by { |zone_id, entry_id, *| [ zone_id, entry_id ] }
        .transform_values { |rows| rows.map { |_zone, _entry, id, finish, quantity| Line.new(id:, finish:, quantity:) } }
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
    # named by its answer. A printing with a proxy and no copy has a row too.
    def groups_for(location, entries, copies, proxies)
      rows = entries.filter_map do |entry|
        owned = copies[[ location.id, entry.id ]]
        lines = proxies.fetch([ location.id, entry.id ], [])
        next if owned.nil? && lines.empty?

        Row.new(entry:, owned: owned.to_i, lines:, answer: Catalog::DeckCards.answer(deck.collectible_type, entry, deck.format))
      end
      rows.group_by { it.answer.position }.sort_by { |position, _| position || Float::INFINITY }
        .map { |_position, in_group| Group.new(name: in_group.first.answer.group, rows: in_group) }
    end
end
