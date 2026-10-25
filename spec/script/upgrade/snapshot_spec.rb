require "rails_helper"
require Rails.root.join("script/upgrade/snapshot").to_s

RSpec.describe Upgrade::Snapshot, :upgrade do
  let(:dir) { upgrade_dir }

  # A volume whose last writes are still in the -wal file, copied while the writer is open, as a stopped container's can be.
  def volume_with_log
    source = File.join(dir, "volume")
    FileUtils.mkdir_p(source)
    writer = SQLite3::Database.new(File.join(source, "production.sqlite3"))
    writer.execute_batch("PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0; CREATE TABLE things (id INTEGER PRIMARY KEY, name); INSERT INTO things (name) VALUES ('kept')")
    copies = File.join(dir, "copies")
    FileUtils.mkdir_p(copies)
    Dir[File.join(source, "production.sqlite3*")].each { FileUtils.cp(it, copies) }
    writer.close
    copies
  end

  it "folds in a write-ahead log that the copied files came with (AC-2.4)", :aggregate_failures do
    copies = volume_with_log
    main_only = File.join(dir, "main-only")
    FileUtils.mkdir_p(main_only)
    FileUtils.cp(File.join(copies, "production.sqlite3"), main_only)
    expect(SQLite3::Database.new(File.join(main_only, "production.sqlite3")).execute("SELECT name FROM sqlite_master WHERE name = 'things'")).to be_empty
    target = described_class.consolidate(copies, "production.sqlite3", File.join(dir, "snapshot.sqlite3"))
    expect(open_database(target).execute("SELECT name FROM things")).to eq([ [ "kept" ] ])
  end

  it "fails naming the file when the main database file is missing" do
    expect { described_class.consolidate(dir, "production.sqlite3", File.join(dir, "x.sqlite3")) }
      .to raise_error(described_class::Missing, /production\.sqlite3/)
  end
end
