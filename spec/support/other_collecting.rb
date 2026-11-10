# A second collecting vocabulary, registered for one example with :other_collecting as the type "other" (spec 042 AC-4.5). Its
# scale has one condition, "mint", which the scanner's own vocabulary doesn't know. It also registers one deck format whose key,
# "standard", another collectible registers as well, so a spec can show that a format key is unique within its type only
# (spec 062 AC-1.2).
module OtherCollecting
  CONDITIONS = { "mint" => [ "Mint", "M" ] }.freeze

  # The heading the New deck page groups this type's formats under when formats of two types are offered.
  def self.category_name = "Other cards"
  def self.conditions = CONDITIONS
  def self.special_finishes = []
  def self.finishes_for(_entry) = []
  def self.finish_label(finish) = finish.to_s.humanize

  # Built on first use, not at load: this file loads before the examples, and the seam's constants are the application's.
  def self.formats
    @formats ||= [
      Catalog::Formats::Format.new(
        key: "standard", name: "Standard", default: true,
        zones: [ Catalog::Formats::Zone.new(key: "deck", name: "Deck"), Catalog::Formats::Zone.new(key: Catalog::Formats::CONSIDERING, name: "Considering") ]
      )
    ].freeze
  end
end

RSpec.configure do |config|
  config.around(:each, :other_collecting) do |example|
    Catalog.collecting["other"] = "OtherCollecting"
    example.run
  ensure
    Catalog.collecting.delete("other")
  end
end
