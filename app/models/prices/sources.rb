# The contract between the core and a price source: how a collectible's extension supplies prices (spec 085). This
# comment is the one place the contract is written down; a source for a new collectible is added by reading it. It
# mirrors `Catalog::Sources`, the contract for the catalog. A source is a class, registered in `Prices.sources` under
# its key (config/initializers/prices.rb), built with `.new` and no arguments, that provides:
#
#   .key                      the source's stable key: lower case letters, digits and underscores, such as "widget_prices";
#                             stored as price_sources.key, and never changed once released
#   .collectible_type         the key of the `Catalog.sources` entry whose printings this source's external ids name
#   .title                    the source's name, stored as price_sources.name (not `.name`, which every class answers)
#   .attribution              the text a page shows beside this source's prices
#   .attribution_url          an https address, or nil
#   .hosted_paid_allowed?     true or false: whether a hosted instance with paid plans may show this source's prices. Stated
#                             and stored; nothing refuses a source by it yet
#   .series                   the `Series` this source quotes: an Array, not empty, with no two equal
#   #reported_on(path)        the Date the data in the file at path is from. Raises IntegrityError when the file doesn't say
#   #each_quote(path, languages:) { |Quote or Malformed| }
#                             streamed, for the file at path, each Quote carrying #reported_on's date; without a block it
#                             returns an Enumerator. `languages:` is what the collectible's catalog source returns from
#                             `#languages`, so quotes are yielded for the printings the catalog holds; a source for a
#                             collectible without languages ignores it
#
# What `#each_quote` must and must not do:
#
# - It reads a local copy of the source's data and nothing else: no network call, no write, no read of the database. The
#   file is the caller's to fetch. The contract has no members that fetch it.
# - It holds one record at a time: memory doesn't grow with the file.
# - It yields only the prices the file carries. A price the file leaves empty has no quote; whether that means a price is
#   gone is the caller's to decide from the absence.
# - It yields a `Malformed` for what it could not read, and goes on. What a `Malformed` means for absence:
#   - one with a `series` is a price the file carries and the source could not read: **not an absence**, and the caller
#     must leave that printing's price in that series alone;
#   - one with an `external_key` and no `series` is a printing whose prices could not be read at all: no series of that
#     printing may be read as absent;
#   - one with no `external_key` names no printing, so the run's absences can't be trusted.
# - It raises `IntegrityError` (before yielding anything) for a file whose day it can't tell, and lets the reader's own
#   error (a corrupt file) surface to the caller.
#
# A `Quote` is one price of one printing: the source's id for the printing (the catalog entry's `external_key`), its
# series (finish, currency, kind), whole `cents` and the day it was reported. Values validate when built, so a source
# can't yield what the prices database would refuse.
#
# @see file:prices.md
module Prices::Sources
  # A source's failure that isn't a bad line: the base of the errors below.
  class Error < StandardError; end

  # The file can't be trusted: its day can't be told, so no quote may be given a date.
  class IntegrityError < Error; end

  # A source class that doesn't meet the contract (see `verify!`).
  class ConfigurationError < Error; end

  # An ISO 4217 code is three upper-case letters; the same rule as the price_series table's check constraint (spec 081).
  CURRENCY = /\A[A-Z]{3}\z/

  # @api private
  # @raise [ArgumentError] unless the value is a String with something in it
  def self.text!(name, value)
    raise ArgumentError, "#{name} must be a non-blank String, got #{value.inspect}" unless value.is_a?(String) && !value.strip.empty?
  end

  # @api private
  # @raise [ArgumentError] unless the value is three upper-case letters
  def self.currency!(value)
    raise ArgumentError, "currency must be three upper-case letters, got #{value.inspect}" unless value.is_a?(String) && value.match?(CURRENCY)
  end

  # What a price means: a finish, an ISO 4217 currency and a kind (spec 081 glossary). Series are global: two sources
  # that quote the same finish, currency and kind share one row (`PriceSeries`).
  Series = Data.define(:finish, :currency, :kind) do
    def initialize(finish:, currency:, kind:)
      Prices::Sources.text!(:finish, finish)
      Prices::Sources.currency!(currency)
      Prices::Sources.text!(:kind, kind)
      super
    end
  end

  # One price of one printing, as a source reported it.
  #
  # `external_key` is the source's id for the printing; `cents` is a whole number of cents, 0 or more; `reported_on` is
  # a Date, the day the source's data is from.
  #
  # @raise [ArgumentError] when built with a blank key, finish or kind, a currency that isn't three upper-case
  #   letters, a `cents` that isn't a non-negative Integer, or a `reported_on` that isn't a Date
  Quote = Data.define(:external_key, :finish, :currency, :kind, :cents, :reported_on) do
    def initialize(external_key:, finish:, currency:, kind:, cents:, reported_on:)
      Prices::Sources.text!(:external_key, external_key)
      Prices::Sources.text!(:finish, finish)
      Prices::Sources.currency!(currency)
      Prices::Sources.text!(:kind, kind)
      raise ArgumentError, "cents must be an Integer of 0 or more, got #{cents.inspect}" unless cents.is_a?(Integer) && cents >= 0
      raise ArgumentError, "reported_on must be a Date, got #{reported_on.inspect}" unless reported_on.is_a?(Date)

      super
    end

    # The series this quote is a price in.
    #
    # @return [Series]
    def series = Series.new(finish:, currency:, kind:)
  end

  # A line, or a price on a line, that the source could not read. `series` is the `Series` of an unreadable price, or
  # nil when the line is unreadable as a whole. See the comment of this module for what each kind means for absence.
  Malformed = Data.define(:external_key, :error, :series) do
    def initialize(external_key:, error:, series: nil) = super
  end
end
