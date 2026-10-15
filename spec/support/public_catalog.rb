# The open catalog in specs (spec 023): `:public_catalog` turns the operator's setting on for one example and restores
# the previous value after it. Tests never read COLLECTOR_PUBLIC_CATALOG (config/initializers/public_catalog.rb).
RSpec.configure do |config|
  config.around(:each, :public_catalog) do |example|
    previous = Rails.configuration.x.public_catalog
    Rails.configuration.x.public_catalog = true
    example.run
  ensure
    Rails.configuration.x.public_catalog = previous
  end
end
