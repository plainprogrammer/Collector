require "rails_helper"
require "rake"

RSpec.describe "catalog rake tasks", type: :task do # rubocop:disable RSpec/DescribeClass -- rake tasks have no class
  before { Rails.application.load_tasks unless Rake::Task.task_defined?("catalog:refresh") }

  after { %w[catalog:refresh catalog:status].each { |name| Rake::Task[name].reenable } }

  describe "catalog:refresh" do
    it "queues a manual refresh without waiting for it" do
      expect { Rake::Task["catalog:refresh"].invoke("mtg") }
        .to have_enqueued_job(Catalog::RefreshJob).with("mtg", "manual")
        .and output(/Queued mtg catalog refresh/).to_stdout
    end

    it "rejects an unknown collectible type" do
      expect { Rake::Task["catalog:refresh"].invoke("pokemon") }.to raise_error(ArgumentError, /pokemon/)
    end
  end

  describe "catalog:status" do
    it "lists the 10 most recent runs, newest first, with counts and messages", :aggregate_failures do
      11.times { |i| create(:catalog_refresh_run, started_at: (20 - i).hours.ago, source_version: "v#{i}") }
      create(:catalog_refresh_run, status: "failed", started_at: 1.minute.ago, message: "IntegrityError: short file")

      lines = capture_stdout { Rake::Task["catalog:status"].invoke("mtg") }.lines

      expect(lines.size).to eq(11) # the 10 runs, then the source's own line (spec 011)
      expect(lines.last).to start_with("Art matching:")
      expect(lines.first).to include("failed", "IntegrityError: short file", "seen=0", "malformed=0")
      expect(lines.second).to include("v10", "applied", "scheduled")
    end

    it "says when there are no runs" do
      expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/No mtg refresh runs yet/).to_stdout
    end

    it "ends with the source's own status lines, such as art matching (spec 011 AC-3.11)" do
      expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/Art matching: off/).to_stdout
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
