require "rails_helper"

RSpec.describe Collector::Backup::Restore, :backup, :committed do
  let(:volume) { scratch("volume") }
  let!(:seed) { seed_instance }

  # A refusal that changes nothing in the volume and reads as two plain sentences (AC-3.8): each starts with a capital, a path
  # or the file's name (collector-backup-….tar.gz, note.txt) and ends with a full stop.
  def expect_refused(path, problem, advice = nil)
    before = checksums(volume)
    refusal = refusal_of { restore_backup(path, volume:) }

    expect(refusal&.problem).to eq(problem)
    expect(refusal.advice).to eq(advice) if advice
    [ refusal.problem, refusal.advice ].each do |sentence|
      expect(sentence).to match(/\A(?:[A-Z]|\/|collector-backup-|[\w.-]+\.(?:gz|txt|json) ).*\.\z/)
      expect(sentence).not_to match(/Exception|Error|Collector::|SQLite3|\.rb\b/)
    end
    expect(checksums(volume)).to eq(before)
    expect(volume.children.map { it.basename.to_s }).to match_array(before.keys)
    refusal
  end

  describe "a fresh volume (AC-2.1, AC-2.11)" do
    it "places the snapshot with the sessions ended and every other row as it was", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: seed, restore, then every table and the report compared
      seed_session(seed.user, seed.lots.first)
      path = create_backup
      result = restore_backup(path, volume:)
      primary = volume.join("production.sqlite3")
      cleared = %w[sessions bulk_removals bulk_selections bulk_selection_marks]
      live = table_rows(instance_database)
      restored = table_rows(primary)

      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
      expect(File.binread(primary, 2, 18).bytes).to eq([ 1, 1 ])
      expect(restored.keys).to eq(live.keys)
      (live.keys - cleared).each { |table| expect(restored.fetch(table)).to eq(live.fetch(table)), table }
      cleared.each { |table| expect(restored.fetch(table)).to be_empty, table }
      expect(live.fetch("sessions")).not_to be_empty # the source had them
      expect { Collector::Backup::Snapshot.new(primary).verify! }.not_to raise_error
      expect(result.report.lines(chomp: true)).to include("Restored #{path.basename} into #{volume}.")
      expect(result.report).to include("it holds 1 account, 1 user and 3 lots.", "Everyone signs in again",
        "pending bulk-removal Undos and selections are gone", "Start Collector now", "Build art index")
    end

    it "restores an instance with no users and says who becomes its admin (AC-2.11)" do
      clear_instance!
      result = restore_backup(create_backup, volume:)

      expect(result.report).to include("The backup holds no users: the first person to reach the restored instance becomes its admin.")
    end

    it "restores from a file that lives in the volume, and leaves it as it was", :aggregate_failures do
      path = create_backup
      inside = volume.join(path.basename).tap { FileUtils.cp(path, it) }
      before = Digest::SHA256.file(inside).hexdigest

      restore_backup(inside, volume:)

      expect(volume.children.map { it.basename.to_s }).to contain_exactly(inside.basename.to_s, "production.sqlite3")
      expect(Digest::SHA256.file(inside).hexdigest).to eq(before)
    end

    it "reads no secret: one backup restored under two secrets holds the same rows (AC-2.7)" do
      path = create_backup
      first = scratch("first")
      second = scratch("second")
      with_env("SECRET_KEY_BASE" => "one" * 20) { restore_backup(path, volume: first) }
      with_env("SECRET_KEY_BASE" => "two" * 20) { restore_backup(path, volume: second) }

      expect(table_rows(first.join("production.sqlite3"))).to eq(table_rows(second.join("production.sqlite3")))
    end
  end

  describe "a volume that isn't fresh (AC-2.5)" do
    {
      "a primary database" => "production.sqlite3",
      "only a -wal file of a database that is gone" => "production.sqlite3-wal",
      "only a queue database" => "production_queue.sqlite3"
    }.each do |label, name|
      it "refuses a volume that holds #{label} and changes nothing", :aggregate_failures do
        volume.join(name).write("whatever was there")
        volume.join("catalog.txt").write("another file")
        path = create_backup

        expect_refused(path, "The volume at #{volume} isn't empty: it holds #{name}.",
          "Restore onto a new, empty volume and start Collector on that. Nothing was changed.")
      end
    end

    it "refuses a primary that appears while the restore runs, and removes its temporary file (never overwrites)", :aggregate_failures do
      path = create_backup
      appear = ->(step) { volume.join("production.sqlite3").write("appeared") if step == :snapshot_ready }

      refusal = refusal_of { restore_backup(path, volume:, checkpoint: appear) }

      expect(refusal.problem).to eq("The volume at #{volume} isn't empty: it holds production.sqlite3.")
      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
      expect(volume.join("production.sqlite3").read).to eq("appeared")
    end
  end

  describe "a restore that is refused or stopped (AC-2.6)" do
    it "never creates the primary's path for a file that doesn't exist" do
      missing = scratch_path("nope.tar.gz")

      expect_refused(missing, "There is no file at #{missing}.", "Check the path as the container sees it; copy the backup in first.")
    end

    it "leaves no primary database when it is killed with the snapshot written, and the next restore succeeds and cleans up", :aggregate_failures do
      path = create_backup
      run_killed_at(:snapshot_ready, <<~RUBY, path, volume, release_versions.to_json)
        files = { "primary" => "production.sqlite3", "cache" => "production_cache.sqlite3", "queue" => "production_queue.sqlite3", "cable" => "production_cable.sqlite3" }
        databases = Collector::Backup::Databases.new(files.transform_values { |name| Pathname(ARGV[1]).join(name) })
        Collector::Backup::Restore.new(file: ARGV[0], databases: databases, release_versions: JSON.parse(ARGV[2]), checkpoint: STOP_HERE).call
      RUBY
      expect(volume.children.map { it.basename.to_s }).to eq([ "collector-restore.partial" ])
      volume.join("collector-restore.partial-journal").write("a stopped run's journal")

      restore_backup(path, volume:)

      expect(volume.children.map { it.basename.to_s }).to eq([ "production.sqlite3" ])
    end

    it "refuses a storage directory that isn't there", :aggregate_failures do
      gone = scratch_path("gone")

      refusal = refusal_of { restore_backup(create_backup, volume: gone) }

      expect(refusal.problem).to eq("The storage directory #{gone} doesn't exist.")
      expect(gone).not_to exist
    end

    it "refuses when the volume has too little room, before it writes anything", :aggregate_failures do
      path = create_backup
      refusal = refusal_of { restore_backup(path, volume:, free_space: ->(_path) { 1 }) }

      expect(refusal.problem).to match(/\AThe volume at #{Regexp.escape(volume.to_s)} has 1 byte free; the snapshot needs .*\.\z/)
      expect(volume.children).to be_empty
    end

    it "checks the room before the checksum, as FR-2 lists them (maintainer's ruling m3)", :aggregate_failures do
      original = unpack_snapshot(create_backup)
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(original.binread.tap { |bytes| bytes.setbyte(bytes.bytesize - 1, bytes.getbyte(bytes.bytesize - 1) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { Collector::Backup::Archive.write(it, manifest: manifest_for(original), snapshot: changed) }

      expect(refusal_of { restore_backup(altered, volume:, free_space: ->(_path) { 1 }) }.problem).to start_with("The volume at #{volume} has 1 byte free")
      expect_refused(altered, "#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")
    end

    it "refuses a file the user can't read and a volume it can't write, naming the fix and changing nothing (plan-review M3)", :aggregate_failures do
      skip "root reads and writes anything" if Process.uid.zero?
      path = create_backup
      path.chmod(0o000)

      expect_refused(path, "#{path} can't be read by the user Collector runs as (uid #{Process.uid}).",
        "Give it to that user (chown 1000:1000), as the README's restore steps do, then run this again. Nothing was changed.")

      path.chmod(0o600)
      volume.chmod(0o500)

      expect_refused(path, "The volume at #{volume} isn't writable by the user Collector runs as (uid #{Process.uid}).",
        "Give the volume to that user (chown 1000:1000), then run this again. Nothing was changed.")
    end
  end

  describe "a wrong or damaged file (AC-3.1 to AC-3.7)" do
    let(:path) { create_backup }

    it "refuses a file cut short, and a .partial file, as incomplete (AC-3.1)", :aggregate_failures do
      cut = scratch("cut").join(path.basename).tap { it.binwrite(path.binread[0...-100]) }
      partial = scratch("partial").join("#{path.basename}.0123456789abcdef.partial").tap { FileUtils.cp(path, it) }

      [ cut, partial ].each do |file|
        expect_refused(file, "#{file.basename} is incomplete; it was cut short or is still being written.", "Take the backup again, or copy it again.")
      end
    end

    it "refuses a changed snapshot on its checksum (AC-3.2)" do
      original = unpack_snapshot(path)
      manifest = manifest_for(original)
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(original.binread.tap { |bytes| bytes.setbyte(bytes.bytesize - 1, bytes.getbyte(bytes.bytesize - 1) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { Collector::Backup::Archive.write(it, manifest:, snapshot: changed) }

      expect_refused(altered, "#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")
    end

    it "refuses what isn't a backup, and a Collector export, saying so (AC-3.3)", :aggregate_failures do
      text = scratch_path("note.txt").tap { it.write("hello") }
      export = scratch_path("collector-export-2026-10-21.json").tap { it.write(CollectionExport.new(account: seed.user.account, at: Time.utc(2026, 10, 21)).to_json) }

      expect_refused(text, "#{text.basename} isn't a Collector backup.", "Give a collector-backup-….tar.gz file made by backup:create.")
      expect(expect_refused(export, "#{export.basename} is a Collector export file, not a backup.").advice).to include("Import collection")
    end

    it "refuses an unknown backup format version, naming the ones it restores (AC-3.4)" do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")

      expect_refused(future, "v2.tar.gz uses backup format version 2; this release restores version 1.", "Restore it with a release that knows that version.")
    end

    it "refuses a newer release's backup, naming both schema versions (AC-3.5)" do
      newer = copy_of_instance("newer.sqlite3").tap { |copy| sqlite(copy) { |database| database.execute("INSERT INTO schema_migrations (version) VALUES ('29991231235959')") } }
      archive = archive_of(newer)

      expect_refused(archive, "#{archive.basename} was taken by a newer release of Collector (schema version 29991231235959; this release has #{release_versions.max_by(&:to_i)}).",
        "Restore it onto that release or a newer one.")
    end

    it "refuses a snapshot with an unreadable page, and one with an orphan row, as damaged (AC-3.7)", :aggregate_failures do
      damaged = copy_of_instance("damaged.sqlite3").tap { damage_table!(it, "lots") }
      orphaned = copy_of_instance("orphaned.sqlite3")
      sqlite(orphaned) do |database|
        database.execute("PRAGMA foreign_keys = OFF")
        database.execute("INSERT INTO lots (account_id, catalog_entry_id, quantity, lot_key, created_at, updated_at) VALUES (999, 999, 1, 'k', '2026-10-21 14:21:00', '2026-10-21 14:21:00')")
      end
      zero = { "accounts" => 0, "users" => 0, "lots" => 0 }

      [ archive_of(damaged, into: scratch("a"), counts: zero), archive_of(orphaned, into: scratch("b")) ].each do |archive|
        expect_refused(archive, "The database inside #{archive.basename} is damaged.", "Use another copy of the backup.")
      end
    end

    it "refuses a snapshot whose counts differ from its manifest's" do
      archive = archive_of(copy_of_instance("counts.sqlite3"), counts: { "accounts" => 5, "users" => 5, "lots" => 5 })

      expect_refused(archive, "The restored database doesn't match the backup's counts.", "Use another copy of the backup.")
    end
  end
end
