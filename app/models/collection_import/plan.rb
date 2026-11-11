# What applying a file to the collection would do, and the fingerprint that ties an apply to the preview that showed it
# (spec 028 decision 2) and, for a version 2 file, of the locations (spec 029 decision 11) and, for a version 4 file, of the
# decks (spec 062 AC-7.10) and, for a version 4 file, of the proxies (spec 068 AC-7.8). The one place that lists what an apply writes, the account's currency among them (spec 038
# decision 7).
class CollectionImport::Plan
  attr_reader :added_rows, :changed_rows, :removed_lots, :view_change, :locations, :decks, :proxies, :currency_change

  # @param outcomes [Hash] what `CollectionImport` judged of the lots
  # @param view_change [String, nil]
  # @param locations [CollectionImport::Locations] what applying does with the places
  # @param decks [CollectionImport::Decks] what applying does with the decks, uncounted for a version 1 to 3 file
  # @param proxies [CollectionImport::Proxies] what applying does with the proxies, uncounted for a version 1 to 3 file
  # @param currency_change [CollectionImport::CurrencyChange, nil]
  def initialize(outcomes, view_change, locations, decks, proxies, currency_change)
    @added_rows = outcomes.fetch(:added_rows)
    @changed_rows = outcomes.fetch(:changed_rows)
    @removed_lots = outcomes.fetch(:removed_lots)
    @matched = outcomes.fetch(:matched_lots)
    @view_change = view_change
    @locations = locations
    @decks = decks
    @proxies = proxies
    @currency_change = currency_change
  end

  def held_for(row) = @matched.fetch(row.identity)

  # Nothing to change: no lot, no location, no deck, no proxy, no view change and no currency change (spec 028 decision 12, spec
  # 029 decision 10, spec 038 decision 7, spec 062 AC-7.7, spec 068 AC-7.4). The zone repair of an apply (AC-8.2a) is never a
  # change of its own.
  def nothing_to_change? = !writes_lots? && view_change.nil? && locations.nothing_to_change? && decks.nothing_to_change? && proxies.nothing_to_change? && currency_change.nil?

  # Whether the apply writes a lot; only then does it clear the working state that points at lots (spec 029 AC-9.17).
  def writes_lots? = added_rows.any? || changed_rows.any? || removed_lots.any?

  # The removed lots that are in a deck's zone: what a version 1 to 3 file, which has no zone to name, takes out of the
  # collector's decks (spec 062 AC-7.4).
  #
  # @return [Array<CollectionImport::HeldLot>]
  def removed_zone_lots = removed_lots.select(&:in_zone?)

  # Whether applying removes anything the collector must confirm: a lot, a place, a deck or a proxy (spec 028 decision 6, spec 062
  # AC-7.6, spec 068 decision 16).
  def removes? = removed_lots.any? || locations.removes? || decks.removes? || proxies.removes?

  def counts = { added: added_rows.size, changed: changed_rows.size, removed: removed_lots.size }

  # A digest of the stored file and of the plan: the added and changed rows and their outcome, every changed and removed
  # lot's id, quantity and times at full precision, the view change, the locations' part for a file that counts them, the
  # decks' part for a file that counts them (version 4 only, so a version 1 to 3 plan keeps the fingerprint it had, spec 062
  # AC-7.10), the proxies' part for a file that counts them (version 4 only, spec 068 AC-7.8) and, last and only when there is one, the currency change's two codes, so a plan without one keeps the
  # fingerprint it had (spec 038 decision 7).
  def fingerprint(file_checksum)
    parts = [ file_checksum,
      added_rows.map { |row| [ row.number, "added" ] },
      changed_rows.map { |row| lot_part(held_for(row)).unshift(row.number, "changed") },
      removed_lots.sort_by(&:id).map { |lot| lot_part(lot) },
      view_change ]
    parts << locations.fingerprint_part if locations.counted?
    parts << decks.fingerprint_part if decks.counted?
    parts << proxies.fingerprint_part if proxies.counted?
    parts << [ currency_change.from, currency_change.to ] if currency_change
    Digest::SHA256.hexdigest(JSON.generate(parts))
  end

  private
    # A lot's place is part of it, so a lot moved between the preview and the apply makes the preview stale (spec 032 AC-11.7).
    def lot_part(lot) = [ lot.id, lot.quantity, lot.created_exact, lot.updated_exact, lot.identity.last ]
end
