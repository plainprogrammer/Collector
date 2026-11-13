# Where prices come from, in the prices database (spec 081 decision 2): a key, a name, the attribution a page shows and
# whether a hosted instance with paid plans may show the source. A row is written from the source class's own
# declaration (`Prices::Sources`), so the text ships with the build and takes effect at the next sync, and no migration
# seeds it (spec 085 decision 7).
#
# @see file:prices.md
class PriceSource < PricesRecord
  validates :key, :name, :attribution, presence: true
  validates :hosted_paid_allowed, inclusion: { in: [ true, false ] }

  # The row of a price source, created or brought up to date from its declaration, and the rows of the series it
  # declares (`PriceSeries.ensure!`). Idempotent, safe to call at the start of every run and from two processes at once
  # (a lost race on the unique key is retried once), and a call that changes nothing writes nothing. Never deletes a
  # source or a series. Writes to the prices database only.
  #
  # @param source_class [Class] a class that implements `Prices::Sources`
  # @return [PriceSource] the row
  # @raise [Prices::Sources::ConfigurationError] when the class doesn't meet the contract; nothing is written
  def self.sync!(source_class)
    Prices::Sources.verify!(source_class)
    PriceSeries.ensure!(source_class.series)
    attempts = 0
    begin
      find_or_initialize_by(key: source_class.key).tap do |source|
        source.assign_attributes(name: source_class.title, attribution: source_class.attribution, attribution_url: source_class.attribution_url,
                                 hosted_paid_allowed: source_class.hosted_paid_allowed?)
        source.save!
      end
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 2
      raise
    end
  end
end
