require "rails_helper"
require Rails.root.join("script/upgrade/rules").to_s

RSpec.describe Upgrade::SeedExceptions, :upgrade do
  let(:dir) { upgrade_dir }

  def exceptions(body, key)
    path = File.join(dir, "seed_exceptions.yml")
    File.write(path, body)
    described_class.load(path, key)
  end

  def database_with(rows)
    open_database(build_database(File.join(dir, "seeded.sqlite3")) do |db|
      rows.each { |table, count| db.execute("CREATE TABLE #{table} (id INTEGER PRIMARY KEY)"); count.times { db.execute("INSERT INTO #{table} DEFAULT VALUES") } }
    end)
  end

  it "reads only the key asked for, a release's or next", :aggregate_failures do
    body = "\"0.2.1\":\n  - { table: mtg_artworks, reason: needs the art build }\nnext: []\n"
    expect(exceptions(body, "0.2.1").entries.map(&:table)).to eq([ "mtg_artworks" ])
    expect(exceptions(body, "next").entries).to be_empty
    expect(exceptions(body, "0.9.9").entries).to be_empty
  end

  it "names an entry without a reason" do
    expect(exceptions("next:\n  - { table: x }\n", "next").errors).to eq([ "seed_exceptions.yml next: entry 1 needs a table and a reason" ])
  end

  describe ".coverage" do
    it "fails a table without a row, naming the table and the seed file (AC-2.5, AC-2.6)", :aggregate_failures do
      problems, = described_class.coverage(database_with("lots" => 3, "locations" => 0), [], label: "next", seed: "script/upgrade/seeds/next.rb")
      expect(problems.size).to eq(1)
      expect(problems.first).to include("locations", "script/upgrade/seeds/next.rb", "seed_exceptions.yml")
    end

    it "passes a listed exception and prints it (AC-2.5)", :aggregate_failures do
      entries = [ described_class::Entry.new(table: "locations", reason: "no feature yet") ]
      problems, notes = described_class.coverage(database_with("lots" => 3, "locations" => 0), entries, label: "0.2.1", seed: "0.2.1.rb")
      expect(problems).to be_empty
      expect(notes).to eq([ "seed exception: locations (no feature yet)" ])
    end

    it "fails an exception for a table the database does not have (AC-2.5)" do
      entries = [ described_class::Entry.new(table: "ghosts", reason: "gone") ]
      problems, = described_class.coverage(database_with("lots" => 3), entries, label: "0.2.1", seed: "0.2.1.rb")
      expect(problems).to eq([ "script/upgrade/seed_exceptions.yml lists ghosts for 0.2.1, which has no such table" ])
    end

    it "looks only at the tables asked for when restricted" do
      problems, = described_class.coverage(database_with("lots" => 3, "solid_queue_jobs" => 0), [], label: "next", seed: "next.rb", only: %w[lots])
      expect(problems).to be_empty
    end
  end

  it "ships with no exception for the previous release or for next" do
    path = Rails.root.join("script/upgrade/seed_exceptions.yml")
    expect([ exceptions(path.read, "0.2.1"), exceptions(path.read, "next") ].flat_map { [ it.entries, it.errors ] }).to all(be_empty)
  end
end
