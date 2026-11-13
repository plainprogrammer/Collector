# Magic's deck rules for the deck checks (spec 079 decision 3, the extension side of `Catalog::DeckChecks`): size and copy
# limits per format, and each printing's limit read from its first face's type line, its rules text and its legalities.
# Reads the loaded printing record only, so no query runs per card.
class MTG::DeckRules
  # The formats that share one rule set: the main zone's minimum, the sideboard's maximum and a limit of four.
  CONSTRUCTED = %w[standard pioneer modern legacy vintage pauper].freeze
  # A constructed deck holds at least this many cards in its main zone (spec 079 decision 3).
  MAIN_MINIMUM = 60
  # A constructed deck's sideboard holds at most this many cards.
  SIDEBOARD_MAXIMUM = 15
  # The copies of one card a constructed deck may hold (a basic land and the cards that say otherwise excepted).
  CONSTRUCTED_COPIES = 4
  # The copies of one card a Commander deck may hold: the singleton rule.
  COMMANDER_COPIES = 1
  # A Commander deck's commander and main zones hold exactly this many cards together.
  COMMANDER_SIZE = 100
  # Rules text of a card a deck may hold any number of: Scryfall's own words (confirmed in verification.md, T0.2).
  ANY_NUMBER = /a deck can have any number of cards named/i
  # Rules text of a card a deck may hold up to a stated number of; the number is the word after "up to".
  STATED_NUMBER = /a deck can have up to (\w+) cards named/i
  # The number words the stated limits use (Seven Dwarves: seven; Nazgûl: nine).
  NUMBER_WORDS = %w[two three four five six seven eight nine ten].each_with_index.to_h { |word, index| [ word, index + 2 ] }.freeze

  # The rules of one format.
  #
  # @param format_key [String] the deck's stored format key
  # @return [Catalog::DeckChecks::Rules, nil] nil for casual and for a key the collectible has no rules for
  def self.for(format_key)
    return commander if format_key == "commander"

    constructed(format_key) if CONSTRUCTED.include?(format_key)
  end

  # A printing's limit in a format. Order matters: a basic land and any-number text are exempt first, then a stated number,
  # then Vintage's restriction, then the ordinary limit. A printing with no card data is never exempt and never restricted.
  #
  # @param entry [Catalog::Entry] a printing, its `extension` loaded or nil
  # @param format_key [String]
  # @param ordinary [Integer] the format's ordinary limit
  # @return [Catalog::DeckChecks::Limit, nil] nil for a card that is never limited
  def self.limit_for(entry, format_key, ordinary)
    printing = entry.extension
    return Catalog::DeckChecks::Limit.new(count: ordinary, reason: nil) if printing.nil?

    faces = Array(printing.faces)
    return if basic_land?(faces.first)

    text = faces.filter_map { it["oracle_text"] }.join("\n")
    return if text.match?(ANY_NUMBER)

    stated = NUMBER_WORDS[text[STATED_NUMBER, 1].to_s.downcase]
    return Catalog::DeckChecks::Limit.new(count: stated, reason: nil) if stated
    return Catalog::DeckChecks::Limit.new(count: 1, reason: "restricted to 1") if format_key == "vintage" && printing.legalities.to_h["vintage"] == "restricted"

    Catalog::DeckChecks::Limit.new(count: ordinary, reason: nil)
  end

  # @api private
  def self.basic_land?(face) = face&.dig("type_line").to_s.split("—").first.to_s.split.include?("Basic")
  private_class_method :basic_land?

  # @api private
  def self.constructed(format_key)
    Catalog::DeckChecks::Rules.new(
      sizes: [ Catalog::DeckChecks::SizeRule.new(zone_keys: %w[main], min: MAIN_MINIMUM, max: nil),
               Catalog::DeckChecks::SizeRule.new(zone_keys: %w[sideboard], min: nil, max: SIDEBOARD_MAXIMUM) ],
      copies: Catalog::DeckChecks::CopyRule.new(zone_keys: %w[main sideboard], limit_for: ->(entry) { limit_for(entry, format_key, CONSTRUCTED_COPIES) })
    )
  end
  private_class_method :constructed

  # @api private
  def self.commander
    Catalog::DeckChecks::Rules.new(
      sizes: [ Catalog::DeckChecks::SizeRule.new(zone_keys: %w[commander main], min: COMMANDER_SIZE, max: COMMANDER_SIZE) ],
      copies: Catalog::DeckChecks::CopyRule.new(zone_keys: %w[commander main], limit_for: ->(entry) { limit_for(entry, "commander", COMMANDER_COPIES) })
    )
  end
  private_class_method :commander
end
