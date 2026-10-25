require "rails_helper"

RSpec.describe Collector::Backup::Create, :backup, :committed do
  let(:directory) { scratch("out") }
  let!(:seed) { seed_instance }

  def run(into: directory, source: instance_database, clock: clock_at, **options)
    described_class.new(directory: into, source:, clock:, **options).call
  end

  it "writes one file named by the UTC second and returns its facts (AC-1.1)", :aggregate_failures do
    result = run

    expect(directory.children.map { it.basename.to_s }).to eq([ "collector-backup-20261021T142100Z.tar.gz" ])
    expect(result).to have_attributes(path: directory.join("collector-backup-20261021T142100Z.tar.gz"),
      schema_version: release_versions.max_by(&:to_i), counts: { "accounts" => 1, "users" => 1, "lots" => 3 })
    expect(result.bytes).to eq(result.path.size)
    expect(result.report).to match(/\ABackup written: .*\nSize: .*\nSchema version: \d+\nHolds: 1 account, 1 user and 3 lots\nTook: \d+\.\d s\z/)
  end

  it "holds the manifest and a rollback-journal snapshot that agrees with it, and no sidecar (AC-1.4)", :aggregate_failures do
    path = run.path
    unpacked = scratch("unpacked")
    _output, status = Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    snapshot = unpacked.join("primary.sqlite3")
    manifest = Collector::Backup::Manifest.parse(unpacked.join("manifest.json").read)

    expect(status).to be_success
    expect(unpacked.children.map { it.basename.to_s }).to match_array(%w[manifest.json primary.sqlite3])
    expect(manifest).to have_attributes(backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", snapshot_bytes: snapshot.size,
      snapshot_sha256: Digest::SHA256.file(snapshot).hexdigest, counts: { "accounts" => 1, "users" => 1, "lots" => 3 })
    expect(File.binread(snapshot, 2, 18).bytes).to eq([ 1, 1 ])
    expect(Dir["#{snapshot}-*"]).to be_empty
    expect { Collector::Backup::Snapshot.new(snapshot).verify! }.not_to raise_error
  end

  it "is private and holds no secret or setting, and nothing but the two files (AC-1.8, AC-4.1)", :aggregate_failures do
    with_env(BackupHelpers::SECRETS) { run }
    path = directory.children.sole
    unpacked = scratch("unpacked")
    listing, = Open3.capture2("tar", "-tzf", path.to_s)
    Open3.capture2("tar", "-xzf", path.to_s, "-C", unpacked.to_s)
    bytes = unpacked.children.sum("".b) { it.binread }

    expect(path.stat.mode & 0o777).to eq(0o600)
    expect(listing.lines(chomp: true)).to eq(%w[manifest.json primary.sqlite3])
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
    run_killed_at(:snapshot_written, <<~RUBY, directory, instance_database)
      Collector::Backup::Create.new(directory: ARGV[0], source: ARGV[1], checkpoint: STOP_HERE).call
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
    expect(refusal.problem).to match(/\A#{Regexp.escape(directory.to_s)} has 1 byte free; a backup needs about .* \(twice the database's size\)\.\z/)
    expect(directory.children).to be_empty
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
end
