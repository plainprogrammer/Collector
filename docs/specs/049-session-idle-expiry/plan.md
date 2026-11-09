# Plan 049: Sessions Expire After 30 Days Unused, and Stop Storing the Address and User Agent

**Spec:** [spec.md](spec.md) v1.0.0 (approved at Gate A, 2026-11-09). **Branch:** `228-session-idle-expiry`. **Issue:** #228.
**Status:** Draft, for Fable review and Gate B.

## Goal

A session whose stamp is 30 days old is no session; a request records use at most once a day; a nightly job deletes expired sessions; `sessions.ip_address` and `user_agent` are gone. Five tasks, four commits of code and one of documents, each test-first, in three phases.

## Gates

- **Simplicity:** one new model method set (`Session`), one job (`Session::SweepJob`), three migrations, edits to one concern (`Authentication`). No new service, no wrapper, no gem.
- **Anti-abstraction:** the expiry rule is two methods on `Session` (`expired?`, the `expired` scope) used by the request path and the sweep alike (FR-2); nothing else is introduced.
- **Integration-first:** the contract between phases is `Session`'s five names, defined in Task 2 and used in Tasks 3 and 4:

```ruby
Session::IDLE_LIMIT        # 30.days, the spec's idle limit
Session::STAMP_INTERVAL    # 1.day
Session::SWEEP_BATCH       # 1_000
Session.expired(now = Time.current)          # scope: last_used_at <= now - IDLE_LIMIT
Session#expired?(now = Time.current)         # last_used_at <= now - IDLE_LIMIT
Session#stale?(now = Time.current)           # last_used_at <= now - STAMP_INTERVAL || last_used_at > now
Session.sweep!(now: Time.current, batch: SWEEP_BATCH)  # deletes expired rows in batches, returns the count
```

The cookie's lifetime is `Session::IDLE_LIMIT` (decision 7), so it has no constant of its own.

## Decisions the plan makes (not in the spec)

- **Three migrations** (the rule separates schema from backfill; versions are after the newest, `20261106200001`): `20261109100001_add_last_used_at_to_sessions` (adds the stamp, nullable), `20261109100002_backfill_sessions_last_used_at` (data), `20261109100003_drop_session_client_columns` (drops `ip_address` and `user_agent`, makes the stamp `NOT NULL`). All three set `disable_ddl_transaction!`, as `AddCurrencyToAccounts` and `AddLocationToLots` do and for the reason their comments give: SQLite copies `sessions` to drop a column or add a constraint, and with foreign keys enforced inside a transaction the copy's `DROP TABLE` would run the `ON DELETE CASCADE` of `bulk_selections` and `bulk_removals` (spec Open Questions; the spec's M2). Each step is guarded (`column_exists?`), so a run that stopped between steps is finished by the next.
- **The stamp is `sessions.last_used_at`, `NOT NULL`, with no database default** (SQLite can't add a `NOT NULL` column without a constant default; the third migration adds the constraint after the backfill). New rows get it from the model: `attribute :last_used_at, default: -> { Time.current }`, so every `user.sessions.create!` in the suite and the sign-in path stamp the creation time (AC-2.1) with no change. The one raw `INSERT INTO sessions` in the suite (`spec/lib/collector/backup/snapshot_spec.rb:103`) names the column.
- **A stamp update is `session.update!(last_used_at: now)`,** which also moves `updated_at` (Rails' bookkeeping; the spec only requires the migration not to rewrite it, AC-4.3 and the proof's differences).
- **The sweep is `Session.sweep!`,** a class method that loops `pluck(ids) → where(id: ids).delete_all`; each `delete_all` is one statement and so its own write transaction (AC-3.3); the cascade is the database's (`delete_all` runs no callbacks, as `User#end_sessions!` does). `Session::SweepJob` calls it.
- **No ADR:** nothing here is a lasting decision beyond the spec's.
- **Counting writes** (AC-1.5, AC-2.2, AC-2.7, AC-3.3): one helper in `spec/support/query_counting.rb`, `write_statements_to(table) { … }`, that subscribes to `sql.active_record` and returns the `INSERT`/`UPDATE`/`DELETE` statements naming the table (the shape of spec 032 AC-11.12's `statements_during`, which is local to one spec file). It is included in request, job and model specs.

## Phase 1: The stamp, the dropped columns and the sessions' API (Tasks 1 and 2)

**Implements:** FR-5, FR-6, FR-7, FR-2 (the shared rule). **Satisfies:** AC-4.1–AC-4.4, AC-4.6, AC-4.7 (by the suites), AC-2.1, AC-2.8 (the predicate), AC-1.1 and AC-1.2 (the predicate). **Files:** `db/migrate/20261109100001…`, `…100002…`, `…100003…`, `db/schema.rb`, `app/models/session.rb`, `app/controllers/concerns/authentication.rb`, `spec/migrations/drop_session_client_columns_spec.rb`, `spec/models/session_spec.rb`, `spec/support/query_counting.rb`, `spec/support/backup_helpers.rb`, `spec/lib/collector/backup/snapshot_spec.rb`, `script/upgrade/seeds/next.rb`, `script/upgrade/expected_changes.yml`, `spec/script/upgrade/expected_changes_spec.rb`.

### Task 1: Migrations, schema, and the callers of the two columns

**Test first.** Create `spec/migrations/drop_session_client_columns_spec.rb` (it fails: the migration files don't exist, so the `require` raises `LoadError`). It follows `spec/migrations/add_currency_to_accounts_spec.rb`: `:backup, :committed, type: :model`, the Migrator for down and up, an `around` that brings the migrations back up.

```ruby
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
```

Run `bin/rspec spec/migrations/drop_session_client_columns_spec.rb`: **expected failure, `LoadError` for the first migration.**

**Code.** The three migrations:

```ruby
# db/migrate/20261109100001_add_last_used_at_to_sessions.rb
# The time a session was last used, recorded at most once a day (spec 049 decision 2). Nullable here: SQLite can't add a
# NOT NULL column with no default, and the backfill that follows sets every existing row; the third migration makes it NOT NULL.
# Without a transaction: removing a column copies the table, and with foreign keys enforced the copy's DROP TABLE would run
# the ON DELETE CASCADE of bulk_selections and bulk_removals (see AddCurrencyToAccounts, AddLocationToLots).
class AddLastUsedAtToSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :sessions, :last_used_at, :datetime unless column_exists?(:sessions, :last_used_at)
  end

  def down
    remove_column :sessions, :last_used_at if column_exists?(:sessions, :last_used_at)
  end
end
```

```ruby
# db/migrate/20261109100002_backfill_sessions_last_used_at.rb
# Every session that exists now has been used as of this upgrade, so none expires at once (spec 049 decision 11): the only
# older record is the creation time, which says nothing about use. Idempotent (a row already stamped is left), in batches of
# 1,000, and plain SQL (no application model, .claude/rules/sqlite-and-migrations.md). Nothing to undo going down.
class BackfillSessionsLastUsedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  BATCH = 1_000

  def up
    now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    loop do
      ids = select_values("SELECT id FROM sessions WHERE last_used_at IS NULL ORDER BY id LIMIT #{BATCH}") # Safe: a constant
      break if ids.empty?

      execute "UPDATE sessions SET last_used_at = #{now} WHERE id IN (#{ids.join(", ")})" # Safe: integer ids from the query above
    end
  end

  def down; end
end
```

```ruby
# db/migrate/20261109100003_drop_session_client_columns.rb
# A session no longer keeps the client's address and user agent, which nothing read (spec 049 decision 5; #218 2), and its
# stamp becomes NOT NULL. Without a transaction, as AddLastUsedAtToSessions explains. The UPDATE first is a safety net, not
# the backfill (that is the migration before this): it stamps a row a database that skipped the backfill still holds, so the
# NOT NULL can't fail. Going down puts the two columns back empty (the values are not kept) and lets the stamp be NULL again.
class DropSessionClientColumns < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "UPDATE sessions SET last_used_at = #{connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))} WHERE last_used_at IS NULL"
    remove_columns :sessions, *%i[ip_address user_agent].select { column_exists?(:sessions, it) } # one table copy for both
    change_column_null :sessions, :last_used_at, false if columns(:sessions).find { it.name == "last_used_at" }&.null
  end

  def down
    add_column :sessions, :ip_address, :string unless column_exists?(:sessions, :ip_address)
    add_column :sessions, :user_agent, :string unless column_exists?(:sessions, :user_agent)
    change_column_null :sessions, :last_used_at, true unless columns(:sessions).find { it.name == "last_used_at" }&.null
  end
end
```

`Session` gets the default so every `create!` stamps (Task 2 adds the rest of its API):

```ruby
  attribute :last_used_at, default: -> { Time.current }
```

`Authentication#start_new_session_for` stops passing the two attributes:

```ruby
    def start_new_session_for(user)
      user.sessions.create!.tap do |new_session|
        Current.session = new_session
        cookies.signed.permanent[:session_id] = { value: new_session.id, httponly: true, same_site: :lax, secure: request.ssl? }
      end
    end
```

(The cookie stays permanent until Task 3.) Other callers: `spec/support/backup_helpers.rb:90` becomes `user.sessions.create!`; `spec/lib/collector/backup/snapshot_spec.rb:103` becomes `INSERT INTO sessions (user_id, last_used_at, created_at, updated_at) VALUES (?, ?, ?, ?)` with `[ user_id, now, now, now ]`; `script/upgrade/seeds/next.rb:31` becomes `[ ada, grace ].each { |user| user.sessions.create! }`; `seeds/0.2.1.rb` is **not** touched (it runs in the previous release's image). `script/upgrade/expected_changes.yml` becomes:

```yaml
changes:
  - table: sessions
    column: ip_address
    kind: dropped
    migration: "20261109100003"
    reason: "Spec 049 decision 5: a session no longer stores the client's address"
  - table: sessions
    column: user_agent
    kind: dropped
    migration: "20261109100003"
    reason: "Spec 049 decision 5: a session no longer stores the client's user agent"
```

`spec/script/upgrade/expected_changes_spec.rb:73-76` ("ships empty and valid") expects the shipped file to have no live entry and no error, so it fails as soon as the two entries exist. Replace that example (plan review B1; the shipped spec 031's "ships as `changes: []`" stays as written, and `docs/releasing.md` step 7 retires the entries at the next tag):

```ruby
  it "ships valid, every entry naming a migration of the working tree" do
    versions = Rails.root.glob("db/migrate/*.rb").map { it.basename.to_s[/\A\d+/] }
    real = described_class.load(Rails.root.join("script/upgrade/expected_changes.yml"), previous_versions: [], current_versions: versions)
    expect([ real.errors, real.retired ]).to all(be_empty)
    expect(real.live.map { [ it.table, it.column, it.kind ] }).to eq([ [ "sessions", "ip_address", "dropped" ], [ "sessions", "user_agent", "dropped" ] ])
  end
```

(The implementer matches the loader's real keyword names in `script/upgrade/rules.rb`.) The proof compares only the columns both databases have (`script/upgrade/compare.rb:105`), so the added `last_used_at`, its backfill and its NOT NULL are not reported and need no `rewritten` entry; the two `dropped` entries are all the proof needs (AC-4.5).

Run `bin/rails db:migrate`; restore the cable, cache and queue schema files it rewrites (memory `migrate-schema-noise.md`); commit `db/schema.rb` with `sessions` as `t.datetime "last_used_at", null: false`, no `ip_address` and no `user_agent`, version `2026_11_09_100003`.

**Verify:** `bin/rspec spec/migrations spec/backup_guards_spec.rb spec/lib/collector/backup spec/script/upgrade spec/requests/sessions_spec.rb spec/requests/registrations_spec.rb spec/models/user` all pass; `bin/rspec spec/export_format*` (whichever files hold the Coverage guard: `git grep -l "Left out" spec`) pass with no change to the format (AC-4.6). `bin/rails db:migrate:redo` runs clean on the development database (reversibility, with the spec).

**Commit:** `feat(sessions): stamp each session's last use and stop storing the address and user agent (#228)`.

### Task 2: `Session`'s expiry rule

**Test first.** `spec/models/session_spec.rb` (new, `type: :model`):

```ruby
require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) { create(:user) }
  let(:now) { Time.utc(2026, 11, 9, 12, 0, 0) }

  def session_stamped(ago) = user.sessions.create!(last_used_at: now - ago)

  describe "#expired? and .expired (spec 049 decisions 1 and 2)" do
    it "is expired at 30 days or more and not before, by the stamp", :aggregate_failures do
      fresh = session_stamped(30.days - 1.second)
      edge = session_stamped(30.days)
      old = session_stamped(31.days)

      expect([ fresh, edge, old ].map { it.expired?(now) }).to eq([ false, true, true ])
      expect(described_class.expired(now)).to contain_exactly(edge, old)
    end
  end

  describe "#stale?" do
    it "is stale at 24 hours or more, and when the stamp is in the future (the clock was set back)", :aggregate_failures do
      expect(session_stamped(23.hours).stale?(now)).to be(false)
      expect(session_stamped(24.hours).stale?(now)).to be(true)
      expect(session_stamped(-1.hour).stale?(now)).to be(true)
    end
  end

  it "stamps a new session with its creation time (AC-2.1)" do
    travel_to(now) { expect(user.sessions.create!.last_used_at).to eq(now) }
  end

  it "keeps no address and no user agent (AC-4.1)" do
    expect(described_class.column_names).not_to include("ip_address", "user_agent")
  end
end
```

Run: **expected failure, `NoMethodError` (`expired?`, `expired`).**

**Code**, in `app/models/session.rb` (the existing comment and associations stay):

```ruby
class Session < ApplicationRecord
  # A session unused for this long is no session (spec 049 decisions 1 and 4); the cookie's lifetime is the same (decision 7).
  IDLE_LIMIT = 30.days
  # Use is recorded at most this often, so ordinary requests don't write (decision 2).
  STAMP_INTERVAL = 1.day
  # Expired sessions are deleted this many to a statement (decision 10).
  SWEEP_BATCH = 1_000

  belongs_to :user
  # (the existing comment about ON DELETE CASCADE stays here)
  has_one :bulk_selection
  has_many :bulk_removals

  attribute :last_used_at, default: -> { Time.current }

  scope :expired, ->(now = Time.current) { where(last_used_at: ..(now - IDLE_LIMIT)) }

  def expired?(now = Time.current) = last_used_at <= now - IDLE_LIMIT

  # Due for a new stamp: a day old, or later than now (the host's clock was set back, AC-2.8).
  def stale?(now = Time.current) = last_used_at <= now - STAMP_INTERVAL || last_used_at > now
end
```

**Verify:** `bin/rspec spec/models/session_spec.rb` passes, then `bin/rspec spec/models spec/requests/sessions_spec.rb` (the default no longer ties to columns).

**Commit:** `feat(sessions): a session expires when its stamp is 30 days old (#228)`.

## Phase 2: The request path (Task 3)

**Implements:** FR-1, FR-3; decisions 6, 7, 9. **Satisfies:** AC-1.1–AC-1.7, AC-2.1–AC-2.8. **Files:** `app/controllers/concerns/authentication.rb`, `spec/requests/session_expiry_spec.rb`, `spec/support/query_counting.rb`.

### Task 3: An expired session is no session; use is recorded once a day

**Test first.** Add the helper to `spec/support/query_counting.rb` and include it for jobs and models too:

```ruby
module QueryCounting
  # The write statements (INSERT, UPDATE, DELETE) a block runs against one table, for "this request wrote nothing to it".
  def write_statements_to(table)
    statements = []
    counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b.*"#{table}"/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    statements
  end
end

RSpec.configure do |config|
  config.include QueryCounting, type: :request
  config.include QueryCounting, type: :job
  config.include QueryCounting, type: :model
end
```

(replacing the one `config.include … type: :request` line.) Then `spec/requests/session_expiry_spec.rb` (`type: :request`; `TimeHelpers` are already included):

```ruby
require "rails_helper"

RSpec.describe "Session idle expiry (spec 049)", type: :request do
  let(:user) { create(:user) }
  let(:signed_in_session) { user.sessions.last } # not `session`: an integration test has one of its own

  before { sign_in_as(user) }

  def stamp!(ago) = signed_in_session.update!(last_used_at: Time.current - ago) # sets the stamp without a request

  # Set-Cookie is an Array when a response sets two cookies (Rack 3), so find the session cookie's own line.
  def session_cookie = Array(response.headers["Set-Cookie"]).find { it.start_with?("session_id=") }

  def cookie_expiry = Time.httpdate(session_cookie[/expires=([^;]+)/i, 1])

  describe "expiry (Story 1)" do
    it "signs in a session 29 days and 23 hours old (AC-1.1)" do
      stamp!(29.days + 23.hours)
      get collection_path
      expect(response).to have_http_status(:ok)
    end

    it "sends a GET with a session 30 days and a second old to sign-in, keeping the page to return to (AC-1.2)", :aggregate_failures do
      stamp!(30.days + 1.second)
      get collection_path(q: "bolt")
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      expect(response).to redirect_to(collection_path(q: "bolt"))
    end

    it "redirects a post with an expired session to sign-in and changes nothing (AC-1.3)", :aggregate_failures do
      lot = create(:lot, account: user.account, quantity: 2)
      stamp!(31.days)
      patch lot_path(lot), params: { lot: { quantity: 9 } }
      expect(response).to redirect_to(new_session_path)
      expect(lot.reload.quantity).to eq(2)
    end

    it "shows an open catalog page to an expired session as to a visitor (AC-1.4)", :public_catalog, :aggregate_failures do
      stamp!(31.days)
      get catalog_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "writes nothing to sessions and removes the cookie (AC-1.5)", :aggregate_failures do
      stamp!(31.days)
      writes = write_statements_to("sessions") { get collection_path }
      expect(writes).to be_empty
      expect(Session.exists?(signed_in_session.id)).to be(true)
      expect(session_cookie).to start_with("session_id=;")
    end

    it "makes a new session on the next sign-in, not reusing the expired one (AC-1.6)", :aggregate_failures do
      expired = signed_in_session
      stamp!(31.days)
      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      expect(user.sessions.where.not(id: expired.id).count).to eq(1)
      expect(expired.reload.expired?).to be(true)
    end

    it "keeps a session in regular use signed in for 100 days, with no absolute lifetime (AC-1.7)" do
      10.times do
        travel(10.days)
        get collection_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "recording use (Story 2)" do
    it "writes nothing to sessions for a stamp under 24 hours old (AC-2.2)", :aggregate_failures do
      stamp!(23.hours)
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(session_cookie).to be_nil
    end

    it "stamps a session 24 hours old or more and sets the cookie again for 30 days (AC-2.3)", :aggregate_failures do
      stamp!(24.hours)
      get collection_path
      expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
      expect(cookie_expiry).to be_within(1.minute).of(30.days.from_now)
    end

    it "counts a page, a form post and an open catalog visit as use (AC-2.4)", :public_catalog, :aggregate_failures do
      lot = create(:lot, account: user.account)
      [ -> { get collection_path }, -> { patch lot_path(lot), params: { lot: { quantity: 3 } } }, -> { get catalog_entries_path } ].each do |call|
        stamp!(2.days)
        call.call
        expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
      end
    end

    it "records nothing for no cookie, a bad cookie or a cookie that names a gone row (AC-2.5)", :aggregate_failures do
      gone = signed_in_session.id
      Session.where(id: gone).delete_all # the cookie stays and now names no row
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(response).to redirect_to(new_session_path)

      cookies[:session_id] = "not-a-signed-value"
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(response).to redirect_to(new_session_path)

      cookies.delete(:session_id)
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(Session.count).to eq(0)
    end

    it "sets a signed, HTTP-only, same-site-lax cookie that expires in 30 days and is not permanent (AC-2.6)", :aggregate_failures do
      delete session_path # the group's sign-in left a session; a signed-in user is redirected away from sign-in
      https!
      sign_in_as(user)
      expect(session_cookie).to match(/httponly/i).and match(/samesite=lax/i).and match(/secure/i)
      expect(cookie_expiry).to be_within(1.minute).of(30.days.from_now)
    end

    it "writes to sessions at most once for requests within a day (AC-2.7)", :aggregate_failures do
      stamp!(2.days)
      first = write_statements_to("sessions") { get collection_path }
      second = write_statements_to("sessions") { get collection_path }
      expect(first.size).to eq(1)
      expect(second).to be_empty
    end

    it "rewrites a stamp later than now (the clock was set back) and signs in (AC-2.8)", :aggregate_failures do
      stamp!(-3.days)
      get collection_path
      expect(response).to have_http_status(:ok)
      expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
    end
  end
end
```

(The `patch lot_path` params follow the existing lots request specs; the implementer matches them to `LotsController#update`'s real parameters and to the account's `Lot` factory, and uses the same example's real route if `lot_path` differs. An example that stays red for a reason of its own wiring, not for the missing behaviour, is a defect of the example.) Run `bin/rspec spec/requests/session_expiry_spec.rb`: **expected failures:** AC-1.2/1.3/1.4/1.5/1.6/1.7 (an expired session is still signed in; the cookie is 20 years), AC-2.3, AC-2.6, AC-2.8; the "writes nothing" examples may pass already and are kept as regression guards.

**Code.** `app/controllers/concerns/authentication.rb`:

```ruby
    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.includes(user: :account).find_by(id: cookies.signed[:session_id])
      if session&.expired?
        # An expired session is no session (spec 049 decision 9). A read doesn't write: the row stays for the nightly sweep.
        cookies.delete(:session_id)
        nil
      else
        record_use_of(session) if session
        session
      end
    end

    # At most one write a day per session (decision 2); the cookie's new date goes out in the same response (decision 7).
    def record_use_of(session)
      return unless session.stale?

      session.update!(last_used_at: Time.current)
      set_session_cookie(session)
    end

    def set_session_cookie(session)
      cookies.signed[:session_id] = { value: session.id, expires: Session::IDLE_LIMIT.from_now, httponly: true, same_site: :lax, secure: request.ssl? }
    end

    def start_new_session_for(user)
      user.sessions.create!.tap do |new_session|
        Current.session = new_session
        set_session_cookie(new_session)
      end
    end
```

`resume_session`, `request_authentication` and `terminate_session` are unchanged (a sign-out by a session whose stamp is a day old first stamps it and sets the cookie, then destroys the row and deletes the cookie; Rack keeps only the deletion, so the output is today's and the extra write is the spec's use): an expired session returns nil there, so the redirect, the kept page and the 303 on sign-out are today's.

**Verify:** `bin/rspec spec/requests/session_expiry_spec.rb spec/requests` (every request spec signs in and out through these paths), then `bin/rspec spec/system/scanner_adding_spec.rb spec/system/scanner_spec.rb` if the Firefox driver runs here (they delete the cookie by name), else left to CI.

**Commit:** `feat(sessions): an expired session is no session, and use is recorded once a day (#228)`.

## Phase 3: The sweep (Task 4)

**Implements:** FR-4; decisions 3, 8, 10. **Satisfies:** AC-3.1–AC-3.8, AC-1.8. **Files:** `app/models/session.rb`, `app/jobs/session/sweep_job.rb`, `config/recurring.yml`, `spec/models/session_spec.rb`, `spec/jobs/session/sweep_job_spec.rb`, `spec/config/recurring_spec.rb`.

### Task 4: `Session.sweep!`, the job, and the schedule

**Test first.** Add to `spec/models/session_spec.rb`:

```ruby
  describe ".sweep! (spec 049 Story 3)" do
    def fill(session)
      selection = BulkSelection.for(session)
      selection.marks.create!(account: user.account, lot: create(:lot, account: user.account))
      BulkRemoval.create!(session:, account: user.account, copies: 1)
    end

    it "deletes expired sessions with their selection, marks and Undo, and nothing else (AC-3.1, AC-3.4, AC-1.8)", :aggregate_failures do
      other = create(:user)
      gone = session_stamped(31.days).tap { fill(it) }
      kept = session_stamped(1.day).tap { fill(it) }
      theirs = other.sessions.create!(last_used_at: now)
      before = [ User.count, Account.count, Lot.count ]

      expect(described_class.sweep!(now:)).to eq(1)

      expect(described_class.all).to contain_exactly(kept, theirs)
      expect(BulkSelection.pluck(:session_id)).to eq([ kept.id ])
      expect(BulkRemoval.pluck(:session_id)).to eq([ kept.id ])
      expect(BulkSelection::Mark.count).to eq(1)
      expect([ User.count, Account.count, Lot.count ]).to eq(before)
      expect(gone).not_to be_persisted.or(satisfy { described_class.exists?(gone.id) == false })
    end

    it "changes nothing when none is expired, and the second run deletes nothing (AC-3.2)", :aggregate_failures do
      session_stamped(31.days)
      expect(described_class.sweep!(now:)).to eq(1)
      expect(described_class.sweep!(now:)).to eq(0)
      user.sessions.create!(last_used_at: now)
      expect(described_class.sweep!(now:)).to eq(0)
    end

    it "deletes every expired session across batches, one delete statement each (AC-3.3)", :aggregate_failures do
      5.times { session_stamped(40.days) }
      statements = write_statements_to("sessions") { expect(described_class.sweep!(now:, batch: 2)).to eq(5) }
      expect(statements.size).to eq(3)
      expect(described_class.count).to eq(0)
    end
  end
```

(The mark model is `BulkSelection::Mark`. The first example's last assertion is `expect(described_class.exists?(gone.id)).to be(false)`, replacing the `satisfy` line.) Then `spec/jobs/session/sweep_job_spec.rb` (`type: :job`):

```ruby
require "rails_helper"

RSpec.describe Session::SweepJob, type: :job do
  let(:user) { create(:user) }

  it "runs on the default queue and deletes the expired sessions of every account (AC-3.8)", :aggregate_failures do
    expect(described_class.new.queue_name).to eq("default")
    old = user.sessions.create!(last_used_at: 31.days.ago)
    recent = create(:user).sessions.create!

    described_class.perform_now

    expect(Session.all).to contain_exactly(recent)
    expect(Session.exists?(old.id)).to be(false)
  end

  it "declares one run at a time (AC-3.7)", :aggregate_failures do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_key).to eq("session_sweep")
  end

  it "queues a second sweep behind the first through Solid Queue (AC-3.7)", :solid_queue, :aggregate_failures do
    first = queue_job(described_class)
    second = queue_job(described_class)

    expect(first.ready_execution).to be_present
    expect(second.blocked_execution).to be_present
  end

  it "retries a busy database later and fails on an error that is not transient (AC-3.5)", :aggregate_failures do
    allow(Session).to receive(:sweep!).and_raise(SQLite3::BusyException)
    expect { described_class.perform_now }.to have_enqueued_job(described_class)

    allow(Session).to receive(:sweep!).and_raise(ArgumentError)
    expect { described_class.perform_now }.to raise_error(ArgumentError)
  end
end
```

(Whether `concurrency_limit`/`concurrency_key` and `ready_execution` read as written depends on Solid Queue's API in the bundled version; the implementer reads `ActiveJob::ConcurrencyControls` in the gem and `spec/models/catalog/operation/queue_spec.rb:18` for the readers that exist and uses those, keeping the assertion's meaning.) And in `spec/config/recurring_spec.rb`:

```ruby
  %w[development production].each do |environment|
    it "schedules the session sweep daily at night in #{environment} (spec 049 AC-3.6)", :aggregate_failures do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig(environment, "sweep_sessions")

      expect(task).to include("class" => "Session::SweepJob", "queue" => "default")
      expect(Fugit.parse_cronish(task["schedule"]).to_cron_s).to eq("10 4 * * *")
    end
  end
```

Run: **expected failures:** `NoMethodError: sweep!`, `NameError: Session::SweepJob`, a nil task.

**Code.** In `Session`:

```ruby
  # Deletes the expired sessions a batch at a time, each batch its own statement and so its own short write transaction
  # (spec 049 decision 10), and returns how many it deleted. Cross-tenant by nature: the instance runs it over every account's
  # sessions (.claude/rules/multi-tenancy.md). delete_all runs no callbacks on purpose: the database removes each session's
  # bulk selection and Undo (ON DELETE CASCADE), as it does for User#end_sessions! (spec 006 FR-4, FR-6).
  def self.sweep!(now: Time.current, batch: SWEEP_BATCH)
    deleted = 0
    while (ids = expired(now).limit(batch).pluck(:id)).any?
      deleted += where(id: ids).delete_all
    end
    deleted
  end
```

```ruby
# app/jobs/session/sweep_job.rb
# Deletes expired sessions every night (spec 049 decision 8). Idempotent: a second run right after the first deletes nothing.
# One at a time, as the sweep is cross-tenant and SQLite has one writer; a busy database is retried with a backoff. A run that
# is missed is harmless: the request path already refuses an expired session, and the next run deletes what is left.
class Session::SweepJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: "session_sweep", duration: 15.minutes
  retry_on SQLite3::BusyException, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3

  def perform = Session.sweep!
end
```

`config/recurring.yml` gains, under both `development` and `production`:

```yaml
  sweep_sessions:
    class: Session::SweepJob
    queue: default
    schedule: at 4:10am every day
```

**Verify:** `bin/rspec spec/models/session_spec.rb spec/jobs spec/config spec/backup_guards_spec.rb`; `bin/rails zeitwerk:check`.

**Commit:** `feat(sessions): a nightly job deletes expired sessions (#228)`.

## Phase 4: Documents and the proof (Task 5, run by the supervisor)

**Implements:** Story 5. **Satisfies:** AC-5.1–AC-5.3, AC-4.5, AC-4.7. **Files:** `docs/architecture/tenancy-and-accounts.md`, `docs/specs/README.md`, `docs/specs/049-session-idle-expiry/{spec.md,verification.md}`, `docs/architecture/release-and-deploy.md` only if it names the sessions' columns (read first), `README.md`, `docs/backup-restore.md` (read for a statement that a session lasts until ended; the two read clean in the spec's review).

### Task 5: The tenancy area doc, the index, the verification

Edit `tenancy-and-accounts.md` as AC-5.1 lists, with spec 049 as each statement's source: the Glossary's *Session* (stamp, expiry); the Invariants' bullet on jobs ("The jobs the app runs are global: … and `Session::SweepJob`, which deletes every account's expired sessions") and the cross-account reads bullet (`Session.sweep!`); "A session" (Created: the row has no address or user agent, the cookie expires in 30 days; Resumed: an expired session is no session, the cookie removed, nothing written; a use is any request resolving the session, recorded at most daily with the cookie renewed; Ended: add idle expiry and the sweep, drop "Nothing else ends one: sessions have no expiry"); the Named constants table (`Session::IDLE_LIMIT`, `STAMP_INTERVAL`, `SWEEP_BATCH`, the cookie's lifetime, the schedule); the Decisions list: remove only the clauses for rulings 1 and 2 from the "Six behaviours have no spec source" bullet and set its count to what remains, as the coordinator's rule for the lines shared by #228–#231 says (and the same for the "open:" line under Sources, line 169), and remove the two "Accepted limits" entries about sessions. In `docs/specs/README.md` row 049: status "Approved" and plan "present"; at distillation the row changes per spec 027. Record in `verification.md` the criteria verified by reading (AC-5.1–AC-5.3) and the evidence for the rest.

**Verify (with a CI slot):** `bin/ci` whole, with the example count and the run's SHA recorded in `verification.md`. `bin/upgrade-smoke` needs a container engine and is not a `bin/ci` step: AC-4.5's proof is the `spec/script/upgrade` examples plus CI's image job, and AC-4.7's is the harness's backup leg (`script/upgrade/harness.rb`, which restores the previous release's backup and migrates it with `RESTORE_ENDS_SESSIONS`), also CI's image job. `verification.md` says so, and that the backfilled stamp is not reported by the proof (it compares common columns only), so no `rewritten` entry exists.

**Commit:** `docs(tenancy): sessions idle expiry and the dropped columns (#228)`.

## Coverage

| Spec | Task |
|---|---|
| FR-1, FR-3; AC-1.1–AC-1.7; AC-2.1–AC-2.8 | 2, 3 (AC-2.1 and AC-4.1 also 1) |
| FR-2 | 2 (`expired?`/`expired`), 3 and 4 use them |
| FR-4; AC-1.8, AC-3.1–AC-3.8 | 4 |
| FR-5, FR-6, FR-7; AC-4.1–AC-4.4, AC-4.6, AC-4.7 | 1 |
| AC-4.5 | 1 (the files), 5 (evidence) |
| AC-5.1–AC-5.3 | 5 |

## Execution

Implementer batches (Sonnet, test-first, each task its own commit, diff checked by the supervisor after each batch): batch A is Tasks 1 and 2; batch B is Tasks 3 and 4. Task 5 is the supervisor's, with the implementation review (Mode B, Opus) recorded in `verification.md` under `## Implementation review`. One spec run at a time in the worktree.
