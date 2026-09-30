# Parses a Scryfall mana cost into Collector's own pips (spec 004 AC-8.3). Hybrid, Phyrexian and
# snow symbols aren't designed yet, so they render as text tags (pip? false).
class MTG::ManaCost
  COLOURS = { "W" => "white", "U" => "blue", "B" => "black", "R" => "red", "G" => "green" }.freeze
  Pip = Data.define(:text, :css, :label, :pip?)

  attr_reader :pips

  def initialize(cost)
    @pips = cost.to_s.scan(/\{([^}]+)\}/).flatten.map { |raw| pip_for(raw) }
  end

  def label = "Mana cost: #{pips.map(&:label).join(', ')}"

  private
    def pip_for(raw)
      case raw
      when /\A\d+\z/ then Pip.new(text: raw, css: "c-mana", label: "#{raw} generic", pip?: true)
      when "X" then Pip.new(text: "X", css: "c-mana", label: "X", pip?: true)
      when "C" then Pip.new(text: "C", css: "c-mana", label: "1 colourless", pip?: true)
      when *COLOURS.keys then Pip.new(text: raw, css: "c-mana c-mana--#{raw.downcase}", label: "1 #{COLOURS[raw]}", pip?: true)
      when "S" then Pip.new(text: "{S}", css: "c-tag", label: "snow", pip?: false)
      when %r{\A(.)/P\z} then Pip.new(text: "{#{raw}}", css: "c-tag", label: "Phyrexian #{COLOURS.fetch(Regexp.last_match(1), Regexp.last_match(1))}", pip?: false)
      else
        parts = raw.split("/").map { |part| COLOURS.fetch(part, part) }
        Pip.new(text: "{#{raw}}", css: "c-tag", label: parts.join(" or "), pip?: false)
      end
    end
end
