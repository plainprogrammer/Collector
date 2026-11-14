require "rails_helper"
require "fugit"

RSpec.describe "config/recurring.yml", type: :config do # rubocop:disable RSpec/DescribeClass -- verifies a config file
  it "refreshes the MTG catalog weekly in production", :aggregate_failures do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "refresh_mtg_catalog")

    expect(task).to include("class" => "Catalog::RefreshJob", "args" => [ "mtg", "scheduled" ], "queue" => "sync")
    expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("15 3 * * 1")
  end

  it "refreshes prices daily in production, at another time than the catalog's refresh, and not in development (spec 089 AC-5.1)", :aggregate_failures do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    task = config.dig("production", "refresh_prices")

    expect(task).to include("class" => "Prices::RefreshJob", "args" => [ "scryfall" ], "queue" => "sync")
    expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("30 11 * * *")
    expect(config.dig("development", "refresh_prices")).to be_nil
  end

  %w[development production].each do |environment|
    it "schedules the import upload sweep every 15 minutes in #{environment} (spec 028 AC-5.5)" do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig(environment, "sweep_import_uploads")

      expect(task).to include("class" => "ImportUpload::SweepJob", "queue" => "default", "schedule" => "every 15 minutes")
    end
  end

  %w[development production].each do |environment|
    it "schedules the session sweep daily at night in #{environment} (spec 049 AC-3.6)", :aggregate_failures do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig(environment, "sweep_sessions")

      expect(task).to include("class" => "Session::SweepJob", "queue" => "default")
      expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("10 4 * * *")
    end
  end
end
