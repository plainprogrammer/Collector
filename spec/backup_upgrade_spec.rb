require "rails_helper"

RSpec.describe "restoring a backup from an older release (AC-3.6)", :backup, :committed, type: :model do
  before { seed_instance }

  let(:volume) { scratch("volume") }

  it "restores it as it is, and the first start migrates it with every row kept", :aggregate_failures do
    schema_before = Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest
    older = unpack_snapshot(create_backup, "older.sqlite3")
    _output, error, status = app_command(older, "db:rollback", "STEP=1")
    expect(status).to be_success, "the newest migration must be reversible (.claude/rules/sqlite-and-migrations.md): #{error}"
    older_versions = Collector::Backup::Snapshot.new(older).schema_versions
    expect(older_versions.size).to eq(release_versions.size - 1)

    restore_backup(archive_of(older, schema_version: older_versions.max_by(&:to_i)), volume:)
    restored = volume.join("production.sqlite3")
    expect(Collector::Backup::Snapshot.new(restored).schema_versions).to match_array(older_versions) # the restore ran no migration

    _output, error, status = app_command(restored, "db:prepare")
    expect(status).to be_success, error
    snapshot = Collector::Backup::Snapshot.new(restored)
    expect(snapshot.schema_versions).to match_array(release_versions)
    expect(snapshot.counts).to eq("accounts" => 1, "users" => 1, "lots" => 3) # nothing was lost, and schema:load would have emptied it
    expect(Digest::SHA256.file(Rails.root.join("db/schema.rb")).hexdigest).to eq(schema_before)
  end
end
