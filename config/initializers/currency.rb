# Stops the app on an unsupported COLLECTOR_CURRENCY (spec 004 FR-6).
Rails.application.config.to_prepare do
  Rails.configuration.x.currency = Collector::Currency.fetch!(ENV.fetch("COLLECTOR_CURRENCY", "USD"))
end
