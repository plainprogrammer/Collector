require "rails_helper"
require Rails.root.join("script/upgrade/harness").to_s

RSpec.describe Upgrade::Harness, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:root) { File.join(dir, "checkout") }
  let(:out) { StringIO.new }
  let(:log) { [] }
  let(:old_migrations) { %w[20261001000001] }
  let(:all_migrations) { %w[20261001000001 20261002000001] }
  let(:options) { described_class::Options.new(timeout: 60, boot_attempts: 2, repository: "ghcr.io/plainprogrammer/collector") }
  let(:pages) do
    { "/registration/new" => FakeWeb::Response.new(200, '<input name="user[email_address]">'),
      "/collection" => ->(user) { FakeWeb::Response.new(200, user == "ada@x.test" ? "Dragon One Dragon Two" : '<p class="c-empty">No cards in your collection yet.</p>') },
      "/collection/export" => FakeWeb::Response.new(200, JSON.generate("format_version" => 2, "lots" => Array.new(2001) { {} })) }
  end
  let(:web) { FakeWeb.new(pages:, log:) }
  let(:databases) { [ seeded("old", old_migrations), seeded("upgraded", all_migrations), seeded("next", all_migrations) ] }
  let(:engine) { FakeEngine.new(databases:, log:) }

  before do
    build_history(root, "v0.2.1" => { "db/migrate/20261001000001_create_a.rb" => "a\n", "script/upgrade/seeds/0.2.1.rb" => "# fake seed\n",
      "script/upgrade/seeds/next.rb" => "# fake seed\n", "script/upgrade/seed_exceptions.yml" => "\"0.2.1\": []\nnext: []\n",
      "script/upgrade/expected_changes.yml" => "changes: []\n", "app/models/export_format/v2.schema.json" => "{}\n" },
      "work" => { "db/migrate/20261002000001_create_b.rb" => "b\n" })
  end

  # A seeded database as a release makes it (accounts, users, 2,000 lots, sign-up open), with the given migrations recorded.
  def seeded(name, versions, lots: 2000, extra: "")
    build_database(File.join(dir, "#{name}.sqlite3")) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE accounts (id INTEGER PRIMARY KEY); CREATE TABLE users (id INTEGER PRIMARY KEY, password_digest TEXT);
        CREATE TABLE lots (id INTEGER PRIMARY KEY, account_id INTEGER); CREATE TABLE instance_settings (id INTEGER PRIMARY KEY, sign_up_open BOOLEAN);
        CREATE TABLE schema_migrations (version TEXT PRIMARY KEY);
        INSERT INTO accounts VALUES (1), (2); INSERT INTO users VALUES (1, 'x'), (2, 'y'); INSERT INTO instance_settings VALUES (1, 1);
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < #{lots}) INSERT INTO lots SELECT i, 1 FROM n;
        #{versions.map { "INSERT INTO schema_migrations VALUES ('#{it}');" }.join}
        #{extra}
      SQL
    end
  end


  def harness(previous: "auto", engine: self.engine, env: { "GITHUB_ACTIONS" => "true" }, options: self.options, release: Upgrade::Release.new(root, env:))
    described_class.new(previous:, current: "collector:smoke", release:, engine:, options:, web: web.method(:new_client), out:, root:, sleeper: ->(_) { })
  end

  it "proves a clean upgrade, in AC-2.9's order, and prints the comparison (AC-4.1, AC-7.3)", :aggregate_failures do
    expect(harness.call).to eq(0)
    starts = log.each_index.select { log[it] == :start }
    upgrade_start = starts.fetch(1)
    snapshot = log.each_index.find { it > upgrade_start && log[it] == :copy_database }
    expect(log[upgrade_start..snapshot]).not_to include(:runner, :sign_in, :get)
    expect(out.string).to match(/lots\s+old\s+2000\s+new\s+2000\s+same/)
    expect(out.string).to include("== upgrade", "== snapshot and compare", "== behaviour", "skipped").and match(/^OK: v0\.2\.1/)
  end

  it "prints 'no previous release' and touches no container when there is none (AC-1.2)", :aggregate_failures do
    empty = File.join(dir, "empty")
    build_history(empty, "work" => { "f" => "x" })
    expect(harness(release: Upgrade::Release.new(empty, env: { "GITHUB_ACTIONS" => "true" })).call).to eq(0)
    expect(engine.calls).to be_empty
    expect(out.string).to include("no previous release")
  end

  it "pulls the exact version tag for the platform and prints the digest and revision (AC-1.3)", :aggregate_failures do
    options.platform = "linux/arm64"
    harness.call
    expect(engine.calls.first).to eq([ :pull, [ "ghcr.io/plainprogrammer/collector:0.2.1" ], { platform: "linux/arm64" } ])
    expect(out.string).to include("v0.2.1", "sha256:abc123", "version 0.2.1", "deadbeef")
  end

  it "fails naming the tag and the platform, without a retry or a fallback, when the image has no manifest (AC-1.4)", :aggregate_failures do
    engine = FakeEngine.new(pull: FakeEngine::Result.new("", "Error: manifest unknown\n", 1))
    options.platform = "linux/arm64"
    expect(harness(engine:).call).to eq(1)
    expect(engine.names.count(:pull)).to eq(1)
    expect(out.string).to include("FAIL: pull", "v0.2.1", "linux/arm64", "manifest unknown")
  end

  it "does not retry the 403 ghcr.io answers for a repository that does not exist or a credential without read access (AC-1.4, hand run)", :aggregate_failures do
    wording = "Error: unable to copy from source docker://ghcr.io/x/y:0.2.1: fetching manifest 0.2.1 in ghcr.io/x/y: Requesting bearer token: received unexpected HTTP status: 403 Forbidden\n"
    engine = FakeEngine.new(pull: FakeEngine::Result.new("", wording, 1))
    expect(harness(engine:).call).to eq(1)
    expect(engine.names.count(:pull)).to eq(1)
    expect(out.string).to include("FAIL: pull", "403 Forbidden")
  end

  it "tries a transient pull failure three times, waiting between, then fails naming the registry's last answer (AC-1.5)", :aggregate_failures do
    waits = []
    engine = FakeEngine.new(pull: FakeEngine::Result.new("", "dial tcp: i/o timeout\n", 1))
    harness = described_class.new(previous: "auto", current: "collector:smoke", release: Upgrade::Release.new(root, env: { "GITHUB_ACTIONS" => "true" }),
      engine:, options:, web: web.method(:new_client), out:, root:, sleeper: ->(seconds) { waits << seconds })
    expect(harness.call).to eq(1)
    expect([ engine.names.count(:pull), waits.size ]).to eq([ 3, 2 ])
    expect(out.string).to include("ghcr.io", "i/o timeout")
  end

  it "fails before booting anything when the previous release has no seed, naming the file and the release step (AC-2.7)", :aggregate_failures do
    File.delete(File.join(root, "script/upgrade/seeds/0.2.1.rb"))
    expect(harness.call).to eq(1)
    expect(engine.names).not_to include(:start)
    expect(out.string).to include("script/upgrade/seeds/0.2.1.rb", "docs/releasing.md")
  end

  it "fails with the seed's error rather than comparing a half-filled database (AC-2.8)", :aggregate_failures do
    engine = FakeEngine.new(databases:, runner: FakeEngine::Result.new("", "NoMethodError: undefined method 'x'\n", 1))
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("FAIL: seed", "v0.2.1", "NoMethodError")
    expect(engine.names).not_to include(:copy_database)
  end

  it "fails naming the container when it was killed at the end of the grace period (AC-2.4)", :aggregate_failures do
    engine = FakeEngine.new(databases:, state: { running: false, exit_code: 137 })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to match(/upgrade-smoke-\d+-previous stopped with status 137/)
  end

  it "fails when the old database was not made by the previous release (AC-2.1)", :aggregate_failures do
    engine = FakeEngine.new(databases: [ seeded("wrong", %w[20261001000001 20269999999999]) ])
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("AC-2.1", "20269999999999")
  end

  it "fails when a table of the previous release got no rows from the seed (AC-2.5)" do
    bare = build_database(File.join(dir, "bare.sqlite3")) { |db| db.execute_batch("CREATE TABLE schema_migrations (version TEXT); INSERT INTO schema_migrations VALUES ('20261001000001'); CREATE TABLE things (id INTEGER PRIMARY KEY)") }
    harness(engine: FakeEngine.new(databases: [ bare ])).call
    expect(out.string).to include("table things has no row after script/upgrade/seeds/0.2.1.rb")
  end

  it "names the migration and the release when the upgraded container exits before /up (AC-3.3)", :aggregate_failures do
    up = [ 200, 200, 0 ] # the previous boot, the pre-stop pages, then the upgraded container never answers
    pages["/up"] = ->(_user) { FakeWeb::Response.new(up.length > 1 ? up.shift : up.first, "") }
    states = [ { running: true, exit_code: 0 }, { running: false, exit_code: 1 } ]
    migrating = "== 20261002000001 CreateB: migrating =====\nSQLite3::ConstraintException: boom\n"
    engine = FakeEngine.new(databases:, state: ->(*) { states.shift }, logs: migrating)
    options.boot_attempts = 1
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("v0.2.1", "20261002000001 CreateB", "boom")
  end

  it "fails naming the table and the first key when the upgrade loses a row (AC-4.2, AC-7.5)", :aggregate_failures do
    thin = seeded("thin", all_migrations, lots: 1999)
    expect(harness(engine: FakeEngine.new(databases: [ databases[0], thin, databases[2] ])).call).to eq(1)
    expect(out.string).to include("FAIL lots", "id = 2000", "fix it, or list the change")
    expect(out.string).to match(/previous: v0\.2\.1 .*sha256:abc123/)
    expect(out.string).to include("commit: #{Upgrade::Release.new(root).head}", "reproduce: bin/upgrade-smoke ghcr.io/plainprogrammer/collector:0.2.1 collector:smoke")
  end

  it "fails when a collector can't sign in with their old password (AC-5.1)", :aggregate_failures do
    web.sign_in_ok = false
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.1", "collector 1 of 2")
    expect(out.string).not_to include("ada@x.test")
  end

  it "fails when the upgraded database lacks a migration of the code under test (AC-3.2)", :aggregate_failures do
    unmigrated = seeded("unmigrated", old_migrations)
    expect(harness(engine: FakeEngine.new(databases: [ databases[0], unmigrated ])).call).to eq(1)
    expect(out.string).to include("AC-3.2", "20261002000001")
  end

  it "fails when the collector's own page lacks a card name, or shows it to another collector (AC-5.2)", :aggregate_failures do
    pages["/collection"] = ->(_user) { FakeWeb::Response.new(200, "Dragon One") }
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.2", "1 of the 2 seeded names")
    expect(out.string).not_to include("Dragon Two")
  end

  it "fails when a collector with no cards sees an error page and not the empty collection (AC-5.2)", :aggregate_failures do
    pages["/collection"] = ->(user) { FakeWeb::Response.new(200, user == "ada@x.test" ? "Dragon One Dragon Two" : "<h1>Something went wrong</h1>") }
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.2", "empty collection")
  end

  it "fails when a seeded location is not listed, and passes when it is (AC-5.4)", :aggregate_failures do
    facts = FakeEngine::FACTS.merge("locations" => [ "Binder A" ])
    pages["/locations"] = FakeWeb::Response.new(200, "Shelf B")
    expect(harness(engine: FakeEngine.new(databases:, facts:)).call).to eq(1)
    expect(out.string).to include("AC-5.4", "1 of the 1 seeded locations")
    expect(out.string).not_to include("Binder A")
  end

  it "fails when the export holds fewer lots than were seeded, or names a version it has no schema for (AC-5.5)", :aggregate_failures do
    pages["/collection/export"] = FakeWeb::Response.new(200, JSON.generate("format_version" => 2, "lots" => [ {} ]))
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.5", "holds 1 lots, the seed made 2001")
  end

  it "fails when the recurring tasks are not all registered, after waiting for them (AC-5.6)", :aggregate_failures do
    engine = FakeEngine.new(databases:, runner_answers: { /RecurringTask/ => FakeEngine::Result.new("false\n", "", 0) })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("AC-5.6")
    expect(engine.names.count(:runner)).to be > 30
  end

  it "fails when the seeded scheduled job isn't in the queue before the stop (AC-2.3)", :aggregate_failures do
    missing = FakeEngine.new(databases:, runner_answers: { /arguments LIKE/ => FakeEngine::Result.new("0\n", "", 0) })
    expect(harness(engine: missing).call).to eq(1)
    expect(out.string).to include("the seed's scheduled job")
  end

  it "fails when the scheduled job is gone from the queue after the upgrade (AC-5.7)", :aggregate_failures do
    counts = [ "1\n", "0\n" ] # before the stop, then after the upgrade
    gone = FakeEngine.new(databases:, runner_answers: { /arguments LIKE/ => -> { FakeEngine::Result.new(counts.shift || "0\n", "", 0) } })
    expect(harness(engine: gone).call).to eq(1)
    expect(out.string).to include("AC-5.7: the scheduled job upgrade-marker is no longer in the queue (found 0)")
  end

  it "fails when a job enqueued on the upgraded instance has no row in the queue database (AC-5.7)", :aggregate_failures do
    unrowed = FakeEngine.new(databases:, runner_answers: { /perform_later/ => FakeEngine::Result.new("false\n", "", 0) })
    expect(harness(engine: unrowed).call).to eq(1)
    expect(out.string).to include("has no row in solid_queue_jobs")
  end

  it "fails when the sign-up page differs after the upgrade (AC-5.3)", :aggregate_failures do
    shown = [ FakeWeb::Response.new(200, '<input name="user[email_address]">'), FakeWeb::Response.new(200, "closed") ]
    pages["/registration/new"] = ->(_user) { shown.length > 1 ? shown.shift : shown.first }
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.3")
  end

  it "fails the run when the check exceeds its time limit, printing the time (AC-7.4)", :aggregate_failures do
    options.timeout = 1
    engine = FakeEngine.new(databases:, start: ->(*, **) { sleep 3 })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to match(/exceeded 1 s \(elapsed \d+ s\)/)
  end

  it "reports an error of no expected kind with the same evidence lines (AC-7.5, Error Scenarios)", :aggregate_failures do
    broken = FakeEngine.new(databases:, runner: FakeEngine::Result.new("UPGRADE-SEED-COMPLETE {not json", "", 0))
    expect(harness(engine: broken).call).to eq(1)
    expect(out.string).to match(/^FAIL: .*JSON::ParserError/).and include("reproduce:")
  end

  it "removes every container, volume and the scratch directory on success and on failure (AC-7.3, FR-6)", :aggregate_failures do
    harness.call
    started = engine.calls.select { it.first == :start }.map { it[2][:name] }
    expect(engine.calls.select { it.first == :remove }.map { it[1].first }.uniq).to match_array(started)
    expect(engine.names).to include(:remove_volume, :remove_directory)
    failing = FakeEngine.new(databases: [ databases[0] ], runner: FakeEngine::Result.new("", "boom", 1))
    harness(engine: failing).call
    expect(failing.names).to include(:remove, :remove_volume, :remove_directory)
  end

  it "removes its temporary directory" do
    before = Dir.glob(File.join(Dir.tmpdir, "upgrade-smoke*"))
    harness.call
    expect(Dir.glob(File.join(Dir.tmpdir, "upgrade-smoke*"))).to eq(before)
  end

  it "cleans up when the runner kills the step with SIGTERM, and leaves the process's own handler as it found it (AC-7.3, FR-6)", :aggregate_failures do
    killed = FakeEngine.new(databases:, log:, start: ->(*, **) { Process.kill("TERM", Process.pid); sleep 5 })
    own = proc { }
    handler = Signal.trap("TERM", &own)
    begin
      expect { harness(engine: killed).call }.to raise_error(Interrupt)
      expect(killed.names).to include(:remove_volume)
      expect(Signal.trap("TERM", handler)).to eq(own)
    ensure
      Signal.trap("TERM", handler)
    end
  end

  describe "the backup leg" do
    let(:listing) { FakeEngine::Result.new("rails backup:create[DIRECTORY]  # Back up\nrails backup:restore[FILE]  # Restore\n", "", 0) }
    let(:sessions) { "CREATE TABLE sessions (id INTEGER PRIMARY KEY); INSERT INTO sessions VALUES (1), (2);" }
    let(:ended) { "CREATE TABLE sessions (id INTEGER PRIMARY KEY);" }
    let(:leg_databases) { [ seeded("old2", old_migrations, extra: sessions), seeded("upgraded2", all_migrations, extra: sessions), seeded("restored", all_migrations, extra: ended), databases[2] ] }

    it "backs up with the previous release, restores with the code under test under another secret, and compares (AC-6.1, AC-6.2)", :aggregate_failures do
      engine = FakeEngine.new(databases: leg_databases, tasks: listing)
      expect(harness(engine:).call).to eq(0)
      expect(engine.calls.find { it.first == :task }[1]).to eq([ "upgrade-smoke-#{Process.pid}-previous", "backup:create[/backups]" ])
      restore = engine.calls.find { it.first == :restore }[2]
      expect(restore).to include(image: "collector:smoke", file: "collector-backup-1.tar.gz")
      secrets = engine.calls.select { it.first == :start }.map { it[2][:secret] }
      expect(secrets[1]).to eq(secrets[0])
      expect(secrets[3]).not_to eq(secrets[0])
      expect(out.string).to include("== backup leg").and match(/^sessions\s+old\s+2\s+new\s+0/)
    end

    it "runs Story 5's checks on the restored instance but not AC-5.7, which a primary-only backup can't satisfy (AC-6.2)" do
      engine = FakeEngine.new(databases: leg_databases, tasks: listing)
      harness(engine:).call
      expect(engine.calls.count { it.first == :runner && it[1].last.include?("perform_later") }).to eq(1)
    end

    it "fails when the sessions a restore ends are still there (P4)", :aggregate_failures do
      kept = seeded("kept", all_migrations, extra: sessions)
      expect(harness(engine: FakeEngine.new(databases: leg_databases.take(2) + [ kept ], tasks: listing)).call).to eq(1)
      expect(out.string).to include("sessions", "after the restore")
    end

    it "fails when the restore loses a row (AC-6.2)", :aggregate_failures do
      thin = seeded("thin", all_migrations, lots: 1999, extra: ended)
      expect(harness(engine: FakeEngine.new(databases: leg_databases.take(2) + [ thin ], tasks: listing)).call).to eq(1)
      expect(out.string).to include("FAIL lots", "id = 2000")
    end

    it "fails naming the refusal when the code under test refuses a backup the previous release took (AC-6.3)", :aggregate_failures do
      refusal = FakeEngine::Result.new("", "This backup was made by a newer Collector.\n", 1)
      expect(harness(engine: FakeEngine.new(databases: leg_databases, tasks: listing, restore: refusal)).call).to eq(1)
      expect(out.string).to include("AC-6.3", "newer Collector")
    end

    it "fails when the backup directory doesn't hold exactly one file (AC-6.1)", :aggregate_failures do
      expect(harness(engine: FakeEngine.new(databases: leg_databases, tasks: listing, list_directory: [])).call).to eq(1)
      expect(out.string).to include("exactly one file")
    end

    it "fails, and does not skip the leg, when the previous release lists the task but the backup it takes fails (AC-6.4)", :aggregate_failures do
      broken = FakeEngine::Result.new("", "disk full\n", 1)
      expect(harness(engine: FakeEngine.new(databases: leg_databases, tasks: listing, task: broken)).call).to eq(1)
      expect(out.string).to include("backup:create failed on v0.2.1", "disk full")
      expect(out.string).not_to include("backup leg skipped")
    end

    it "skips the leg with a printed line, and the exit status doesn't change, when the previous release has no backup task (AC-6.4)", :aggregate_failures do
      expect(harness.call).to eq(0)
      expect(out.string).to include("previous release v0.2.1 has no backup task; backup leg skipped")
      expect(engine.names).not_to include(:restore, :task)
    end
  end

  describe "the hand modes (decision 2, AC-6.5)" do
    it "treats an image of a commit as no release: reads the tree from the ref, runs next.rb, retires listed changes, says so", :aggregate_failures do
      options.previous_ref = "v0.2.1"
      File.write(File.join(root, "script/upgrade/expected_changes.yml"),
        "changes:\n  - table: lots\n    kind: rows_removed\n    migration: \"20261001000001\"\n    reason: \"Spec 99\"\n")
      expect(harness(previous: "ghcr.io/plainprogrammer/collector:edge").call).to eq(0)
      expect(out.string).to include("this run is not a release proof", "retired: lots rows_removed (migration 20261001000001 is in v0.2.1)")
      expect(engine.names).not_to include(:pull)
    end

    it "reads the release from the image's version label (decision 2)", :aggregate_failures do
      expect(harness(previous: "ghcr.io/plainprogrammer/collector:0.2.1").call).to eq(0)
      expect(out.string).to include("previous: v0.2.1")
    end

    it "asks for --previous-version when the label is not a stable version, and lets the flag win and say so", :aggregate_failures do
      info = { "RepoDigests" => [ "x@sha256:1" ], "Config" => { "Labels" => { "org.opencontainers.image.version" => "edge" } } }
      expect(harness(previous: "x:edge", engine: FakeEngine.new(image_info: info)).call).to eq(1)
      expect(out.string).to include("--previous-version X.Y.Z")
      out.truncate(0)
      out.rewind
      options.previous_version = "0.2.1"
      expect(harness(previous: "x:edge", engine: FakeEngine.new(databases:, image_info: info)).call).to eq(0)
      expect(out.string).to include("the image's label says \"edge\" and --previous-version says 0.2.1; using 0.2.1")
    end
  end

  describe ".parse" do
    it "reads the images and options (decision 2)", :aggregate_failures do
      previous, current, parsed = described_class.parse(%w[img:old img:new --previous-version 0.2.1 --timeout 90 --platform linux/arm64], env: { "SMOKE_BOOT_ATTEMPTS" => "7" })
      expect([ previous, current ]).to eq(%w[img:old img:new])
      expect(parsed.to_h).to include(previous_version: "0.2.1", timeout: 90, platform: "linux/arm64", boot_attempts: 7)
    end

    it "refuses a missing image" do
      expect { described_class.parse(%w[auto]) }.to raise_error(ArgumentError, /usage/)
    end
  end

  describe ".failed_migration" do
    it "names the last migration a log began" do
      log = "== 20261001000001 A: migrating ==\n== 20261002000001 CreateB: migrating ==\nboom\n"
      expect(described_class.failed_migration(log)).to eq("20261002000001 CreateB")
    end
  end
end
