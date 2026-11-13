# What a price means: a finish, an ISO 4217 currency and a kind, in the prices database (spec 081 decision 2). Series are
# global, not per source, so two sources that quote the same finish, currency and kind share one row. A row is written
# from a source's declaration (its `.series`), never by a migration (spec 085 decision 7).
#
# There is no uniqueness validation: the unique index on finish, currency and kind is the guard, and `ensure!` creates
# through it, so a caller that loses a race reads the winner's row instead of failing a validation.
#
# @see file:prices.md
class PriceSeries < PricesRecord
  validates :finish, :kind, presence: true
  validates :currency, format: { with: Prices::Sources::CURRENCY }

  # The rows of the given series, each created if it doesn't exist. Idempotent and safe from two processes at once; never
  # deletes a row. Writes to the prices database only.
  #
  # @param series [Array<Prices::Sources::Series>] declared series
  # @return [Hash{Prices::Sources::Series => PriceSeries}] a row for each series, so `ensure!(series)[quote.series]` is a
  #   quote's row
  def self.ensure!(series)
    series.to_h do |declared|
      attributes = declared.to_h
      [ declared, find_by(attributes) || create_or_find_by!(attributes) ]
    end
  end
end
