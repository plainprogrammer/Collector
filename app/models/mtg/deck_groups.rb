# Magic's groups for a deck page's rows (spec 066 decision 6): the top-level types of a printing's first face. A card is
# placed by the part of its type line before the dash: a Creature is a Creature whatever else it is (an Artifact Creature,
# Dryad Arbor, a Land Creature), then a Land is a Land (an Artifact Land), then the first of the other types in the order of
# {NAMES}. The order of {NAMES} is the order the groups are shown in; a type line with none of them is Other.
module MTG::DeckGroups
  # The groups, in the order the page shows them.
  NAMES = %w[Creatures Planeswalkers Battles Instants Sorceries Artifacts Enchantments Lands Other].freeze
  # The card type each group but Other collects, at the same index as its name.
  TYPES = %w[Creature Planeswalker Battle Instant Sorcery Artifact Enchantment Land].freeze

  # Where a card's type line puts it among {NAMES}.
  #
  # @param type_line [String, nil] a face's type line, "Legendary Creature — Elf Druid"
  # @return [Integer] an index of {NAMES}; Other's for no type data
  def self.position(type_line)
    types = type_line.to_s.split("—").first.to_s.split
    return TYPES.index("Creature") if types.include?("Creature")
    return TYPES.index("Land") if types.include?("Land")

    TYPES.index { types.include?(it) } || NAMES.index("Other")
  end

  # The group's shown name.
  #
  # @param position [Integer] from {position}
  # @return [String]
  def self.group_name(position) = NAMES.fetch(position)
end
