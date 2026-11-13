require "rails_helper"
require Rails.root.join("script/upgrade/release").to_s

RSpec.describe "restoring a backup from an older release (AC-3.6)", :backup, :committed, type: :model do
  before { seed_instance }

  let(:volume) { scratch("volume") }

  # The schema version the backup is rolled back to: the newest migration of the previous release that this checkout has,
  # so that every migration written since is rolled back, however many there are and whichever of them change the schema
  # (#179; a count of steps went vacuous when the newest migration was a data step with nothing to undo). When no
  # migration is newer than that, as right after a release is cut, the newest one is rolled back, as the example did
  # before. It reads the previous release from the repository's tags (full history in CI, as the git sandbox's specs need),
  # so it needs a git checkout, and a clone with a remote but no tags raises Release::TagsNotFetched with the fix.
  let(:rollback_target) do
    ordered = release_versions.sort_by(&:to_i)
    release = Upgrade::Release.new(Rails.root.to_s)
    previous = release.previous
    shipped = previous && release.migration_versions(previous.tag).max_by(&:to_i)
    target = shipped && ordered.reverse.find { it.to_i <= shipped.to_i } # one this checkout has, even on a branch cut before the release
    target && target != ordered.last ? target : ordered[-2]
  end

  it "restores it as it is, and the first start migrates it with every row kept", :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- one scenario: restore, first start, then what it changed and left alone
    schema_before = Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest
    prices_structure_before = Digest::SHA256.file(Rails.root.join("db/prices_structure.sql")).hexdigest
    older = unpack_snapshot(create_backup, "older.sqlite3")
    _output, error, status = app_command(older, "db:migrate:primary", "VERSION=#{rollback_target}")
    expect(status).to be_success, "every migration since the previous release must be reversible (.claude/rules/sqlite-and-migrations.md): #{error}"
    older_versions = Collector::Backup::Snapshot.new(older).schema_versions
    expect(older_versions).to match_array(release_versions.select { it.to_i <= rollback_target.to_i })

    restore_backup(archive_of(older, schema_version: older_versions.max_by(&:to_i)), volume:)
    restored = volume.join("production.sqlite3")
    expect(Collector::Backup::Snapshot.new(restored).schema_versions).to match_array(older_versions) # the restore ran no migration

    _output, error, status = app_command(restored, "db:prepare")
    expect(status).to be_success, error
    snapshot = Collector::Backup::Snapshot.new(restored)
    expect(snapshot.schema_versions).to match_array(release_versions)
    expect(snapshot.counts).to eq("accounts" => 1, "users" => 1, "lots" => 3) # nothing was lost, and schema:load would have emptied it
    expect(Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest).to eq(schema_before)
    expect(Digest::SHA256.file(Rails.root.join("db/prices_structure.sql")).hexdigest).to eq(prices_structure_before)
    expect(volume.join("production_prices.sqlite3")).to exist # a version 1 restore's first start creates the prices database (AC-5.2)
  end
end
