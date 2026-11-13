# A price source for the contract's own specs (spec 085): it knows no real collectible and yields the records it is given.
#
# @api private
class FakePriceSource
  def self.key = "fake_source"
  def self.collectible_type = "widgets"
  def self.title = "Fake Source"
  def self.attribution = "Prices as reported by the fake source."
  def self.attribution_url = "https://prices.example.test"
  def self.hosted_paid_allowed? = false
  def self.series = [ Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market") ]

  # A subclass whose class members answer what is given, for a source that has one member wrong or different.
  #
  # @param members [Hash] class member name => the value it answers
  # @return [Class]
  def self.with(**members)
    Class.new(self) { members.each { |name, value| define_singleton_method(name) { value } } }
  end

  # @param records [Array] the Quote and Malformed values each_quote yields
  # @param reported_on [Date, Exception] what reported_on answers, or the error it raises
  def initialize(records: [], reported_on: Date.new(2026, 11, 13))
    @records = records
    @reported_on = reported_on
  end

  def reported_on(_path) = @reported_on.is_a?(Exception) ? raise(@reported_on) : @reported_on

  def each_quote(path, languages:, &block)
    return enum_for(:each_quote, path, languages:) unless block

    @records.each(&block)
  end
end

# A second fake of the same collectible, to show the registry's key order.
#
# @api private
class OtherFakePriceSource < FakePriceSource
  def self.key = "aaa_other"
end
