# What applying a file would do with the collector's decks (spec 062 AC-7.1 to AC-7.3): replace by comparison key, as
# {CollectionImport::Locations} does for places, because a deck's name shares the name space of places. A version 1 to 3 file
# says nothing about decks (+file+ is nil), so the collector's stay as they are and nothing here counts; the copies in
# their zones are what applying such a file removes, and the lots' plan says so, not this one.
#
# A held deck whose key the file also has is *renamed* when its spelling differs and *format changed* when its collectible
# type or format differs; the two lists are independent, so a deck with both is in both and keeps its id. Zones are not a
# deck's data here: they come from the format and the apply writes them. Collectible-agnostic: a type and a format are text.
# @see file:data-portability.md
class CollectionImport::Decks
  # A deck of the collection; +id+ is its location's id.
  Held = Data.define(:id, :name, :key, :collectible_type, :format)
  # A deck of the file, its name as the collector would store it (`Location::Name.normalise`).
  Entry = Data.define(:name, :collectible_type, :format)
  # A held deck the file spells differently.
  Renamed = Data.define(:held, :name)
  # A held deck the file gives another collectible type or format.
  FormatChanged = Data.define(:held, :collectible_type, :format)

  # @return [Array<Entry>] the file's decks the collection lacks
  attr_reader :added
  # @return [Array<Renamed>]
  attr_reader :renamed
  # @return [Array<FormatChanged>]
  attr_reader :format_changed
  # @return [Array<Held>] the held decks the file lacks
  attr_reader :removed
  # @return [Integer] the held decks the file has exactly as they are
  attr_reader :unchanged

  # @param held [Array<Held>] the account's decks
  # @param file [Array<Entry>, nil] the file's decks, or nil for a version 1 to 3 file
  def initialize(held, file)
    @counted = !file.nil?
    @added = []
    @renamed = []
    @format_changed = []
    @removed = []
    @unchanged = 0
    return unless @counted

    held_by_key = held.index_by(&:key)
    entries = file.index_by { |entry| Location::Name.key(entry.name) }
    entries.each do |key, entry|
      kept = held_by_key[key]
      if kept.nil?
        @added << entry
      else
        @renamed << Renamed.new(held: kept, name: entry.name) if kept.name != entry.name
        @format_changed << FormatChanged.new(held: kept, collectible_type: entry.collectible_type, format: entry.format) if changed_format?(kept, entry)
        @unchanged += 1 if kept.name == entry.name && !changed_format?(kept, entry)
      end
    end
    @removed = held.reject { |deck| entries.key?(deck.key) }
    sort!
  end

  # Whether the file says anything about decks (version 4); false for an older file, which leaves the collector's decks alone.
  def counted? = @counted

  # The five counts the preview shows.
  #
  # @return [Hash{Symbol => Integer}]
  def counts = { added: added.size, renamed: renamed.size, format_changed: format_changed.size, unchanged:, removed: removed.size }

  # Whether the file changes no deck: none added, renamed, format-changed or removed (an unchanged deck is no change).
  def nothing_to_change? = added.empty? && renamed.empty? && format_changed.empty? && removed.empty?

  # Whether applying removes a deck, which needs the collector's confirmation.
  def removes? = removed.any?

  # The first `CollectionImport::LIST_LIMIT` renamed decks, for the page.
  def listed_renamed = renamed.first(CollectionImport::LIST_LIMIT)

  # How many renamed decks the page doesn't list.
  def more_renamed = renamed.size - listed_renamed.size

  # The first `CollectionImport::LIST_LIMIT` format-changed decks, for the page.
  def listed_format_changed = format_changed.first(CollectionImport::LIST_LIMIT)

  # How many format-changed decks the page doesn't list.
  def more_format_changed = format_changed.size - listed_format_changed.size

  # The first `CollectionImport::LIST_LIMIT` removed decks, for the page.
  def listed_removed = removed.first(CollectionImport::LIST_LIMIT)

  # How many removed decks the page doesn't list.
  def more_removed = removed.size - listed_removed.size

  # What the plan's fingerprint takes from the decks (spec 062 AC-7.10, as the places' part does): the name of each added
  # deck; the current and the file's name of each renamed one; the current and the file's type and format of each
  # format-changed one; the name of each removed one. No id, and an unchanged deck isn't in it, so a deck deleted and added
  # again with the same spelling and format changes nothing. The lists are in the order of the comparison key then the
  # name, which is unique per account, so the part is the same every time.
  #
  # @return [Array]
  def fingerprint_part
    [ added.map(&:name),
      renamed.map { |item| [ item.held.name, item.name ] },
      format_changed.map { |item| [ item.held.name, item.held.collectible_type, item.held.format, item.collectible_type, item.format ] },
      removed.map { |deck| [ deck.name ] } ]
  end

  private
    def changed_format?(held, entry) = held.collectible_type != entry.collectible_type || held.format != entry.format

    def sort!
      @added.sort_by! { |entry| [ Location::Name.key(entry.name), entry.name ] }
      @renamed.sort_by! { |item| [ item.held.key, item.name ] }
      @format_changed.sort_by! { |item| [ item.held.key, item.held.name ] }
      @removed.sort_by! { |deck| [ deck.key, deck.name ] }
    end
end
