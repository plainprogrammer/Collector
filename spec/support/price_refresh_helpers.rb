# Builders and fakes for the daily price refresh's specs (spec 089): a fake price source and a fake catalog source for
# a made-up collectible, "widgets", registered for one example with `use_widget_sources`.
#
# @api private
module PriceRefreshHelpers
  PLAIN = Prices::Sources::Series.new(finish: "plain", currency: "USD", kind: "market")
  DAY = Date.new(2026, 11, 13)

  # Registers `fake_source` (prices) and `widgets` (catalog) for this example; both are undone after it.
  #
  # @param records [Array] what the price source yields from `each_quote` (a record that responds to `call` is called)
  # @param reported_on [Date, Exception] what `#reported_on` answers
  # @param series [Array<Prices::Sources::Series>, nil] the series it declares, or the one plain series
  # @param version [String] the catalog source's current version
  # @param languages [Array<String>] the catalog source's languages
  def use_widget_sources(records: [], reported_on: DAY, series: nil, version: "v1", languages: [ "en" ])
    price_class = Class.new(FakePriceSource) do
      define_singleton_method(:series) { series } if series
      define_method(:initialize) { |*| super(records:, reported_on:) }
    end
    catalog_class = Class.new(FakeCatalogSource) do
      define_method(:initialize) { |*| super(version:, languages:) }
    end
    stub_const("WidgetPrices", price_class)
    stub_const("WidgetCatalog", catalog_class)
    Prices.sources["fake_source"] = "WidgetPrices"
    Catalog.sources["widgets"] = "WidgetCatalog"
    @widget_sources = true
    price_class
  end

  def widget_quote(key, cents, series: PLAIN, on: DAY)
    Prices::Sources::Quote.new(external_key: key, finish: series.finish, currency: series.currency, kind: series.kind, cents:, reported_on: on)
  end

  def widget_malformed(key = nil, series: nil) = Prices::Sources::Malformed.new(external_key: key, error: "unreadable", series:)

  def widget_entry(key, **attributes) = create(:catalog_entry, collectible_type: "widgets", external_key: key, **attributes)

  def price_source_row = PriceSource.sync!(FakePriceSource) # the same row `fake_source` has, before an example registers its own

  def series_row(series = PLAIN) = PriceSeries.ensure!([ series ]).fetch(series)

  # A current price and its history row, as an earlier run would have left them.
  def seed_price(entry, cents, series: PLAIN, on: Date.new(2026, 11, 12))
    keys = { catalog_entry_id: entry.id, price_source_id: price_source_row.id, price_series_id: series_row(series).id }
    CurrentPrice.insert_all!([ keys.merge(cents:, reported_on: on, changed_on: on) ])
    PriceChange.insert_all!([ keys.merge(recorded_on: on, cents:) ])
  end
end

RSpec.configure do |config|
  config.include PriceRefreshHelpers
  config.after do
    next unless @widget_sources

    Prices.sources.delete("fake_source")
    Catalog.sources.delete("widgets")
  end
end
