# How Magic cards are collected: finishes, conditions, the category name (spec 004 FR-6) and the deck formats with their zones
# (spec 062 decision 2, the extension side of `Catalog::Formats`).
module MTG::Collecting
  CATEGORY_NAME = "Magic: The Gathering"
  CONDITIONS = {
    "near_mint" => [ "Near mint", "NM" ], "lightly_played" => [ "Lightly played", "LP" ],
    "moderately_played" => [ "Moderately played", "MP" ], "heavily_played" => [ "Heavily played", "HP" ],
    "damaged" => [ "Damaged", "DMG" ]
  }.freeze
  SPECIAL_FINISHES = %w[foil etched].freeze
  FINISH_ORDER = %w[nonfoil foil etched].freeze

  def self.category_name = CATEGORY_NAME
  def self.conditions = CONDITIONS
  def self.special_finishes = SPECIAL_FINISHES
  def self.finish_order = FINISH_ORDER
  def self.finish_label(finish) = finish.to_s.humanize

  def self.finishes_for(entry)
    Catalog::Entry.preload_extensions([ entry ]) if entry.extension.nil?
    Array(entry.extension&.finishes).sort_by { |finish| [ FINISH_ORDER.index(finish) || FINISH_ORDER.size, finish ] }
  end

  # The deck formats, in the order the New deck page lists them. Casual is the default. Every format has the Considering zone the
  # core asks for (`Catalog::Formats::CONSIDERING`); Commander's own zone comes first.
  FORMATS = begin
    zone = ->(key, name) { Catalog::Formats::Zone.new(key:, name:) }
    constructed = [ zone.("main", "Main"), zone.("sideboard", "Sideboard"), zone.("considering", "Considering") ].freeze
    commander = [ zone.("commander", "Commander"), zone.("main", "Main"), zone.("considering", "Considering") ].freeze
    [
      [ "casual", "Casual", constructed, true ], [ "standard", "Standard", constructed, false ], [ "pioneer", "Pioneer", constructed, false ],
      [ "modern", "Modern", constructed, false ], [ "legacy", "Legacy", constructed, false ], [ "vintage", "Vintage", constructed, false ],
      [ "pauper", "Pauper", constructed, false ], [ "commander", "Commander", commander, false ]
    ].map { |key, name, zones, default| Catalog::Formats::Format.new(key:, name:, zones:, default:) }.freeze
  end

  # The deck formats this collectible registers with the core's seam, with each format's zones in order.
  #
  # @return [Array<Catalog::Formats::Format>]
  def self.formats = FORMATS

  # The deck formats whose rules the catalog stores a legality for: Scryfall's legality key is the format's own key, so the
  # deck's key reads the printing's `legalities` directly. Casual has no rules, so it has no entry here and no marker.
  LEGALITY_FORMATS = %w[standard pioneer modern legacy vintage pauper commander].freeze

  # The deck page's answer for one card (spec 066, the extension side of `Catalog::DeckCards`): the group of its first face's
  # type line, the marker word for the deck's format and whether the `deck_cost` partial draws its cost. Reads the loaded
  # extension record only, so no query runs per card.
  #
  # @param entry [Catalog::Entry] a printing with `extension` loaded (`Catalog::Entry.preload_extensions`)
  # @param format_key [String] the deck's stored format key
  # @return [Catalog::DeckCards::Answer]
  def self.deck_card(entry, format_key)
    printing = entry.extension
    position = MTG::DeckGroups.position(printing&.faces&.first&.dig("type_line"))
    Catalog::DeckCards::Answer.new(group: MTG::DeckGroups.group_name(position), position:,
      legality: deck_legality(printing, format_key), costed: !printing.nil?)
  end

  # @api private
  def self.deck_legality(printing, format_key)
    return unless printing && LEGALITY_FORMATS.include?(format_key)

    status = printing.legalities.fetch(format_key, "not_legal")
    MTG::Legality.word(status) unless status == "legal"
  end
  private_class_method :deck_legality
end
