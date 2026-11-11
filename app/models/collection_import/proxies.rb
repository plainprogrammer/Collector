# What applying a file would do with the collector's proxies (spec 068 decision 16): compare by identity, as lots are. A version
# 1 to 3 file says nothing about proxies (+rows+ is nil), so the collector's stay and nothing here counts. A held proxy no good
# row matches is *removed*, a held proxy a problem row only names included (the preview can't be applied then); counts are
# rows, not quantities (spec Terms).
#
# Collectible-agnostic: a proxy is a deck and zone key, an entry's type and source id and a finish.
# @see file:data-portability.md
class CollectionImport::Proxies
  # A proxy of the collection, read as the file would write it: +identity+ is `[deck key, zone key, type, source id, finish]`;
  # +place+ is "Deck › Zone".
  Held = Data.define(:id, :identity, :quantity, :name, :set_code, :collector_number, :language, :finish, :place) do
    # What a list shows of it: `import_proxy_line`'s keywords.
    def described = { set_code:, collector_number:, language:, finish:, place: }
  end

  # @return [Array<CollectionImport::ProxyRows::ProxyRow>] the good rows no held proxy has
  attr_reader :added
  # @return [Array<CollectionImport::ProxyRows::ProxyRow>] the good rows whose held proxy has another quantity
  attr_reader :changed
  # @return [Array<Held>] the held proxies no good row matches
  attr_reader :removed
  # @return [Integer] the good rows equal to a held proxy
  attr_reader :unchanged

  # @param held [Array<Held>] the account's proxies
  # @param rows [Array<CollectionImport::ProxyRows::ProxyRow>, nil] the file's proxy rows, or nil for a version 1 to 3 file
  def initialize(held, rows)
    @counted = !rows.nil?
    @added = []
    @changed = []
    @removed = []
    @unchanged = 0
    @held = held.index_by(&:identity)
    return unless @counted

    good = rows.reject(&:problem?)
    matched, @added = good.partition { |row| @held.key?(row.identity) }
    @changed, same = matched.partition { |row| row.quantity != @held.fetch(row.identity).quantity }
    @unchanged = same.size
    kept = matched.to_set(&:identity)
    @removed = held.reject { |proxy| kept.include?(proxy.identity) }.sort_by { |proxy| order(proxy) }
  end

  # Whether the file says anything about proxies (version 4).
  def counted? = @counted

  # The four counts the preview shows, in rows.
  #
  # @return [Hash{Symbol => Integer}]
  def counts = { added: added.size, changed: changed.size, unchanged:, removed: removed.size }

  # Whether the file changes no proxy.
  def nothing_to_change? = added.empty? && changed.empty? && removed.empty?

  # Whether applying removes a proxy, which needs the collector's confirmation.
  def removes? = removed.any?

  # The held proxy a changed row matches.
  #
  # @param row [CollectionImport::ProxyRows::ProxyRow]
  # @return [Held]
  def held_for(row) = @held.fetch(row.identity)

  # The first `CollectionImport::LIST_LIMIT` removed proxies, for the page.
  def listed_removed = removed.first(CollectionImport::LIST_LIMIT)

  # How many removed proxies the page doesn't list.
  def more_removed = removed.size - listed_removed.size

  # What the plan's fingerprint takes from the proxies: each added row by its identity and quantity, each changed row by its
  # identity and both quantities, each removed proxy by its identity and quantity. No id and no row number, so a proxy
  # deleted and added again with the same identity and quantity changes nothing. Empty for an older file.
  #
  # @return [Array]
  def fingerprint_part
    [ added.map { |row| [ *row.identity, row.quantity ] }.sort_by { |part| part.map(&:to_s) },
      changed.map { |row| [ *row.identity, held_for(row).quantity, row.quantity ] }.sort_by { |part| part.map(&:to_s) },
      removed.map { |proxy| [ *proxy.identity, proxy.quantity ] } ]
  end

  private
    # Deck key, zone key, card name, set code, collector number as a person reads it, language, finish (decision 16).
    def order(proxy)
      number = proxy.collector_number.to_s
      [ proxy.identity[0], proxy.identity[1], proxy.name, proxy.set_code, number.match?(/\A\d/) ? 0 : 1, number.to_i, number, proxy.language, proxy.finish.to_s ]
    end
end
