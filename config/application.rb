require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/collector/trusted_proxies"

module Collector
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # collector/backup is the operator's backup and restore (spec 030): required by path before the app boots, never autoloaded.
    # collector/ci_groups, collector/ci_shard and collector/push_scope are bin/ci's and the pre-push hook's development
    # tooling (spec 035): required by path, never autoloaded.
    config.autoload_lib(ignore: %w[assets tasks collector/backup.rb collector/backup collector/ci_groups.rb collector/ci_shard.rb collector/push_scope.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Downloaded catalog source files live on the persistent storage volume.
    config.x.catalog_download_dir = Rails.root.join("storage/catalog")

    # Reverse proxies whose X-Forwarded-For is trusted (spec 004 AC-4.8).
    config.action_dispatch.trusted_proxies = Collector::TrustedProxies.parse(ENV["COLLECTOR_TRUSTED_PROXIES"])
    config.x.sign_in_rate_limit_store = nil # nil: Rails.cache

    # Card scanner measurement mode (spec 007 Story 5): off unless an environment sets it.
    config.x.scanner_measurement = nil

    # Art matching for the card scanner (spec 011): off until config/initializers/art_matching.rb reads the environment.
    config.x.mtg_art_matching = false

    # The open catalog (spec 023): off until config/initializers/public_catalog.rb reads the environment.
    config.x.public_catalog = false
  end
end
