# What a deck page's Check deck answers (spec 079): the deck's size and copy limits judged by the collectible's own rules, and
# every card with owned copies and proxies in one zone, which needs no rule and runs for every deck. Like
# `Catalog::DeckShape`, an optional answer on the collecting vocabulary (`Catalog.collecting_for`), so the core counts and
# words the results and never names a collectible, a format or a zone key but `Catalog::Formats::CONSIDERING`.
#
# An extension contract: a vocabulary that has rules for a format provides
# * `deck_rules(format_key)` returning {Rules}, or nil for a format it has no rules for (the deck's stored key, registered or not).
# * `Rules#sizes`: {SizeRule}s in the order they are shown. A rule holds the `zone_keys` it counts (the extension names them;
#   the core matches each to a zone row's key) and one of three shapes: `min` only, `max` only, or `min == max` (an exact
#   size); a range with two different bounds is not offered. The extension supplies no words.
# * `Rules#copies`: a {CopyRule} or nil. Its `zone_keys` are counted together; `limit_for` is called with one counted printing
#   (a `Catalog::Entry` whose `extension` may be nil) and returns a {Limit} (`count`, and a `reason` sentence part such as
#   "restricted to 1", or nil) or nil for a card that is never limited. For a printing with no extension record it returns
#   the format's ordinary limit. It reads loaded records only, never a query.
# The core counts copies by catalog identity over every counted printing and holds a card to the lowest number its printings
# answer; nil is above every number, so a card is unlimited only when every counted printing answers nil, and the reason is
# the one given with the lowest number (the first printing in page order on a tie). A card of another collectible than the
# deck's is left out of every check. Considering and any zone no rule names are counted by no size or copy rule.
# A vocabulary without `deck_rules`, a nil answer, a type no longer registered and a deck whose format is no longer registered
# have no size or copy rules.
# @see file:collection-and-lots.md
module Catalog::DeckChecks
  # One size rule: the zone keys it counts together and a minimum, a maximum, or both equal (an exact size).
  SizeRule = Data.define(:zone_keys, :min, :max)
  # A card's limit: the most copies a deck may hold, and an optional sentence part that says why ("restricted to 1").
  Limit = Data.define(:count, :reason)
  # The copy rule: the zone keys counted together and a callable from a loaded printing to a {Limit} or nil.
  CopyRule = Data.define(:zone_keys, :limit_for)
  # What a vocabulary answers for a format: its size rules and its copy rule (nil for none).
  Rules = Data.define(:sizes, :copies)
  # One line of a report: a status word (nil for a line that is no check), its sentence, and whether it is a finding.
  Line = Data.define(:status, :sentence, :fault)
  # The results of one check request, in the order they are shown.
  Report = Data.define(:lines) do
    # The number of findings.
    def faults = lines.count(&:fault)

    # The summary line: "3 findings", "1 finding" or "No findings".
    def summary = faults.zero? ? "No findings" : "#{faults} #{faults == 1 ? 'finding' : 'findings'}"
  end
  # A row of the deck's collectible with its zone and the zone's position in page order.
  # @api private
  Counted = Data.define(:zone, :position, :row)

  # The report for a deck.
  #
  # @param deck_type [String] the deck's collectible type
  # @param format_key [String] the deck's stored format key, registered or not
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`; read from memory, no statement runs
  # @return [Report] never nil, and never raises for an unregistered type or format
  def self.report(deck_type, format_key, zones)
    counted = counted_rows(deck_type, zones)
    rules = rules_for(deck_type, format_key)
    lines = rules ? rule_lines(rules, deck_type, format_key, zones, counted) : [ no_rules_line(deck_type, format_key) ]
    Report.new(lines: lines + split_lines(counted))
  end

  # @api private
  def self.rules_for(deck_type, format_key)
    return unless Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    vocabulary.deck_rules(format_key) if vocabulary.respond_to?(:deck_rules)
  end
  private_class_method :rules_for

  # Every row of the deck's collectible with its zone's position; another collectible's rows are left out (decision 4).
  # @api private
  def self.counted_rows(deck_type, zones)
    zones.each_with_index.flat_map do |zone, position|
      zone.groups.flat_map(&:rows).select { it.entry.collectible_type == deck_type }.map { Counted.new(zone:, position:, row: it) }
    end
  end
  private_class_method :counted_rows

  # @api private
  def self.rule_lines(rules, deck_type, format_key, zones, counted)
    rules.sizes.map { size_line(it, deck_type, format_key, zones, counted) }
  end
  private_class_method :rule_lines

  # One size result (decision 6). Zones are named in the rule's key order: by the zone row's shown name, else by the format's
  # registration, else by the key.
  # @api private
  def self.size_line(rule, deck_type, format_key, zones, counted)
    total = counted.select { rule.zone_keys.include?(it.zone.location.zone) }.sum { it.row.total }
    subject = rule.zone_keys.map { zone_name(it, deck_type, format_key, zones) }.join(" + ")
    status = if rule.min && total < rule.min then "Short" elsif rule.max && total > rule.max then "Over" else "Pass" end
    format_name = Catalog::Formats.name_for(deck_type, format_key)
    Line.new(status:, sentence: "#{subject}: #{counted_words(total, 'card')}; #{format_name} #{size_need(rule)}.", fault: status != "Pass")
  end
  private_class_method :size_line

  # The rule's requirement in words: "needs at least 60", "allows at most 15" or "needs exactly 100".
  # @api private
  def self.size_need(rule)
    return "needs exactly #{delimited(rule.min)}" if rule.min && rule.min == rule.max
    return "needs at least #{delimited(rule.min)}" if rule.min

    "allows at most #{delimited(rule.max)}"
  end
  private_class_method :size_need

  # @api private
  def self.zone_name(key, deck_type, format_key, zones)
    zones.find { it.location.zone == key }&.name || Catalog::Formats.zones_for(deck_type, format_key)&.find { it.key == key }&.name || key
  end
  private_class_method :zone_name

  # "1 card", "5 copies": the count with delimiters and the singular for one.
  # @api private
  def self.counted_words(number, word) = "#{delimited(number)} #{word.pluralize(number)}"
  private_class_method :counted_words

  # @api private
  def self.no_rules_line(deck_type, format_key)
    Line.new(status: nil, sentence: "#{Catalog::Formats.name_for(deck_type, format_key)} has no rules to check.", fault: false)
  end
  private_class_method :no_rules_line

  # A count with delimiters ("1,234"), as the deck page's heads and spec 069's panel write one.
  # @api private
  def self.delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)
  private_class_method :delimited

  # The owned-plus-proxy check (decision 5): each zone alone, any printing of the card; findings ordered by the zone's
  # position, then the card's name, then its identity; or one pass line.
  # @api private
  def self.split_lines(counted)
    findings = counted.group_by { [ it.position, it.row.entry.catalog_identity_id ] }.filter_map do |(position, identity_id), cards|
      owned = cards.sum { it.row.owned }
      proxy = cards.sum { it.row.proxy }
      next unless owned.positive? && proxy.positive?

      [ position, cards.first.row.entry.name, identity_id, cards.first.zone.name, owned, proxy ]
    end
    return [ Line.new(status: "Pass", sentence: "No card has both owned copies and proxies in one zone.", fault: false) ] if findings.empty?

    findings.sort_by { it.first(3) }.map do |_position, name, _identity_id, zone_name, owned, proxy|
      Line.new(status: "Owned and proxy", sentence: "#{name} in #{zone_name}: #{delimited(owned)} owned, #{delimited(proxy)} proxy.", fault: true)
    end
  end
  private_class_method :split_lines
end
