# How a lot's place is written for people and in an export file, and how it is keyed and resolved (spec 062 D6, D2, D4). One
# home so the label, the file's key and the resolution of a place never disagree. Collectible-agnostic: a zone is a
# location's child, and no game is named here.
#
# A file writes a lot's place as `null`, a place's name, or `{ "deck" => name, "zone" => key }`. Its identity's place value is
# `nil`, a place's comparison key, or the pair `[deck key, zone key]`. A String and an Array never compare equal, so a place
# called "Box" and the zone "main" of a deck called "Box" are different places (AC-6.12).
# @see file:data-portability.md
module Location::Placement
  # The label of a zone wherever a lot's place is shown: "Izzet Tempo › Main".
  #
  # @param name [String] the zone's name
  # @param deck_name [String] the name of the deck the zone belongs to
  # @return [String]
  def self.label(name, deck_name) = "#{deck_name}#{Location::ZONE_SEPARATOR}#{name}"

  # A lot's place as an export file writes it.
  #
  # @param kind [String, nil] the location's kind, nil for an unplaced lot
  # @param name [String, nil] the location's name (a place's name)
  # @param zone [String, nil] the zone's key, for a zone
  # @param deck_name [String, nil] the zone's deck's name, for a zone
  # @return [nil, String, Hash{String => String}]
  # @raise [ArgumentError] for a kind a lot can't be in (a deck's own row)
  def self.written(kind:, name:, zone:, deck_name:)
    case kind
    when nil then nil
    when "place" then name
    when "deck_zone" then { "deck" => deck_name, "zone" => zone }
    else raise ArgumentError, "a lot can't be in a location of kind #{kind.inspect}"
    end
  end

  # A lot's place as its identity holds it.
  #
  # @param name_key [String, nil] the place's comparison key
  # @param zone [String, nil] the zone's key
  # @param deck_key [String, nil] the zone's deck's comparison key
  # @return [nil, String, Array<String>] nil, the place's key, or `[deck key, zone key]`
  # @raise [ArgumentError] for a kind a lot can't be in
  def self.key(kind:, name_key:, zone:, deck_key:)
    case kind
    when nil then nil
    when "place" then name_key
    when "deck_zone" then [ deck_key, zone ]
    else raise ArgumentError, "a lot can't be in a location of kind #{kind.inspect}"
    end
  end

  # What a file's `location` value keys to, normalised as a collector's typed name is (`Location::Name`): the deck's name
  # becomes its comparison key and the zone key is kept as written.
  #
  # @param value [nil, String, Hash] the file's value, as parsed
  # @return [nil, String, Array<String>] the same shape {.key} answers
  # @raise [ArgumentError] when the value is none of the three shapes (a reader has judged it first)
  def self.file_key(value)
    case value
    when nil then nil
    when String then Location::Name.key(Location::Name.normalise(value))
    when Hash then [ Location::Name.key(Location::Name.normalise(value["deck"])), value["zone"] ]
    else raise ArgumentError, "a place is null, a name or a deck and zone, not #{value.class}"
    end
  end

  # The location id a key stands for.
  #
  # @param key [nil, String, Array<String>] from {.key} or {.file_key}
  # @param places [Hash{String => Integer}] place ids by comparison key
  # @param zones [Hash{Array<String> => Integer}] zone ids by `[deck key, zone key]`
  # @return [Integer, nil] nil for nil
  # @raise [KeyError] when the key is in neither hash
  def self.resolve(key, places:, zones:) = key.is_a?(Array) ? zones.fetch(key) : (places.fetch(key) if key)
end
