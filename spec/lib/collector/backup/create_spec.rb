require "rails_helper"

RSpec.describe Collector::Backup::Create, :backup, :committed do
  let(:directory) { scratch("out") }
  let!(:seed) { seed_instance }

  def run(into: directory, source: instance_database, prices_source: instance_prices_database, clock: clock_at, **options)
    described_class.new(directory: into, source:, prices_source:, clock:, **options).call
  end

  def prices_member(path)
    Collector::Backup::Manifest.parse(unpack_member(path, "manifest.json")).prices
  end

  def unpack_member(path, name)
    unpacked = scratch("member-#{SecureRandom.hex(3)}")
    Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    unpacked.join(name).read
  end

  it "writes one file named by the UTC second and returns its facts (AC-1.1)", :aggregate_failures do
    result = run

    expect(directory.children.map { it.basename.to_s }).to eq([ "collector-backup-20261021T142100Z.tar.gz" ])
    expect(result).to have_attributes(path: directory.join("collector-backup-20261021T142100Z.tar.gz"),
      schema_version: release_versions.max_by(&:to_i), counts: { "accounts" => 1, "users" => 1, "lots" => 3 },
      prices_schema_version: Collector::Backup.release_schema_versions(Rails.root, "db/prices_migrate").max_by(&:to_i),
      prices_counts: { "current_prices" => 0, "price_changes" => 0 })
    expect(result.bytes).to eq(result.path.size)
    expect(result.report).to match(/\ABackup written: .*\nSize: .*\nSchema version: \d+; prices \d+\nHolds: 1 account, 1 user and 3 lots; 0 current prices and 0 price changes\nTook: \d+\.\d s\z/)
  end

  it "holds the manifest and rollback-journal snapshots that agree with it, and no sidecar (AC-1.4, AC-4.1)", :aggregate_failures do
    path = run.path
    unpacked = scratch("unpacked")
    _output, status = Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    snapshot = unpacked.join("primary.sqlite3")
    prices = unpacked.join("prices.sqlite3")
    manifest = Collector::Backup::Manifest.parse(unpacked.join("manifest.json").read)

    expect(status).to be_success
    expect(unpacked.children.map { it.basename.to_s }).to match_array(%w[manifest.json primary.sqlite3 prices.sqlite3])
    expect(manifest).to have_attributes(backup_format_version: 2, taken_at: "2026-10-21T14:21:00Z", snapshot_bytes: snapshot.size,
      snapshot_sha256: Digest::SHA256.file(snapshot).hexdigest, counts: { "accounts" => 1, "users" => 1, "lots" => 3 })
    expect(manifest.prices).to include("snapshot_bytes" => prices.size, "snapshot_sha256" => Digest::SHA256.file(prices).hexdigest,
      "counts" => { "current_prices" => 0, "price_changes" => 0 })
    expect([ snapshot, prices ].map { File.binread(it, 2, 18).bytes }).to eq([ [ 1, 1 ], [ 1, 1 ] ])
    expect(Dir["#{snapshot}-*", "#{prices}-*"]).to be_empty
    expect { [ snapshot, prices ].each { Collector::Backup::Snapshot.new(it).verify! } }.not_to raise_error
  end

  it "is private and holds no secret or setting, and nothing but the three files (AC-1.8, AC-4.1)", :aggregate_failures do
    with_env(BackupHelpers::SECRETS) { run }
    path = directory.children.sole
    unpacked = scratch("unpacked")
    listing, = Open3.capture2("tar", "-tzf", path.to_s)
    Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    bytes = unpacked.children.sum("".b) { it.binread }

    expect(path.stat.mode & 0o777).to eq(0o600)
    expect(listing.lines(chomp: true)).to eq(%w[manifest.json primary.sqlite3 prices.sqlite3])
    BackupHelpers::SECRETS.each_value { |value| expect(bytes).not_to include(value) }
  end

  describe "while the app writes (AC-1.2, AC-1.3)" do
    let(:log) { scratch_path("writers.log") }
    let(:stop) { scratch_path("writers.stop") }
    let!(:writers) { start_writers }

    def start_writers
      FileUtils.touch(log)
      %w[pairs lots].map do |kind|
        Process.spawn(RbConfig.ruby, "-e", BackupHelpers::WRITER, instance_database.to_s, log.to_s, stop.to_s, kind, seed.user.account_id.to_s, *seed.entries.map { it.id.to_s },
          chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
      end
    end

    def commits = log.readlines(chomp: true).map(&:split)

    def stop_writers(pids)
      FileUtils.touch(stop)
      pids.each do |pid|
        Process.wait(pid)
      rescue Errno::ECHILD
        nil # already reaped
      end
    end

    # Accounts without a user, and users without an account: a half-written pair would show here, which totals could hide.
    def unpaired(path)
      sqlite(path, readonly: true) do |database|
        [ database.get_first_value("SELECT COUNT(*) FROM accounts a LEFT JOIN users u ON u.account_id = a.id WHERE u.id IS NULL"),
          database.get_first_value("SELECT COUNT(*) FROM users u LEFT JOIN accounts a ON a.id = u.account_id WHERE a.id IS NULL") ]
      end
    end

    before do
      # A database big enough for a backup to take a moment.
      Catalog::Identity.insert_all(Array.new(50_000) { |index| { collectible_type: "mtg", external_key: "filler-#{index}", name: "Filler #{index}", content_digest: "d" } })
    end

    after { stop_writers(writers) } # a failed example must not leave the children writing

    it "holds both rows of every pair or neither, passes its checks, and lets writes commit while VACUUM INTO runs", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a concurrency scenario: writers, four backups, then every snapshot read back
      Timeout.timeout(60) { sleep 0.05 until commits.count { it.first == "pairs" } >= 3 && commits.count { it.first == "lots" } >= 3 }
      committed_before = commits.select { it.first == "pairs" }.map(&:last)
      windows = []
      results = Array.new(4) do |index|
        marks = {}
        checkpoint = ->(step) { marks[step] = Process.clock_gettime(Process::CLOCK_REALTIME) }
        described_class.new(directory: scratch("out#{index}"), source: instance_database, clock: clock_at(Time.utc(2026, 10, 21, 14, 21, index)), checkpoint:).call.tap do
          windows << (marks.fetch(:snapshot_starting)..marks.fetch(:snapshot_written)) # the VACUUM INTO and nothing else
        end
      end
      stop_writers(writers)
      written = commits

      # A write that waited out the busy timeout fails with SQLITE_BUSY and logs an error row. Its wall-clock time is not
      # asserted: it includes scheduling and fsync on a loaded runner. Decision 13's measured bar is script/backup/measure.rb.
      expect(written.select { it.first == "error" }).to be_empty
      during = written.count { |_kind, _started, finished, _account| windows.any? { it.cover?(finished.to_f) } }
      expect(during).to be_positive, "no write committed while VACUUM INTO ran; the backup blocked the app's writers" # AC-1.3
      results.each_with_index do |result, index|
        snapshot = Collector::Backup::Snapshot.new(unpack_snapshot(result.path, "snapshot-#{index}.sqlite3"))

        expect { snapshot.verify! }.not_to raise_error
        expect(unpaired(snapshot.path)).to eq([ 0, 0 ]) # a pair is both rows or neither, in every snapshot
        expect(snapshot.counts.fetch("users")).to be_positive
      end
      first = sqlite(unpack_snapshot(results.first.path, "first.sqlite3"), readonly: true) { |database| database.execute("SELECT id FROM accounts").flatten }
      expect(first).to include(*committed_before.map(&:to_i))
    end
  end

  it "refuses a damaged database with a plain message and leaves nothing behind (AC-1.5)", :aggregate_failures do
    damaged = copy_of_instance("damaged.sqlite3").tap { damage_table!(it, "lots") }
    refusal = refusal_of { run(source: damaged) }

    expect(refusal.problem).to eq("The database reports damage, so no backup was made.")
    expect(refusal.message).not_to match(/SQLite|Collector::|Exception|\.rb/)
    expect(directory.children).to be_empty
  end

  it "leaves at worst a private .partial file when it is killed with the snapshot written (AC-1.6)", :aggregate_failures do
    run_killed_at(:snapshot_written, <<~RUBY, directory, instance_database, instance_prices_database)
      Collector::Backup::Create.new(directory: ARGV[0], source: ARGV[1], prices_source: ARGV[2], checkpoint: STOP_HERE).call
    RUBY

    leftovers = directory.children
    expect(leftovers.map { it.basename.to_s }).to all(match(described_class::PARTIAL))
    expect(leftovers.size).to eq(1)
    expect(leftovers.first.stat.mode & 0o777).to eq(0o600)
  end

  it "removes a .partial file more than a day old on the next run and leaves a younger one (AC-1.6)", :aggregate_failures do
    old = directory.join("collector-backup-20260101T000000Z.tar.gz.0123456789abcdef.partial").tap { it.write("x") }
    old_sidecars = %w[-journal -wal -shm].map { |suffix| directory.join("collector-backup-20260101T000000Z.sqlite3.0123456789abcdef.partial#{suffix}").tap { it.write("s") } }
    young = directory.join("collector-backup-20260102T000000Z.sqlite3.fedcba9876543210.partial").tap { it.write("y") }
    young_sidecar = directory.join("collector-backup-20260102T000000Z.sqlite3.fedcba9876543210.partial-shm").tap { it.write("t") }
    other = directory.join("notes.partial").tap { it.write("z") }
    [ old, *old_sidecars ].each { File.utime(26.hours.ago.to_time, 26.hours.ago.to_time, it) }

    run

    expect([ old, *old_sidecars ]).to all(satisfy { !it.exist? }) # a killed run's sidecars go with it
    expect([ young, young_sidecar, other ]).to all(exist)
  end

  it "never replaces a file with the name it would use, and leaves no .partial (AC-1.9)", :aggregate_failures do
    taken = directory.join("collector-backup-20261021T142100Z.tar.gz").tap { it.write("someone else's file") }
    refusal = refusal_of { run }

    expect(refusal.problem).to eq("A file named collector-backup-20261021T142100Z.tar.gz already exists in #{directory}; it was left as it is.")
    expect(refusal.advice).to eq("Run it again in a second, or give another directory.")
    expect(taken.read).to eq("someone else's file")
    expect(directory.children).to eq([ taken ])
  end

  it "gives two runs started together one file between them and the clash message for the other (AC-1.9)", :aggregate_failures do
    outcomes = Array.new(2) { Thread.new { refusal_of { run } } }.map(&:value)

    expect(outcomes.count(nil)).to eq(1)
    expect(outcomes.compact.sole.problem).to include("already exists")
    expect(directory.children.size).to eq(1)
    expect { Collector::Backup::Archive.read(directory.children.first) }.not_to raise_error
  end

  it "refuses a directory that doesn't exist, can't be written or has too little room, writing nothing (AC-1.11)", :aggregate_failures do
    missing = scratch_path("not-there")
    expect(refusal_of { run(into: missing) }.problem).to eq("#{missing} doesn't exist or isn't a directory.")

    unless Process.uid.zero?
      locked = scratch("locked").tap { it.chmod(0o500) }
      expect(refusal_of { run(into: locked) }.problem).to eq("#{locked} isn't writable by the user Collector runs as (uid #{Process.uid}).")
      expect(locked.children).to be_empty
    end

    refusal = refusal_of { run(free_space: ->(_path) { 1 }) }
    expect(refusal.problem).to match(/\A#{Regexp.escape(directory.to_s)} has 1 byte free; a backup needs about .* \(twice the two databases' sizes\)\.\z/)
    expect(directory.children).to be_empty
  end

  it "refuses a free-space need of twice the two databases, and one byte less than that fails (AC-4.6)", :aggregate_failures do
    need = 2 * (instance_database.size + instance_prices_database.size)
    refusal = refusal_of { run(free_space: ->(_path) { need - 1 }) }

    expect(refusal.problem).to include("a backup needs about #{Collector::Backup.size_phrase(need)} (twice the two databases' sizes)")
    expect(directory.children).to be_empty
    expect { run(free_space: ->(_path) { need }) }.not_to raise_error
  end

  it "refuses a source that isn't there without creating it", :aggregate_failures do
    missing = scratch_path("no-primary.sqlite3")

    expect(refusal_of { run(source: missing) }.problem).to eq("There is no primary database at #{missing}.")
    expect(missing).not_to exist
  end

  it "refuses a database that fails its foreign-key check and points to the exports (AC-1.12)", :aggregate_failures do
    orphaned = copy_of_instance("orphaned.sqlite3")
    sqlite(orphaned) do |database|
      database.execute("PRAGMA foreign_keys = OFF")
      database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', '2026-10-21 14:21:00', '2026-10-21 14:21:00')")
    end
    refusal = refusal_of { run(source: orphaned) }

    expect(refusal.problem).to eq("The database fails its foreign-key check (1 row), so no backup was made.")
    expect(refusal.advice).to include("Export collection")
    expect(directory.children).to be_empty
  end

  describe "the prices database (spec 081 decision 7)" do
    def seed_two_prices
      seed_prices(entry_ids: seed.entries.first(2).map(&:id), current: 2)
    end

    it "holds the prices rows in a rollback-journal file that passes its checks, and reports them (AC-4.1, AC-4.3, AC-4.7)", :aggregate_failures do
      seed_two_prices
      result = run
      snapshot = unpack_snapshot(result.path, "prices.sqlite3", entry: "prices.sqlite3")

      expect(table_rows(snapshot)).to eq(table_rows(instance_prices_database))
      expect(File.binread(snapshot, 2, 18).bytes).to eq([ 1, 1 ])
      expect { Collector::Backup::Snapshot.new(snapshot).verify! }.not_to raise_error
      expect(prices_member(result.path)["counts"]).to eq("current_prices" => 2, "price_changes" => 0)
      expect(result.report.lines(chomp: true)[2..3]).to match([ /\ASchema version: \d+; prices \d+\z/, "Holds: 1 account, 1 user and 3 lots; 2 current prices and 0 price changes" ])
    end

    it "refuses a prices source that isn't there, creating nothing (AC-4.4)", :aggregate_failures do
      missing = scratch_path("no-prices.sqlite3")
      refusal = refusal_of { run(prices_source: missing) }

      expect(refusal.problem).to eq("There is no prices database at #{missing}.")
      expect(refusal.advice).to eq("Start Collector once on this release, which creates it, then run this again.")
      expect([ missing.exist?, directory.children ]).to eq([ false, [] ])
    end

    it "refuses a damaged prices database, naming it, and leaves nothing (AC-4.5)", :aggregate_failures do
      seed_two_prices
      damaged = scratch_path("damaged-prices.sqlite3").tap { Collector::Backup::Snapshot.take(source: instance_prices_database, into: it) }
      damage_table!(damaged, "price_sources")
      refusal = refusal_of { run(prices_source: damaged) }

      expect(refusal.problem).to eq("The prices database reports damage, so no backup was made.")
      expect(directory.children).to be_empty
    end

    it "refuses a prices database that fails its foreign-key check, counting the rows (AC-4.5)", :aggregate_failures do
      broken = scratch_path("orphaned-prices.sqlite3").tap { Collector::Backup::Snapshot.take(source: instance_prices_database, into: it) }
      sqlite(broken) do |database|
        database.execute("INSERT INTO price_sources (id, key, name, attribution, created_at, updated_at) VALUES (1, 'k', 'n', 'a', '2026-10-21', '2026-10-21')")
        database.execute("PRAGMA foreign_keys = OFF")
        3.times { |index| database.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) VALUES (?, 1, 999, '2026-10-21', 5)", [ index + 1 ]) }
      end
      refusal = refusal_of { run(prices_source: broken) }

      expect(refusal.problem).to eq("The prices database fails its foreign-key check (3 rows), so no backup was made.")
      expect(directory.children).to be_empty
    end
  end

  describe "while the prices writer commits (AC-4.8)" do
    let(:log) { scratch_path("prices-writer.log") }
    let(:stop) { scratch_path("prices-writer.stop") }

    it "keeps committing price changes while the prices snapshot is taken", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- a concurrency scenario: a writer, a measured backup, then the log
      FileUtils.touch(log)
      PricesRecord.lease_connection.execute("INSERT INTO price_sources (id, key, name, attribution, created_at, updated_at) VALUES (1, 'k', 'n', 'a', '2026-10-21', '2026-10-21')")
      PricesRecord.lease_connection.execute("INSERT INTO price_series (id, finish, currency, kind, created_at, updated_at) VALUES (1, 'nonfoil', 'USD', 'market', '2026-10-21', '2026-10-21')")
      PricesRecord.lease_connection.execute("INSERT INTO price_changes (catalog_entry_id, price_source_id, price_series_id, recorded_on, cents) WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 50000) SELECT -i, 1, 1, '2026-10-20', i FROM n")
      pid = Process.spawn(RbConfig.ruby, "-e", BackupHelpers::WRITER, instance_prices_database.to_s, log.to_s, stop.to_s, "prices", "0", "0",
        chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
      Timeout.timeout(60) { sleep 0.05 until log.readlines.size >= 3 }
      marks = {}
      checkpoint = ->(step) { marks[step] = Process.clock_gettime(Process::CLOCK_REALTIME) }
      begin
        run(checkpoint:)
      ensure
        FileUtils.touch(stop) # a failed run must not leave the child writing
        Process.wait(pid)
      end
      rows = log.readlines(chomp: true).map(&:split)
      window = marks.fetch(:prices_starting)..marks.fetch(:prices_written)

      expect(rows.select { it.first == "error" }).to be_empty
      expect(rows.map { |_kind, started, finished| finished.to_f - started.to_f }).to all(be < 5), "a price change waited past the 5-second busy timeout"
      expect(rows.count { |_kind, _started, finished| window.cover?(finished.to_f) }).to be_positive, "no price change committed while the prices snapshot was taken"
    end
  end
end
