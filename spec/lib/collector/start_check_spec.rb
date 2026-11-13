require "rails_helper"
require Rails.root.join("lib/collector/start_check").to_s

RSpec.describe Collector::StartCheck, :backup, type: :model do
  let(:volume) { scratch("volume") }
  let(:databases) { databases_for(volume) }
  let(:prices) { volume.join("production_prices.sqlite3") }
  let(:primary) { volume.join("production.sqlite3") }

  def refusal = described_class.refusal(databases:)
  def message = refusal.join(" ")
  def put(path, bytes = "stale") = path.tap { it.write(bytes) }

  describe ".refusal" do
    context "when the start may go on" do
      it "passes an empty directory (a new instance)" do
        expect(refusal).to be_nil
      end

      it "passes a primary and a prices file", :aggregate_failures do
        put(primary)
        put(prices)

        expect(refusal).to be_nil
      end

      it "passes a primary alone (an instance from before the prices database)" do
        put(primary)

        expect(refusal).to be_nil
      end

      it "passes a directory that holds only the queue, cache and cable files and their sidecars" do
        %w[production_queue production_cache production_cable].each do |name|
          [ "", "-wal", "-shm", "-journal" ].each { |suffix| put(volume.join("#{name}.sqlite3#{suffix}")) }
        end

        expect(refusal).to be_nil
      end

      it "passes a configuration with no prices path" do
        databases = Collector::Backup::Databases.new("primary" => primary)

        expect(described_class.refusal(databases:)).to be_nil
      end
    end

    context "when the volume holds orphan prices" do
      it "refuses the prices file alone, with rows or text in it", :aggregate_failures do
        put(prices, "SQLite format 3\0".b + ("x" * 100))

        expect(refusal).to be_an(Array)
        expect(message).to include(volume.to_s, prices.to_s)
      end

      it "refuses an empty prices file" do
        put(prices, "")

        expect(refusal).to be_an(Array)
      end

      %w[-wal -shm -journal].each do |suffix|
        it "refuses a prices #{suffix} file alone and names it", :aggregate_failures do
          put(volume.join("production_prices.sqlite3#{suffix}"))

          expect(refusal).to be_an(Array)
          expect(message).to include(volume.join("production_prices.sqlite3#{suffix}").to_s)
        end
      end

      it "refuses a prices file beside an empty primary and names it as an empty file to remove", :aggregate_failures do
        put(prices)
        put(primary, "")

        expect(message).to include("production.sqlite3 (an empty file)")
        expect(message).to include("production_prices.sqlite3 and its -wal, -shm and -journal files and production.sqlite3")
      end

      it "refuses a prices file beside a dangling-symlink primary and names it as a broken link", :aggregate_failures do
        put(prices)
        File.symlink(scratch_path("nowhere").to_s, primary.to_s)

        expect(message).to include("production.sqlite3 (a broken link)")
      end

      it "refuses a prices file that is a dangling symlink" do
        File.symlink(scratch_path("nowhere").to_s, prices.to_s)

        expect(refusal).to be_an(Array)
      end

      it "refuses a prices file beside only a primary sidecar and names the sidecar", :aggregate_failures do
        put(prices)
        put(volume.join("production.sqlite3-wal"))

        expect(message).to include(prices.to_s, "production.sqlite3-wal (a sidecar left behind)")
        expect(message).to include("and production.sqlite3-wal, then restore again")
      end

      it "words the three sentences of the refusal", :aggregate_failures do
        put(prices)

        expect(refusal.size).to eq(3)
        expect(message).to include(
          "storage directory #{volume}", "no primary database", "-wal, -shm and -journal",
          "restore again onto a volume that holds no other Collector database", "start Collector blank",
          "Run nothing else on the volume", "Nothing was changed"
        )
      end

      it "doesn't mention a leftover primary when there is none", :aggregate_failures do
        put(prices)

        expect(message).not_to include("instead")
        expect(refusal.first).to end_with("and no primary database.")
      end
    end

    it "never opens a file: bytes and modification times are as they were, and text that isn't a database is refused", :aggregate_failures do
      put(prices, "not a database")
      put(volume.join("production_prices.sqlite3-wal"), "not a wal")
      before = volume.children.to_h { [ it.basename.to_s, [ it.read, it.mtime ] ] }

      expect(refusal).to be_an(Array)
      expect(volume.children.to_h { [ it.basename.to_s, [ it.read, it.mtime ] ] }).to eq(before)
    end
  end

  # Decision 7: what a one-off command that connects through the application leaves on a new primary. Reported to the
  # supervisor, which records it in verification.md; the example asserts what the measurement found.
  describe "the file a bare Active Record connection leaves on a new primary (spec 086 decision 7)" do
    it "is more than an empty file", :aggregate_failures do
      path = scratch_path("measured.sqlite3")
      _out, err, status = app_command(path, "runner", "ActiveRecord::Base.lease_connection.execute('select 1')")

      expect(status).to be_success, err
      expect(File.size(path)).to be > 0
    end
  end
end
