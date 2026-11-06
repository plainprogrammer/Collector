# COLLECTOR_CURRENCY is the currency a new account starts with (spec 038 decision 2); each account then keeps its own in
# accounts.currency. An unsupported code stops the app, naming the setting (spec 004 FR-6). Only Account reads the default.
Rails.application.config.to_prepare do
  Rails.configuration.x.default_currency = Collector::Currency.fetch!(ENV.fetch("COLLECTOR_CURRENCY", "USD"))
  # TEMPORARY until phase 2 moves the last reader (spec 038 plan).
  Rails.configuration.x.currency = Rails.configuration.x.default_currency
end
