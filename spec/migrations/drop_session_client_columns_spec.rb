require "rails_helper"
%w[20261109100001_add_last_used_at_to_sessions 20261109100002_backfill_sessions_last_used_at
   20261109100003_drop_session_client_columns].each { |name| require Rails.root.join("db/migrate/#{name}") }

# Spec 049 Story 4 (AC-4.2, AC-4.3, AC-4.4): dropping the two columns rebuilds sessions on SQLite, and the rebuild must not run
# the ON DELETE CASCADE of the bulk selection and the Undo that belong to a session (which would delete collector state on an
# upgrade). The migrations run outside a transaction (disable_ddl_transaction!), so the examples commit their rows (:committed),
# and go down and up through the Migrator, as db:rollback does (see add_location_to_lots_spec.rb).
RSpec.describe DropSessionClientColumns, :backup, :committed, type: :model do
  let(:user) { create(:user) }
  let(:lot) { create(:lot, account: user.account) }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up_all unless Session.connection.column_exists?(:sessions, :last_used_at) && !Session.connection.column_exists?(:sessions, :ip_address)
    Session.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def versions = [ 2026_11_09_100001, 2026_11_09_100002, 2026_11_09_100003 ]

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down_all = versions.reverse_each { |version| context.run(:down, version) }

  def up_all = versions.each { |version| context.run(:up, version) }

  def columns(table) = Session.connection.columns(table).map { |column| [ column.name, column.sql_type, column.null ] }

  def count(table) = Session.connection.select_value("SELECT COUNT(*) FROM #{table}") # Safe: a literal table name from this spec

  # Rows as the previous release holds them: an address, a user agent, a pending selection with a mark, and an undoable removal.
  def fill_previous_schema!
    Session.connection.execute("INSERT INTO sessions (user_id, ip_address, user_agent, created_at, updated_at) VALUES (#{user.id}, '203.0.113.9', 'RSpec', '2025-11-01 10:00:00', '2025-11-01 10:00:00')") # Safe: an integer id from a factory
    session = Session.connection.select_value("SELECT id FROM sessions")
    selection = BulkSelection.create!(session_id: session, account: user.account)
    selection.marks.create!(account: user.account, lot:)
    BulkRemoval.create!(session_id: session, account: user.account, copies: 1)
    session
  end

  it "turns each migration's transaction off, so the rebuild runs with foreign keys off", :aggregate_failures do
    [ AddLastUsedAtToSessions, BackfillSessionsLastUsedAt, described_class ].each do |migration|
      expect(migration.disable_ddl_transaction).to be(true)
    end
  end

  it "ends with no address and no user agent, and a NOT NULL stamp (AC-4.1)", :aggregate_failures do
    expect(columns(:sessions).map(&:first)).not_to include("ip_address", "user_agent") # the connection's columns, not the model's cached ones
    expect(columns(:sessions)).to include([ "last_used_at", "datetime(6)", false ])
  end

  it "keeps every session, its bulk selection, its mark and its Undo going down and up (AC-4.2)", :aggregate_failures do
    down_all
    session = fill_previous_schema!
    before = [ count(:sessions), count(:bulk_selections), count(:bulk_selection_marks), count(:bulk_removals) ]

    up_all

    expect([ count(:sessions), count(:bulk_selections), count(:bulk_selection_marks), count(:bulk_removals) ]).to eq(before)
    expect(Session.connection.select_value("SELECT id FROM sessions")).to eq(session)
    expect(Session.connection.select_value("SELECT user_id FROM sessions")).to eq(user.id)
    expect(columns(:sessions).map(&:first)).not_to include("ip_address", "user_agent")
  end

  it "gives every existing session the migration's time as its stamp, not its creation time (AC-4.3)", :aggregate_failures do
    down_all
    fill_previous_schema!
    updated = Session.connection.select_value("SELECT updated_at FROM sessions")

    travel_to(Time.utc(2026, 11, 9, 12, 0, 0)) { up_all }

    expect(Session.connection.select_value("SELECT last_used_at FROM sessions")).to match(/\A2026-11-09 12:00:00/)
    expect(Session.connection.select_value("SELECT updated_at FROM sessions")).to eq(updated) # updated_at is not rewritten
    expect(Session.expired(Time.utc(2026, 11, 9, 13, 0, 0))).to be_empty # a sweep right after the upgrade deletes none, though the session is a year old
  end

  it "runs the backfill twice with the same result, and leaves a stamp already set (idempotent)", :aggregate_failures do
    session = user.sessions.create!(last_used_at: Time.utc(2026, 11, 1))

    BackfillSessionsLastUsedAt.new.migrate(:up)

    expect(session.reload.last_used_at).to eq(Time.utc(2026, 11, 1))
  end

  it "restores the two columns empty and removes the stamp going down, and the same table comes back up (AC-4.4)", :aggregate_failures do
    user.sessions.create!
    after_up = columns(:sessions)

    down_all
    expect(Session.connection.column_exists?(:sessions, :last_used_at)).to be(false)
    expect(columns(:sessions).map(&:first)).to include("ip_address", "user_agent")
    expect(Session.connection.select_values("SELECT ip_address FROM sessions")).to all(be_nil)
    expect(count(:sessions)).to eq(1)

    up_all
    expect(columns(:sessions)).to eq(after_up)
    expect(count(:sessions)).to eq(1)
  end
end
