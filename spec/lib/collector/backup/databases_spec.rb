require "rails_helper"

RSpec.describe Collector::Backup::Databases, :backup do
  describe ".configured" do
    it "reads the production databases from config/database.yml without connecting (FR-8)", :aggregate_failures do
      databases = described_class.configured(env: "production")

      expect(databases.names).to contain_exactly("primary", "cache", "queue", "cable")
      expect(databases.primary).to eq(Rails.root.join("storage/production.sqlite3"))
      expect(databases.directory).to eq(Rails.root.join("storage"))
    end

    it "reads a single-database environment as its primary", :aggregate_failures do
      databases = described_class.configured(env: "test")

      expect(databases.names).to eq([ "primary" ])
      expect(databases.primary.basename.to_s).to eq("test.sqlite3")
    end
  end

  describe "#occupied" do
    let(:directory) { scratch("volume") }
    let(:databases) { databases_for(directory) }

    it "is empty for an empty volume" do
      expect(databases.occupied).to be_empty
    end

    it "names each of the four databases and each -wal, -shm and -journal file that is there (decision 6)", :aggregate_failures do
      names = %w[production.sqlite3 production_cache.sqlite3-wal production_queue.sqlite3-shm production_cable.sqlite3-journal]
      names.each { |name| directory.join(name).write("x") }

      expect(databases.occupied.map { it.basename.to_s }).to match_array(names)
    end

    it "ignores the restore's own temporary file and its journal, and other files of the volume", :aggregate_failures do
      %w[collector-restore.partial collector-restore.partial-journal catalog.txt].each { |name| directory.join(name).write("x") }

      expect(databases.occupied).to be_empty
    end
  end
end
