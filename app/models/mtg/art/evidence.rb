# A reading's art evidence (spec 011 Story 6): the usable artworks among those the page sent, nearest first. An artwork
# is usable when it's in the artwork table, has printings (not retired, ordinary cards, English: the printings the scanner
# ranks over) and has a card: the card of its printings, or, when they belong to several cards, the one among the text's
# candidates with the best name rank (glossary). The rest give no evidence at all.
class MTG::Art::Evidence
  Usable = Data.define(:id, :distance, :identity_id, :printings)

  def initialize(sent, text_identity_ids:, margin:)
    @sent = sent
    @text_identity_ids = text_identity_ids
    @margin = margin
  end

  def usable
    @usable ||= begin
      printings = printings_by_artwork
      @sent.each_with_index.sort_by { |artwork, index| [ artwork.distance, index ] }.filter_map do |artwork, _index|
        entries = printings[artwork.id]
        identity_id = entries && card_for(entries)
        Usable.new(id: artwork.id, distance: artwork.distance, identity_id:, printings: entries) if identity_id
      end
    end
  end

  def nearest = usable.first

  def confident = (nearest if nearest && nearest.distance <= @margin)

  # Each card's smallest distance among the usable artworks.
  def card_distances = usable.each_with_object({}) { |artwork, distances| distances[artwork.identity_id] ||= artwork.distance }

  private
    # { illustration_id => [entries, newest first] } for the sent artworks that are in the artwork table.
    def printings_by_artwork
      known = MTG::Artwork.where(illustration_id: @sent.map(&:id)).pluck(:illustration_id)
      return {} if known.empty?

      artwork_of = MTG::Printing.where(illustration_id: known).pluck(:catalog_entry_id, :illustration_id).to_h
      Catalog::Entry.searchable.where(id: artwork_of.keys, collectible_type: "mtg", language: "en")
        .newest_first.includes(:set, :identity).to_a.group_by { artwork_of.fetch(it.id) }
    end

    def card_for(entries)
      ids = entries.map(&:catalog_identity_id).uniq
      ids.one? ? ids.first : @text_identity_ids.find { ids.include?(it) }
    end
end
