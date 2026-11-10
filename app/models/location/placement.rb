# How a lot's place is written for people and, from the file tasks on, in an export file and back (spec 062 D6, D2). One
# home so the label, the file's key and the resolution of a place never disagree. Collectible-agnostic: a zone is a
# location's child, and no game is named here.
module Location::Placement
  # The label of a zone wherever a lot's place is shown: "Izzet Tempo › Main".
  #
  # @param name [String] the zone's name
  # @param deck_name [String] the name of the deck the zone belongs to
  # @return [String]
  def self.label(name, deck_name) = "#{deck_name}#{Location::ZONE_SEPARATOR}#{name}"
end
