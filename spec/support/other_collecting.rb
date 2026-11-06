# A second collecting vocabulary, registered for one example with :other_collecting as the type "other" (spec 042 AC-4.5). Its
# scale has one condition, "mint", which the scanner's own vocabulary doesn't know.
module OtherCollecting
  CONDITIONS = { "mint" => [ "Mint", "M" ] }.freeze

  def self.conditions = CONDITIONS
  def self.special_finishes = []
  def self.finishes_for(_entry) = []
  def self.finish_label(finish) = finish.to_s.humanize
end

RSpec.configure do |config|
  config.around(:each, :other_collecting) do |example|
    Catalog.collecting["other"] = "OtherCollecting"
    example.run
  ensure
    Catalog.collecting.delete("other")
  end
end
