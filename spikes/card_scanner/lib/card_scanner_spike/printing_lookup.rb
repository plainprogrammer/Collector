module CardScannerSpike
  # Resolves a parsed collector line to catalog printings (FR-3). Needs Rails.
  class PrintingLookup
    Outcome = Data.define(:status, :entries)

    def self.known_set_codes = Catalog::Set.where(collectible_type: "mtg").pluck(:code)

    def call(set_code:, number:, language: "en")
      return Outcome.new(status: :none, entries: []) if set_code.blank? || number.blank?

      entries = Catalog::Entry.active.joins(:set)
        .where(collectible_type: "mtg", number:, language: language || "en")
        .where(catalog_sets: { code: set_code.downcase }).to_a
      Outcome.new(status: { 0 => :none, 1 => :one }.fetch(entries.size, :ambiguous), entries:)
    end
  end
end
