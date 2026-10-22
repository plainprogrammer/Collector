require Rails.root.join("lib/collector/backup").to_s
require "open3"
require "rbconfig"
require "tmpdir"

# Support for spec 030's examples (decision 9 layer 1, AC-5.4). Tag a group :backup for the helpers and a scratch
# directory removed after each example; add :committed when the example commits rows (VACUUM INTO can't run inside a
# transaction and the writers of AC-1.2 and AC-1.3 use their own connections), which empties the test database
# before and after it.
module BackupHelpers
  PRODUCTION_NAMES = { "primary" => "production.sqlite3", "cache" => "production_cache.sqlite3",
    "queue" => "production_queue.sqlite3", "cable" => "production_cable.sqlite3" }.freeze
  SECRETS = { "SECRET_KEY_BASE" => "sk-recognisable-secret-key-base-value-30303",
    "RAILS_MASTER_KEY" => "mk-recognisable-master-key-value-40404",
    "COLLECTOR_TRUSTED_PROXIES" => "198.51.100.77" }.freeze
  Seed = Data.define(:user, :entries, :lots, :values)

  def scratch_root = (@scratch_root ||= Pathname(Dir.mktmpdir("collector-backup-spec")))

  # A directory under the example's scratch root, created. Several names make several directories.
  def scratch(name) = scratch_root.join(name).tap(&:mkpath)

  # A path under the scratch root that isn't created.
  def scratch_path(name) = scratch_root.join(name)

  def remove_scratch!
    return unless @scratch_root

    @scratch_root.glob("**/*").select(&:directory?).each { it.chmod(0o755) }
    FileUtils.remove_entry(@scratch_root, true)
    @scratch_root = nil
  end

  def production_paths(directory) = PRODUCTION_NAMES.transform_values { directory.join(it) }
  def databases_for(directory) = Collector::Backup::Databases.new(production_paths(directory))
  def instance_database = Collector::Backup::Databases.configured.primary
  def release_versions = Collector::Backup.release_schema_versions

  # The examples' clock: the second a backup is taken (decision 5's file name).
  def clock_at(time = Time.utc(2026, 10, 21, 14, 21, 0)) = Struct.new(:now).new(time)

  # Recognisable values, so that AC-1.7 and AC-1.8 can search for them.
  def seed_instance(lots: 3)
    user = create(:user, name: "Zebra Quartz", email_address: "zebra.quartz@example.test")
    entries = Array.new(lots) { |index| create(:mtg_printing, entry: create(:catalog_entry, name: "Zebra Quartz Dragon #{index}")).entry }
    made = entries.map { |entry| create(:lot, account: user.account, entry:, quantity: 2) }
    Seed.new(user:, entries:, lots: made, values: [ "Zebra Quartz", "zebra.quartz@example.test", "Zebra Quartz Dragon" ])
  end

  # A session with a pending bulk selection (a mark) and a bulk removal, the working state a restore clears (decision 3).
  def seed_session(user, lot)
    session = user.sessions.create!(ip_address: "203.0.113.9", user_agent: "RSpec")
    BulkSelection.for(session).marks.create!(account: user.account, lot:)
    BulkRemoval.create!(session:, account: user.account, copies: 1)
    session
  end

  def create_backup(into: scratch("backups"), source: instance_database, clock: clock_at, **options)
    Collector::Backup::Create.new(directory: into, source:, clock:, **options).call.path
  end

  def restore_backup(file, volume: scratch("volume"), **options)
    Collector::Backup::Restore.new(file:, databases: databases_for(volume), release_versions:, **options).call
  end

  # The manifest of a snapshot file built by hand (a damaged or altered one), not made by backup:create.
  def manifest_for(snapshot_path, **changes)
    snapshot = Collector::Backup::Snapshot.new(snapshot_path)
    fields = { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: release_versions.max_by(&:to_i),
      snapshot_bytes: snapshot_path.size, snapshot_sha256: Digest::SHA256.file(snapshot_path).hexdigest,
      counts: { "accounts" => 0, "users" => 0, "lots" => 0 } }
    fields[:counts] = snapshot.counts unless changes.key?(:counts)
    Collector::Backup::Manifest.new(**fields.merge(changes))
  end

  # An archive built by hand around a snapshot file, with a correct manifest unless changes say otherwise.
  def archive_of(snapshot_path, into: scratch("archives"), name: "collector-backup-20261021T142100Z.tar.gz", **changes)
    into.join(name).tap { Collector::Backup::Archive.write(it, manifest: manifest_for(snapshot_path, **changes), snapshot: snapshot_path) }
  end

  # A .tar.gz built by hand from [name, bytes] pairs, for the files AC-3.3 and AC-3.4 refuse.
  def raw_archive(*entries, into: scratch("archives"), name: "collector-backup-20261021T142100Z.tar.gz")
    into.join(name).tap do |path|
      File.open(path, "wb") do |file|
        gzip = Zlib::GzipWriter.new(file)
        tar = Gem::Package::TarWriter.new(gzip)
        entries.each { |entry_name, bytes| tar.add_file_simple(entry_name, 0o600, bytes.bytesize) { it.write(bytes) } }
        tar.close
        gzip.finish
      end
    end
  end

  # A copy of the test database (schema, and the rows committed so far), made with VACUUM INTO as a backup does.
  def copy_of_instance(name = "copy.sqlite3")
    scratch_path(name).tap { |path| Collector::Backup::Snapshot.take(source: instance_database, into: path) }
  end

  def sqlite(path, readonly: false)
    SQLite3::Database.new(path.to_s, readonly:).tap { it.busy_timeout = 5_000 }.then do |db|
      yield db
    ensure
      db.close
    end
  end

  # Overwrites the root page of a table, so that the b-tree can't be read (AC-1.5, AC-3.7).
  def damage_table!(path, table)
    root, size = sqlite(path) { |db| [ db.get_first_value("SELECT rootpage FROM sqlite_master WHERE name = ?", [ table ]), db.get_first_value("PRAGMA page_size") ] }
    File.open(path, "r+b") { |file| file.seek((root - 1) * size) && file.write("\xFF".b * size) }
  end

  # Runs +code+ in a plain Ruby child that has loaded the backup library and is stopped (SIGKILL) when the command
  # reaches +step+ (its checkpoint). A real kill, not a rescued exception: no ensure block runs (AC-1.6, AC-2.6).
  def run_killed_at(step, code, *arguments)
    prelude = <<~RUBY
      require "bundler/setup"
      require "json"
      require "collector/backup"
      STEP = ARGV.shift.to_sym
      STOP_HERE = ->(reached) { Process.kill("KILL", Process.pid) if reached == STEP }
    RUBY
    pid = Process.spawn(RbConfig.ruby, "-I", Rails.root.join("lib").to_s, "-e", prelude + code, step.to_s, *arguments.map(&:to_s),
      chdir: Rails.root.to_s, out: File::NULL, err: File::NULL)
    status = Process.wait2(pid).last
    expect(status.signaled? && status.termsig == 9).to be(true), "the run wasn't stopped at #{step}: #{status.inspect}"
  end

  # A child Rails process on a database file: the application as a booted instance would be (AC-2.2, AC-3.6). DATABASE_URL
  # is Rails' own setting, so the application gets no setting of its own. SCHEMA keeps a migration from rewriting db/schema.rb.
  def app_command(database, *command, environment: {})
    env = { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{database}", "SCHEMA" => scratch_path("schema-dump.rb").to_s }.merge(environment)
    Open3.capture3(env, Rails.root.join("bin/rails").to_s, *command, chdir: Rails.root.to_s)
  end

  # Empties every table the application knows (not the FTS5 index's shadow tables, which a DELETE would corrupt; no spec
  # of this feature creates catalog names), leaving the schema and its versions.
  def clear_instance!
    connection = ActiveRecord::Base.connection
    keep = %w[schema_migrations ar_internal_metadata]
    connection.disable_referential_integrity do
      (connection.tables - keep).grep_v(/\Acatalog_names_fts/).each { |table| connection.execute("DELETE FROM #{connection.quote_table_name(table)}") }
    end
  end

  # The Refusal a block raises, or nil when it doesn't raise one.
  def refusal_of
    yield
    nil
  rescue Collector::Backup::Refusal => refusal
    refusal
  end

  def with_env(values)
    saved = values.keys.to_h { [ it, ENV[it] ] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  # Every file of a directory by name and SHA-256: "every file is as it was" (AC-2.5, AC-3.x).
  def checksums(directory)
    directory.children.select(&:file?).to_h { [ it.basename.to_s, Digest::SHA256.file(it).hexdigest ] }
  end

  # Every table's rows as sorted strings, for comparing two databases table by table (AC-2.1, AC-2.7).
  def table_rows(path)
    sqlite(path, readonly: true) do |database|
      database.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name").flatten
        .to_h { |table| [ table, database.execute("SELECT * FROM #{table}").map(&:inspect).sort ] }
    end
  end

  # The snapshot inside an archive, written out to a scratch file.
  def unpack_snapshot(archive, name = "unpacked.sqlite3")
    scratch_path(name).tap { |path| File.open(path, "wb") { |file| Collector::Backup::Archive.read(archive) { file.write(it) } } }
  end

  def captured_streams
    out, err = StringIO.new, StringIO.new
    original = [ $stdout, $stderr ]
    $stdout, $stderr = out, err
    status = 0
    begin
      yield
    rescue SystemExit => stopped
      status = stopped.status
    end
    [ out.string, err.string, status ]
  ensure
    $stdout, $stderr = original
  end

  # What Rails logged while the block ran (the commands log nothing, AC-1.7).
  def captured_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end

RSpec.shared_context "with a committed instance" do
  self.use_transactional_tests = false

  before { clear_instance! }
  after { clear_instance! }
end

RSpec.configure do |config|
  config.include BackupHelpers, :backup
  config.include_context "with a committed instance", :committed
  config.after(:each, :backup) { remove_scratch! }
end
