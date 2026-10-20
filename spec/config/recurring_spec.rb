require "rails_helper"
require "fugit"

RSpec.describe "config/recurring.yml", type: :config do # rubocop:disable RSpec/DescribeClass -- verifies a config file
  it "refreshes the MTG catalog weekly in production", :aggregate_failures do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "refresh_mtg_catalog")

    expect(task).to include("class" => "Catalog::RefreshJob", "args" => [ "mtg", "scheduled" ], "queue" => "sync")
    expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("15 3 * * 1")
  end

  %w[development production].each do |environment|
    it "schedules the import upload sweep every 15 minutes in #{environment} (spec 028 AC-5.5)" do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig(environment, "sweep_import_uploads")

      expect(task).to include("class" => "ImportUpload::SweepJob", "queue" => "default", "schedule" => "every 15 minutes")
    end
  end
end
