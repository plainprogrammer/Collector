require "rails_helper"
require "fugit"

RSpec.describe "config/recurring.yml", type: :config do # rubocop:disable RSpec/DescribeClass -- verifies a config file
  it "refreshes the MTG catalog weekly in production", :aggregate_failures do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig("production", "refresh_mtg_catalog")

    expect(task).to include("class" => "Catalog::RefreshJob", "args" => [ "mtg", "scheduled" ], "queue" => "sync")
    expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("15 3 * * 1")
  end
end
