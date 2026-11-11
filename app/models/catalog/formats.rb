# The deck formats collectible extensions register (spec 062 FR-2, ADR 0028). A collectible type's collecting vocabulary
# (`Catalog.collecting_for`) may answer `formats`: an array of {Format}, each with a stable `key`, a shown `name`, its
# {Zone}s in order and whether it is the type's `default`. A key is unique within its type, so two games can both have
# one named the same; the core asks here and never names a format. Zones are keys and names and an order: the core knows
# one zone key, {CONSIDERING}, because every format must have a zone for cards under consideration (the decks issue
# design), so a later change of format can move cards there.
#
# An extension contract: a vocabulary that registers formats must provide
# * `formats` returning `Array<Catalog::Formats::Format>`, with exactly one `default`, each key unique among them,
# * for each format, `zones` with distinct keys and with names that are distinct (by comparison key) and well-formed
#   (`Location::Name`), and a zone whose key is {CONSIDERING},
# * optionally `category_name`, the heading under which the New deck page groups the type's formats when formats of more
#   than one type are offered (a type without it is headed by its humanised type).
# A vocabulary with no `formats` method offers none. {verify!} checks the rest at boot, so a bad registration fails the
# process, not a request.
# @see file:collection-and-lots.md
module Catalog::Formats
  # The one zone key the core names: the zone for cards a collector is considering for a deck.
  CONSIDERING = "considering".freeze
  # One zone of a format: a stable `key` and the `name` shown for it. A zone's row copies the name when the deck is made.
  Zone = Data.define(:key, :name)
  # One format of a collectible type, with its `zones` in the order a deck shows them.
  Format = Data.define(:key, :name, :zones, :default)
  # One choice of the New deck form: a format with the collectible type it belongs to.
  Option = Data.define(:type, :format) do
    # The form value that names both halves, `<type>/<format key>`: a key is unique within its type only.
    def value = "#{type}/#{format.key}"
  end

  # Every registered format of every type, as {Option}s, types in registration order and formats in each type's order.
  #
  # @return [Array<Option>]
  def self.options = Catalog.collecting.keys.flat_map { |type| formats_of(type).map { |format| Option.new(type:, format:) } }

  # One registered format.
  #
  # @param type [String] a collectible type
  # @param key [String, Symbol] the format's key in that type
  # @return [Format, nil] nil when the type or the key is not registered
  def self.find(type, key) = formats_of(type).find { it.key == key.to_s }

  # The format a New deck form value names (AC-1.8): `<type>/<key>`, split on the first slash.
  #
  # @param value [String, nil]
  # @return [Option, nil] nil for blank, no slash, an unknown type, or a key that belongs to another type
  def self.find_pair(value)
    type, key = value.to_s.split("/", 2)
    format = find(type, key) if key
    Option.new(type:, format:) if format
  end

  # The option the New deck form starts on: the first type's default.
  #
  # @return [Option, nil] nil when no type registers a format
  def self.default_option = options.find { it.format.default }

  # The zones a deck of a format has, in order.
  #
  # @return [Array<Zone>, nil] nil when the format is not registered
  def self.zones_for(type, key) = find(type, key)&.zones

  # The name shown for a stored format key.
  #
  # @return [String] the format's name, or the key itself when it is no longer registered
  def self.name_for(type, key) = find(type, key)&.name || key

  # The heading of a type's formats on the New deck page, from the type's vocabulary.
  #
  # @return [String]
  def self.category_name(type)
    vocabulary = Catalog.collecting_for(type)
    vocabulary.respond_to?(:category_name) ? vocabulary.category_name : type.to_s.humanize
  end

  # Whether formats of more than one type are offered, so the select groups them (AC-1.2); with one type the list is flat.
  def self.grouped? = options.map(&:type).uniq.size > 1

  # Checks every registration against the contract above. Called at boot (`config/initializers/catalog.rb`), so a bad
  # registration stops the process instead of a deck's creation.
  #
  # @raise [ArgumentError] naming the type, the format and the rule broken
  # @return [true]
  def self.verify!
    Catalog.collecting.each_key { |type| verify_type!(type) }
    true
  end

  # The formats a type's vocabulary registers: none for an unregistered type or a vocabulary without `formats`.
  def self.formats_of(type)
    return [] unless Catalog.collecting.key?(type.to_s)

    vocabulary = Catalog.collecting_for(type.to_s)
    vocabulary.respond_to?(:formats) ? Array(vocabulary.formats) : []
  end
  private_class_method :formats_of

  # @api private
  def self.verify_type!(type)
    formats = formats_of(type)
    return if formats.empty?

    defaults = formats.count(&:default)
    raise ArgumentError, "#{type}: exactly one format must be the default, found #{defaults}" unless defaults == 1

    repeated = formats.map(&:key).tally.find { |_key, count| count > 1 }&.first
    raise ArgumentError, "#{type}: the format key #{repeated.inspect} is registered more than once" if repeated

    formats.each { |format| verify_zones!(type, format) }
  end
  private_class_method :verify_type!

  # @api private
  def self.verify_zones!(type, format)
    where = "#{type}/#{format.key}"
    zones = format.zones
    repeated = zones.map(&:key).tally.find { |_key, count| count > 1 }&.first
    raise ArgumentError, "#{where}: #{repeated.inspect} is used as a zone key more than once" if repeated

    names = zones.map { |zone| Location::Name.normalise(zone.name) }
    names.each do |name|
      fault = Location::Name.fault(name)
      raise ArgumentError, "#{where}: the zone name #{name.inspect} is not a well-formed name (#{fault})" if fault
    end
    keys = names.map { |name| Location::Name.key(name) }
    raise ArgumentError, "#{where}: two zone names have one comparison key (#{keys.tally.find { |_key, count| count > 1 }.first.inspect})" if keys.uniq.size < keys.size
    raise ArgumentError, "#{where}: it needs a #{CONSIDERING.inspect} zone" unless zones.any? { it.key == CONSIDERING }
  end
  private_class_method :verify_zones!
end
