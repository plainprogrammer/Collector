# Implementation Plan: Apply an Import

**Spec:** docs/specs/028-apply-import/spec.md (v1.3.1, Approved)
**Decisions:** docs/adr/0022-stored-import-upload-retention.md (drafted with this plan); ADR 0013, 0016, 0017, 0020, 0021 apply
**Created:** 2026-10-20
**Supporting:** [data-model.md](data-model.md), [contracts/api.md](contracts/api.md)

## Global Constraints

Copied from the spec; each applies to every phase.

- Replace semantics of spec 025 decision 1; a file with problem rows, a refused file, or one with nothing to change is never stored and never applied (decisions 1, 4, 12).
- The order of an apply's checks is decision 13's: no upload or expired (422) → stored file unreadable (422) → refused or problem rows (422) → nothing to change (422) → fingerprints not all equal (409) → removal unconfirmed (422).
- Applying is one all-or-nothing write transaction; parse and resolve before it; its bar is **under 4 s for 50,000 rows**; the whole request under 30 s and 500 MB RSS growth (decision 3, AC-1.10).
- The stored upload: one per account, `application/json` by content, at most `CollectionImport::MAX_BYTES` (32 MB), `ImportUpload::EXPIRES_IN` = 1 hour; created analyzed; every removal purges synchronously, outside the write transaction; the sweep (every 15 minutes, `default`, development and production) only calls `purge`, never walks `storage/`; orphan = marked blob, no attachment, older than 10 minutes (decisions 8, 9).
- Active Storage routes stay drawn but gated: sign-in plus ownership (decision 8).
- Everything goes through `Current.account`; no parameter names an account, upload or lot; the only parameters are `fingerprint` and `confirm_removal` (FR-5).
- Files of the apply, the stored upload, the controller and views contain neither `MTG` nor `Scryfall` (FR-8). The file's content is never logged; responses are `no-store` (FR-6).
- Format version 1 and its schema and examples are unchanged; only the Coverage table gains a line (decision 9).
- No migration edits to released migrations; migrations use no application models (`.claude/rules/sqlite-and-migrations.md`).
- UI uses only design-system tokens and `c-*` classes (AC-7.4).
- TDD is the hard gate: every implementation step has a failing test before it. Prose documents are checked by reading, never by RSpec (`.claude/rules/testing.md`).

---

## Goal

A signed-in collector who previewed an applicable export file applies it with one click and their collection then holds exactly the file's lots, all or nothing, from a briefly stored, private upload, with the export → import round trip tested.

---

## Scope Check and Gates

One subsystem (data portability), with the stored upload as its release-and-deploy edge. No split.

- **Simplicity (≤3 components):** (1) `ImportUpload` (+ sweep), (2) `CollectionImport` plan/fingerprint + `CollectionImport::Apply`, (3) `Collections::ImportsController` with the preview's changes. The gate concern (Active Storage) is the fourth piece, forced by decision 8; justified in Phase 3's Complexity note.
- **Anti-abstraction:** Active Storage, `Lot.upsert_all`, Solid Queue recurring tasks and `has_one_attached` are used directly. `CollectionImport::Plan` is a view of the existing `outcomes`, not a parallel model.
- **Integration-first:** `contracts/api.md` and `data-model.md` precede code; Phase 0 writes the failing contract-level request specs' helpers and the table.

## Seams for spec 029 (not planned here)

029 extends the apply with v2 locations after 028 merges. The seams: `CollectionImport::Plan` is the one place that lists what an apply writes (`added_rows`, `changed_rows`, `removed_lots`, `view_change`) and the fingerprint's inputs; `CollectionImport::Apply#write!` is the one place that writes them, in one method per kind; `lot_attributes(row, import)` is the one place that maps a row to a lot. 029 adds to those three and to `WorkingState` if it needs it. Nothing of locations is built here.

## File Structure

| File | Responsibility |
|---|---|
| `db/migrate/20261020100001_create_active_storage_tables.rb` | Framework install migration (decision 8) |
| `db/migrate/20261020100002_create_import_uploads.rb` | The upload table (FR-10) |
| `app/models/import_upload.rb` | Stored upload: store, replace, expiry, read, sweep |
| `app/jobs/import_upload/sweep_job.rb` | The recurring sweep |
| `config/recurring.yml` | Schedules the sweep in development and production |
| `app/controllers/concerns/active_storage_gate.rb` + `config/initializers/active_storage_gate.rb` | Sign-in and ownership for Active Storage's routes |
| `app/models/collection_import.rb` (edit) | Entry ids per row, `plan`, `replan`, exact times on `HeldLot` |
| `app/models/collection_import/plan.rb` | What applying does; the fingerprint |
| `app/models/collection_import/apply.rb` | The apply step: checks, transaction, writes, result |
| `app/models/collection_import/working_state.rb` | Clears the lists that point at lots (decision 7) |
| `app/controllers/collections/imports_controller.rb`, `config/routes.rb` | `POST /collection/import` |
| `app/controllers/collections/import_previews_controller.rb` (edit) | Stores the upload |
| `app/views/collections/import_previews/{show,_apply}.html.erb`, `app/views/collections/imports/failed.html.erb` | The pages |
| `app/models/account.rb` (edit) | Associations |
| `spec/support/import_helpers.rb` | Row/file builders shared by the specs |
| `docs/...` | See Phase 12 |

---

## Requirement Map

Every AC and FR → phase → the first failing test (named in the phase). `P#` = phase.

| Requirement | Phase | First failing test |
|---|---|---|
| FR-1 | 4, 5 | `plan_spec` "lists what applying does"; `apply_spec` "refuses in decision 13's order" |
| FR-2 | 5 | `apply_spec` "decides presence, expiry and fingerprint inside the transaction" |
| FR-3 | 5 | `apply_spec` "writes lots that pass Lot's validations (AC-2.4)" |
| FR-4 | 5 | `apply_spec` "reads and writes in a bounded number of statements" |
| FR-5 | 5, 7 | `apply_spec` AC-4.1; `collection_imports_spec` AC-4.2 |
| FR-6 | 7, 10 | `collection_imports_spec` "sends no-store"; filter-parameter example |
| FR-7 | 6 | `collection_import_previews_spec` AC-5.3 |
| FR-8 | 10 | `import_core_spec` |
| FR-9 | 5 | `apply_spec` AC-1.2 "keeps the changed lot's id" |
| FR-10 | 0 | `import_upload_spec` "allows one per account" |
| AC-1.1 | 6 | `collection_import_previews_spec` "offers the apply form only for an applicable file with something to change" |
| AC-1.2–1.4 | 5 (model), 7 (HTTP 303) | `apply_spec` "replaces exactly (AC-1.2)", "(AC-1.3)", "(AC-1.4)" |
| AC-1.5, 1.7 | 4, 5 | `apply_spec` "previews as nothing to change after an apply (AC-1.5)", "(AC-1.7)" |
| AC-1.6 | 5 | `apply_spec` "changes the view, never name or email" |
| AC-1.8 | 5 | `apply_spec` "clears working state only when it writes" |
| AC-1.9 | 5, 7 | `apply_spec` "removes the upload"; request "refuses a second post" |
| AC-1.10 | 11 | Measured, `verification.md` |
| AC-1.11 | 6 | `collection_import_previews_spec` "writes only the upload, its blob and attachment" |
| AC-1.12 | 3 | `active_storage_gate_spec` |
| AC-2.1 | 5, 7 | `apply_spec` "rolls everything back (AC-2.1)"; request 500 |
| AC-2.2 | 5 | `apply_spec` "refuses a second apply as nothing to change" |
| AC-2.3 | 5, 7 | `apply_spec` "answers a lost race with 422, not an error" |
| AC-2.4 | 5 | `apply_spec` "writes lots that pass Lot's validations" |
| AC-2.5 | 5 | `apply_spec` "treats an upload removed after reading as gone" |
| AC-3.1–3.5 | 5, 7 | `apply_spec` per criterion |
| AC-3.6 | 5 | `apply_spec` "gives decision 13's response for combined causes" |
| AC-3.7 | 4 | `plan_spec` "fingerprints" |
| AC-4.1, 4.2 | 5, 7 | `apply_spec`; `collection_imports_spec` |
| AC-4.3 | 7 | `collection_imports_spec` "sends a visitor to sign in" |
| AC-4.4 | 1 | `import_upload_spec` "goes with its account" |
| AC-5.1, 5.2 | 1 | `import_upload_spec` |
| AC-5.3 | 6 | `collection_import_previews_spec` |
| AC-5.4 | 1, 2 | `import_upload_spec` ".sweep!" |
| AC-5.5 | 2, 12 | `recurring_spec`; the export-format document spec |
| AC-5.6 | 5 | `apply_spec` "judges expiry inside the transaction" |
| AC-6.1–6.4 | 8 | `collection_import_round_trip_spec` |
| AC-6.5 | 11 | By hand, `verification.md` |
| AC-7.1 | 6 | `collection_import_previews_spec` |
| AC-7.2 | 9 | `collection_import_apply_spec` (system) |
| AC-7.3, 7.4 | 9 | Screenshots; reading |
| Documents that change | 12 | Reading |

---

## Phase 0: Helpers, tables and the model shell

**Implements:** FR-10, decision 8 (Installation) | **Satisfies:** (AC-4.4 and AC-5.x land in Phase 1)
**Files:** `spec/support/import_helpers.rb`, `spec/models/import_upload_spec.rb`, the two migrations, `app/models/import_upload.rb`, `app/models/account.rb`, `db/schema.rb`, `spec/export_format_document_spec.rb`, `docs/export-format/README.md`
**Interfaces:** Consumes: nothing. Produces: table `import_uploads`; `ImportUpload` (`belongs_to :account`, `has_one_attached :file`); `Account#import_upload`, `#bulk_selections`, `#bulk_removals`; the helpers `import_printing`, `import_row`, `import_file`, `import_io`.

- [ ] Write the shared helpers:

```ruby
# spec/support/import_helpers.rb
# Builders for export files in the specs of spec 025 and spec 028.
module ImportHelpers
  def import_printing(**entry) = create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, **entry)).entry

  def import_row(entry, quantity: 1, finish: nil, condition: nil, price_paid: nil, added_at: "2026-10-01T10:00:00Z", changed_at: added_at)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => finish, "condition" => condition, "price_paid" => price_paid,
      "added_at" => added_at, "changed_at" => changed_at }
  end

  def import_file(user, lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def import_io(data) = StringIO.new(data.is_a?(String) ? data : JSON.generate(data))

  def import_upload_file(data, type: "application/json", name: "export.json")
    Rack::Test::UploadedFile.new(import_io(data), type, original_filename: name)
  end

  # A held lot with the file's times, as the model specs of spec 025 make them.
  def held_lot(account, entry, quantity:, added_at: "2026-10-01T10:00:00Z", changed_at: added_at, **attributes)
    create(:lot, account:, entry:, quantity:, created_at: Time.iso8601(added_at), updated_at: Time.iso8601(changed_at), **attributes)
  end

  # Previews +data+ for +account+ and stores it, as the preview page does; returns the ImportUpload.
  def store_import!(account:, data:)
    bytes = data.is_a?(String) ? data : JSON.generate(data)
    import = CollectionImport.new(account:, file: StringIO.new(bytes))
    ImportUpload.store!(account:, bytes:, plan: import.plan)
  end
end

RSpec.configure do |config|
  %i[model request system].each { |type| config.include ImportHelpers, type: }
end
```

- [ ] Write the failing model spec for the table:

```ruby
# spec/models/import_upload_spec.rb
require "rails_helper"

RSpec.describe ImportUpload, type: :model do
  it "allows one per account (FR-10)", :aggregate_failures do
    account = create(:user).account
    described_class.create!(account:, fingerprint: "a", expires_at: 1.hour.from_now)

    expect { described_class.create!(account:, fingerprint: "b", expires_at: 1.hour.from_now) }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect(account.reload.import_upload.fingerprint).to eq("a")
  end
end
```

- [ ] Run `bin/rspec spec/models/import_upload_spec.rb` — expect FAIL (`uninitialized constant ImportUpload`).
- [ ] Add the migrations. The first is the framework's `ActiveStorage` 8.1.4 `create_active_storage_tables` (blobs, attachments, variant records) with `ActiveRecord::Migration[8.1]`; generate it with `bin/rails active_storage:install` and rename it `20261020100001_create_active_storage_tables.rb` (it references no application model; `primary_and_foreign_key_types` reads generator config only). The second:

```ruby
# db/migrate/20261020100002_create_import_uploads.rb
class CreateImportUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :import_uploads do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :fingerprint, null: false
      t.datetime :expires_at, null: false
      t.timestamps
      t.index :expires_at
    end
  end
end
```

- [ ] Add the model shell and associations:

```ruby
# app/models/import_upload.rb
# The account's previewed export file, kept briefly so that it can be applied (spec 028 decisions 1, 9).
class ImportUpload < ApplicationRecord
  EXPIRES_IN = 1.hour

  belongs_to :account
  has_one_attached :file, dependent: :purge # synchronous: spec 028 decision 9
end
```

```ruby
# app/models/account.rb: add
  has_one :import_upload, dependent: :destroy
  has_many :bulk_selections, dependent: nil # the foreign keys cascade; here for the apply to name them
  has_many :bulk_removals, dependent: nil
```

- [ ] Run `bin/rails db:migrate`, then restore the cache, queue and cable schema files if they changed (`git checkout db/cache_schema.rb db/queue_schema.rb db/cable_schema.rb`; memory: "Migrate schema noise") and check `git diff db/schema.rb` shows only the four new tables and the version. Run `bin/rails db:migrate:redo VERSION=20261020100002` and `bin/rails db:rollback STEP=2 && bin/rails db:migrate` — expect no error (reversible, unattended).
- [ ] Run `bin/rspec spec/models/import_upload_spec.rb` — expect PASS. Run `bin/rspec spec/export_format_document_spec.rb` — expect FAIL: the Coverage table lacks `import_uploads` (AC-5.5; the failure is the intended test).
- [ ] Add the Coverage line to `docs/export-format/README.md` (after `bulk_selections`, alphabetical among the left-out rows): `| \`import_uploads\` | Left out | Transient working state: the previewed file, kept for an hour so it can be applied. The file is the collector's own export, already restored into the lots by applying it. |` — and nothing else in that document. Add `import_uploads` to the list in `spec/export_format_document_spec.rb` ("marks each table as the spec rules", sorted: `bulk_removals bulk_selection_marks bulk_selections import_uploads number_entries ...`).
- [ ] Run `bin/rspec spec/export_format_document_spec.rb spec/models/import_upload_spec.rb` — expect PASS.
- [ ] Commit: `feat(028): install Active Storage and add the import uploads table`

---

## Phase 1: The stored upload

**Implements:** decisions 1, 8, 9 (store, replace, expiry, removal, sweep rule) | **Satisfies:** AC-4.4, AC-5.1, AC-5.2, AC-5.4
**Files:** `app/models/import_upload.rb`, `spec/models/import_upload_spec.rb`
**Interfaces:** Consumes: Phase 0. Phase 4 produces `CollectionImport#plan` and `Plan#fingerprint(checksum)`; this phase uses them through a stand-in plan in its specs and the real one from Phase 4 on. Produces: `ImportUpload.store!(account:, bytes:, plan:)` → `ImportUpload`; `#expired?`; `#checksum`; `#read` → String or nil; `ImportUpload.sweep!`; constants `EXPIRES_IN`, `ORPHAN_GRACE`, `MARKER`.

Phase 1 needs `CollectionImport#plan`, which Phase 4 builds. To keep each phase independently verifiable, `store!` takes the plan's fingerprint through `plan.fingerprint(checksum)`; the specs here pass `FakePlan = Data.define(:value) { def fingerprint(_checksum) = value }`. Phase 4 switches `store_import!` to the real plan.

- [ ] Write the failing specs:

```ruby
# spec/models/import_upload_spec.rb (added to the Phase 0 file)
  let(:account) { create(:user).account }
  let(:plan) { Data.define(:value) { def fingerprint(_checksum) = value }.new("fp-1") }

  def store(bytes = '{"a":1}', for_account: account) = described_class.store!(account: for_account, bytes:, plan:)

  describe ".store! (AC-5.1, AC-5.2)" do
    it "keeps the file as application/json, analyzed, expiring after EXPIRES_IN", :aggregate_failures do
      upload = store
      blob = upload.file.blob

      expect(blob.content_type).to eq("application/json")
      expect(blob).to be_analyzed
      expect(blob.metadata).to include("identified" => true, "import_upload" => true)
      expect(upload.fingerprint).to eq("fp-1")
      expect(upload.expires_at).to be_within(5.seconds).of(described_class::EXPIRES_IN.from_now)
      expect(upload.read).to eq('{"a":1}')
    end

    it "queues no job" do
      expect { store }.not_to have_enqueued_job
    end

    it "replaces the account's earlier upload and purges its file", :aggregate_failures do
      first = store("1")
      key = first.file.blob.key
      second = store("22")

      expect(account.reload.import_upload).to eq(second)
      expect(described_class.count).to eq(1)
      expect(ActiveStorage::Blob.exists?(key: key)).to be(false)
      expect(ActiveStorage::Blob.service.exist?(key)).to be(false)
    end
  end

  describe "#expired? and #read" do
    it "is expired at expires_at, and reads nil when the file is gone", :aggregate_failures do
      upload = store
      expect(upload).not_to be_expired
      travel_to(described_class::EXPIRES_IN.from_now + 1.second) { expect(upload).to be_expired }

      ActiveStorage::Blob.service.delete(upload.file.blob.key)
      expect(upload.read).to be_nil
    end
  end

  describe "going with its account (AC-4.4)" do
    it "purges the blob and its file when the user is deleted" do
      user = create(:user)
      upload = store(for_account: user.account)
      key = upload.file.blob.key

      user.destroy!

      expect([ described_class.count, ActiveStorage::Blob.service.exist?(key) ]).to eq([ 0, false ])
    end
  end

  describe ".sweep! (AC-5.4)" do
    def blob(created_at: Time.current, marked: true)
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("{}"), filename: "x.json", content_type: "application/json", identify: false,
        metadata: { "identified" => true, "analyzed" => true }.merge(marked ? { "import_upload" => true } : {})).tap { |b| b.update_columns(created_at:) }
    end

    it "purges expired uploads and old orphans only, and is idempotent", :aggregate_failures do
      expired = store(for_account: create(:user).account).tap { |u| u.update!(expires_at: 1.minute.ago) }
      fresh = store(for_account: create(:user).account)
      old_orphan = blob(created_at: 11.minutes.ago)
      new_orphan = blob(created_at: 1.minute.ago)
      unmarked = blob(created_at: 1.day.ago, marked: false)
      expired_key = expired.file.blob.key

      described_class.sweep!
      described_class.sweep!

      expect(described_class.all).to contain_exactly(fresh)
      expect(ActiveStorage::Blob.service.exist?(expired_key)).to be(false)
      expect(ActiveStorage::Blob.exists?(old_orphan.id)).to be(false)
      expect(ActiveStorage::Blob.where(id: [ new_orphan.id, unmarked.id, fresh.file.blob.id ]).count).to eq(3)
    end
  end
```

- [ ] Run `bin/rspec spec/models/import_upload_spec.rb` — expect FAIL (`undefined method store!`).
- [ ] Implement:

```ruby
# app/models/import_upload.rb
class ImportUpload < ApplicationRecord
  EXPIRES_IN = 1.hour
  ORPHAN_GRACE = 10.minutes
  MARKER = "import_upload".freeze

  belongs_to :account
  has_one_attached :file, dependent: :purge # synchronous, after the enclosing transaction commits (decision 9)

  scope :expired, -> { where(expires_at: ..Time.current) }

  # Keeps +bytes+, replacing the account's earlier upload (decision 1). The blob is made first, outside any transaction
  # (file I/O), already identified and analyzed so Active Storage queues no job (decision 8); a failure after it purges it.
  def self.store!(account:, bytes:, plan:)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "import-#{account.id}.json",
      content_type: "application/json", identify: false,
      metadata: { "identified" => true, "analyzed" => true, MARKER => true })
    transaction do
      account.import_upload&.destroy!
      create!(account:, fingerprint: plan.fingerprint(blob.checksum), expires_at: EXPIRES_IN.from_now, file: blob)
    end
  rescue StandardError
    blob&.purge
    raise
  end

  # Removes every expired upload, and every marked blob that no attachment holds and that is older than the grace
  # (a preview that crashed between its blob and its record). Cross-tenant by nature: it runs for the instance.
  # It only calls purge; it never lists or deletes paths on disk (decision 9).
  def self.sweep!
    expired.find_each(&:destroy!)
    ActiveStorage::Blob.where.missing(:attachments).where(created_at: ..ORPHAN_GRACE.ago)
      .where("json_extract(active_storage_blobs.metadata, '$.import_upload') = 1").find_each(&:purge)
  end

  def expired? = expires_at <= Time.current

  def checksum = file.blob.checksum

  # The stored file's bytes, or nil when it can't be read (removed by the sweep, a newer preview or a fault).
  def read
    file.download
  rescue ActiveStorage::FileNotFoundError
    nil
  end
end
```

- [ ] Run the spec — expect PASS. If `account.import_upload` is cached stale after `destroy!`, use `ImportUpload.find_by(account_id: account.id)&.destroy!` in `store!`.
- [ ] Run `bin/rubocop app/models/import_upload.rb spec/models/import_upload_spec.rb` — expect clean.
- [ ] Commit: `feat(028): store, expire and sweep a previewed upload`

---

## Phase 2: The recurring sweep

**Implements:** decision 9 (the sweep), FR-10 | **Satisfies:** AC-5.4 (job), AC-5.5 (schedule)
**Files:** `app/jobs/import_upload/sweep_job.rb`, `config/recurring.yml`, `spec/jobs/import_upload/sweep_job_spec.rb`, `spec/config/recurring_spec.rb`
**Interfaces:** Consumes: `ImportUpload.sweep!`. Produces: `ImportUpload::SweepJob` (no arguments, queue `default`).

- [ ] Write the failing specs:

```ruby
# spec/jobs/import_upload/sweep_job_spec.rb
require "rails_helper"

RSpec.describe ImportUpload::SweepJob, type: :job do
  it "sweeps on the default queue, taking no argument", :aggregate_failures do
    expect(described_class.new.queue_name).to eq("default")
    allow(ImportUpload).to receive(:sweep!)

    described_class.perform_now

    expect(ImportUpload).to have_received(:sweep!)
  end
end
```

```ruby
# spec/config/recurring_spec.rb
require "rails_helper"

# Spec 028 AC-5.5: the sweep is scheduled every 15 minutes where Solid Queue runs (production, and development inside Puma).
RSpec.describe "config/recurring.yml" do
  let(:config) { YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true) }

  %w[development production].each do |environment|
    it "schedules the import upload sweep every 15 minutes in #{environment}" do
      expect(config.dig(environment, "sweep_import_uploads"))
        .to include("class" => "ImportUpload::SweepJob", "queue" => "default", "schedule" => "every 15 minutes")
    end
  end

  it "keeps the production tasks it had" do
    expect(config["production"].keys).to include("clear_solid_queue_finished_jobs", "refresh_mtg_catalog")
  end
end
```

- [ ] Run `bin/rspec spec/jobs/import_upload spec/config/recurring_spec.rb` — expect FAIL.
- [ ] Implement:

```ruby
# app/jobs/import_upload/sweep_job.rb
# Removes expired stored uploads and orphaned upload blobs (spec 028 decision 9). Idempotent; queued every 15 minutes
# by config/recurring.yml.
class ImportUpload::SweepJob < ApplicationJob
  queue_as :default

  def perform = ImportUpload.sweep!
end
```

```yaml
# config/recurring.yml: add a development block before production, and the task to both
development:
  sweep_import_uploads:
    class: ImportUpload::SweepJob
    queue: default
    schedule: every 15 minutes

production:
  # ... the two existing tasks unchanged, then:
  sweep_import_uploads:
    class: ImportUpload::SweepJob
    queue: default
    schedule: every 15 minutes
```

- [ ] Run the specs — expect PASS. Run `bin/rails runner 'puts SolidQueue::Configuration.new.send(:recurring_tasks).map(&:key)'` in development — expect `sweep_import_uploads`.
- [ ] Commit: `feat(028): sweep expired import uploads every 15 minutes`

---

## Phase 3: Gate Active Storage's routes

**Implements:** decision 8 (routes gated, app-wide) | **Satisfies:** AC-1.12
**Files:** `app/controllers/concerns/active_storage_gate.rb`, `config/initializers/active_storage_gate.rb`, `spec/requests/active_storage_gate_spec.rb`
**Interfaces:** Consumes: `Authentication` (sign-in), `ImportUpload` (an owned blob to test with). Produces: `ActiveStorageGate`, included in `ActiveStorage::BaseController`: sign-in for all its actions, an ownership check for every action that reads a blob.

Complexity note (fourth component): the gate exists because Active Storage's routes are public and decision 8 rules them gated app-wide. It is the framework's documented "Authenticated Controllers" pattern, not a wrapper.

- [ ] Write the failing spec:

```ruby
# spec/requests/active_storage_gate_spec.rb
require "rails_helper"

# Spec 028 AC-1.12: Active Storage's routes need a sign-in and an owner.
RSpec.describe "Active Storage gate", type: :request do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:entry) { import_printing }
  let!(:upload) { store_import!(account: owner.account, data: import_file(owner, [ import_row(entry) ])) }
  let(:blob) { upload.file.blob }

  def blob_path = rails_blob_path(blob)

  it "sends a signed-out visitor to sign in and returns no content", :aggregate_failures do
    get blob_path

    expect(response).to redirect_to(new_session_path)
    expect(response.body).not_to include("collector-export")
  end

  it "returns 404 to another account's collector, for the blob and for the disk URL", :aggregate_failures do
    sign_in_as(other)
    get blob_path
    expect(response).to have_http_status(:not_found)

    disk_url = blob.url(expires_in: 5.minutes, disposition: "attachment")
    get disk_url
    expect(response).to have_http_status(:not_found)
  end

  it "serves the file to its owner, through the redirect to the disk service", :aggregate_failures do
    sign_in_as(owner)
    get blob_path
    expect(response).to have_http_status(:redirect)
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("collector-export")
  end

  it "returns 404 for a blob no record holds", :aggregate_failures do
    orphan = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    sign_in_as(owner)

    get rails_blob_path(orphan)

    expect(response).to have_http_status(:not_found)
  end

  it "needs a sign-in to create a direct upload" do
    post rails_direct_uploads_path, params: { blob: { filename: "a.png", byte_size: 1, checksum: "x", content_type: "image/png" } }, as: :json

    expect(response).to redirect_to(new_session_path)
  end

  it "never puts a blob URL, key or signed id in the pages", :aggregate_failures do
    sign_in_as(owner)
    post collection_import_preview_path, params: { export_file: import_upload_file(import_file(owner, [ import_row(import_printing) ])) }

    expect(response.body).not_to include("active_storage", blob.key, blob.signed_id)
  end
end
```

(the last example is exercised once Phase 6 renders the page; until then it passes trivially and stays as a guard.)

- [ ] Run `bin/rspec spec/requests/active_storage_gate_spec.rb` — expect FAIL (the signed-out and other-account examples get 302 to the blob / 200).
- [ ] Implement:

```ruby
# app/controllers/concerns/active_storage_gate.rb
# Active Storage's routes are public by default. They are gated app-wide (spec 028 decision 8, ADR 0022): every action
# needs a sign-in, and every action that reads a blob needs a blob that a record of the signed-in account holds.
# Direct-upload creation and the disk service's upload PUT have no blob to own yet and need the sign-in only.
module ActiveStorageGate
  extend ActiveSupport::Concern

  included do
    include Authentication
    before_action :require_blob_owner
  end

  private
    def require_blob_owner
      return if %w[create update].include?(action_name)

      blob = gated_blob
      head :not_found unless blob && Current.account && owned_by_account?(blob)
    end

    def gated_blob
      if params[:encoded_key]
        key = ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)&.with_indifferent_access&.dig(:key)
        ActiveStorage::Blob.find_by(key:) if key
      else
        ActiveStorage::Blob.find_signed(params[:signed_id] || params[:signed_blob_id])
      end
    end

    # A record that answers account_id and holds the blob. A record without one is served to no one.
    def owned_by_account?(blob)
      blob.attachments.includes(:record).any? { |attachment| attachment.record.respond_to?(:account_id) && attachment.record.account_id == Current.account.id }
    end
end
```

```ruby
# config/initializers/active_storage_gate.rb
Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include ActiveStorageGate
end
```

- [ ] Run the spec — expect PASS. If the redirect target host or `Authentication#helper_method` fails in the engine controller, keep `include Authentication` and add `helper_method`-free guard `Authentication` already declares; run `bin/rails zeitwerk:check`.
- [ ] Run `bin/brakeman -q` — expect no new warning (the `where("json_extract…")` string is a constant; the gate has no dynamic SQL).
- [ ] Commit: `feat(028): gate Active Storage's routes behind sign-in and ownership`

---

## Phase 4: The plan and its fingerprint

**Implements:** FR-1 (plan and fingerprint from the reader), decision 2, decision 12 (`nothing_to_change?`) | **Satisfies:** AC-3.7, AC-1.5 (preview side), AC-1.7 (preview side)
**Files:** `app/models/collection_import.rb`, `app/models/collection_import/plan.rb`, `spec/models/collection_import/plan_spec.rb`, `spec/support/import_helpers.rb`
**Interfaces:** Consumes: the existing `outcomes`. Produces: `CollectionImport#plan` (memoized), `#replan` (re-reads the account's lots and the user, no re-parse), `#entry_id(row)`, `CollectionImport::Plan` with `added_rows`, `changed_rows` (rows), `held_for(row)` (HeldLot), `removed_lots` (all, HeldLot), `view_change`, `nothing_to_change?`, `removes?`, `counts` → `{ added:, changed:, removed: }` lots, `fingerprint(file_checksum)` → hex String; `HeldLot#created_exact`, `#updated_exact` (ISO 8601, 6 fractional digits).

- [ ] Write the failing spec:

```ruby
# spec/models/collection_import/plan_spec.rb
require "rails_helper"

# Spec 028: what applying a file would do, and the fingerprint that ties an apply to its preview (decision 2).
RSpec.describe CollectionImport::Plan, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }

  def import(lots, **fields) = CollectionImport.new(account:, file: import_io(import_file(user, lots, **fields)))

  it "lists what applying does (FR-1)", :aggregate_failures do
    kept = held_lot(account, a, quantity: 3)
    edited = held_lot(account, b, quantity: 2)
    gone = held_lot(account, import_printing, quantity: 7)
    plan = import([ import_row(a, quantity: 3), import_row(b, quantity: 5, changed_at: "2026-10-02T10:00:00Z"), import_row(import_printing, quantity: 6) ]).plan

    expect(plan.added_rows.map(&:number)).to eq([ 3 ])
    expect(plan.changed_rows.map(&:number)).to eq([ 2 ])
    expect(plan.held_for(plan.changed_rows.first).id).to eq(edited.id)
    expect(plan.removed_lots.map(&:id)).to eq([ gone.id ])
    expect(plan.counts).to eq(added: 1, changed: 1, removed: 1)
    expect([ plan.nothing_to_change?, plan.removes? ]).to eq([ false, true ])
    expect(kept).to be_persisted
  end

  it "has nothing to change for a file the collection already holds (AC-1.5)", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    plan = import([ import_row(a, quantity: 3) ]).plan

    expect(plan.nothing_to_change?).to be(true)
    expect(import([], profile: { "name" => "x", "email_address" => "x@example.test", "collection_view" => "table" }).plan.nothing_to_change?).to be(false) # a view change alone is something
  end

  it "treats a lot with fractional times as unchanged against a row without them (AC-1.7)" do
    lot = held_lot(account, a, quantity: 3)
    lot.update_columns(created_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.25, updated_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.75)

    expect(import([ import_row(a, quantity: 3) ]).plan.nothing_to_change?).to be(true)
  end

  describe "#fingerprint (AC-3.7)" do
    def fingerprint(checksum = "sum") = import([ import_row(a, quantity: 5), import_row(b, quantity: 1) ]).plan.fingerprint(checksum)

    it "is equal for two previews of the same file and collection", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      expect(fingerprint).to eq(fingerprint)
      expect(lot).to be_persisted
    end

    it "differs for any change to a lot's quantity, either time or existence, to the file, or to the view", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      baseline = fingerprint

      lot.update_columns(quantity: 3)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(quantity: 2)
      expect(fingerprint).to eq(baseline)
      lot.update_columns(updated_at: lot.updated_at + 0.001)
      expect(fingerprint).not_to eq(baseline) # full precision, not truncated to the second
      lot.update_columns(updated_at: lot.updated_at - 0.001, created_at: lot.created_at + 1.hour)
      expect(fingerprint).not_to eq(baseline)
      lot.update_columns(created_at: lot.created_at - 1.hour)
      expect(fingerprint("other")).not_to eq(baseline) # the stored file
      extra = held_lot(account, import_printing, quantity: 1)
      expect(fingerprint).not_to eq(baseline) # a removed lot appears
      extra.destroy!
      lot.destroy!
      expect(fingerprint).not_to eq(baseline)
      user.update_columns(collection_view: "table")
      expect(import([ import_row(a, quantity: 5), import_row(b, quantity: 1) ], profile: { "name" => user.name, "email_address" => user.email_address, "collection_view" => "grid" }).plan.fingerprint("sum")).to be_a(String)
    end
  end

  it "re-reads the collection on replan without parsing again", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    parsed = import([ import_row(a, quantity: 3) ])
    expect(parsed.plan.nothing_to_change?).to be(true)

    account.lots.update_all(quantity: 4)

    expect(parsed.plan.nothing_to_change?).to be(true) # memoized, as the preview saw it
    expect(parsed.replan.changed_rows.size).to eq(1)
  end

  it "knows the catalog entry each row resolved to" do
    parsed = import([ import_row(a) ])

    expect(parsed.entry_id(parsed.rows.first)).to eq(a.id)
  end
end
```

- [ ] Run `bin/rspec spec/models/collection_import/plan_spec.rb` — expect FAIL (`undefined method plan`).
- [ ] Edit `CollectionImport`: add the exact times to `HeldLot`, remember the resolved entries, return the row lists from the outcomes, and add `plan`/`replan`:

```ruby
# app/models/collection_import.rb
  HeldLot = Data.define(:id, :identity, :quantity, :added_at, :changed_at, :name, :set_code, :collector_number, :language,
    :created_exact, :updated_exact) do
    # (described unchanged)
  end

  def initialize(account:, file:)
    @account = account
    @entry_ids = {}
    @refusal = read(file)
    @rows = refused? ? [] : read_rows
  end

  # The catalog entry a row that isn't a problem row resolved to (for applying, spec 028).
  def entry_id(row) = @entry_ids.fetch(row.number)

  # What applying would do to the collection as it was when this was first asked (the preview's view).
  def plan = @plan ||= Plan.new(outcomes, view_change)

  # The same, against the collection as it is now: one read of the lots and of the user, no parsing (spec 028 FR-2).
  def replan
    user.reload
    Plan.new(outcomes_for(held_lots), view_change)
  end
```

  In `entry_problems` (called with `index`) record the entry: in `resolution_problems`' inner loop add `@entry_ids[index + 1] = entries[lot["entry"]["source_id"]]&.id` before `entry_problems`. In `held_lots`, pluck the extra values and pass `created_exact: created.utc.iso8601(6), updated_exact: changed.utc.iso8601(6)`. Split `outcomes`:

```ruby
    def outcomes = @outcomes ||= outcomes_for(held_lots)

    def outcomes_for(held_list)
      held = held_list.index_by(&:identity)
      # ... the existing body unchanged, then in the returned hash add:
      #   added_rows: added, changed_rows: changed,
    end
```

- [ ] Add the plan:

```ruby
# app/models/collection_import/plan.rb
# What applying a file to the collection would do, and the fingerprint that ties an apply to the preview that showed it
# (spec 028 decision 2). The one place that lists what an apply writes.
class CollectionImport::Plan
  attr_reader :added_rows, :changed_rows, :removed_lots, :view_change

  def initialize(outcomes, view_change)
    @added_rows = outcomes.fetch(:added_rows)
    @changed_rows = outcomes.fetch(:changed_rows)
    @removed_lots = outcomes.fetch(:removed_lots)
    @matched = outcomes.fetch(:matched_lots)
    @view_change = view_change
  end

  def held_for(row) = @matched.fetch(row.identity)

  def nothing_to_change? = added_rows.empty? && changed_rows.empty? && removed_lots.empty? && view_change.nil?

  def removes? = removed_lots.any?

  def counts = { added: added_rows.size, changed: changed_rows.size, removed: removed_lots.size }

  # A digest of the stored file and of the plan: the added and changed rows and their outcome, every changed and removed
  # lot's id, quantity and times at full precision, and the view change.
  def fingerprint(file_checksum)
    parts = [ file_checksum,
      added_rows.map { |row| [ row.number, "added" ] },
      changed_rows.map { |row| lot_part(held_for(row)).unshift(row.number, "changed") },
      removed_lots.sort_by(&:id).map { |lot| lot_part(lot) },
      view_change ]
    Digest::SHA256.hexdigest(JSON.generate(parts))
  end

  private
    def lot_part(lot) = [ lot.id, lot.quantity, lot.created_exact, lot.updated_exact ]
end
```

- [ ] Run the new spec — expect PASS; run `bin/rspec spec/models/collection_import_spec.rb spec/requests/collection_import_previews_spec.rb spec/collection_import_core_spec.rb` — expect PASS (spec 025's behaviour is unchanged; `HeldLot.new` is built only in `held_lots`).
- [ ] Update `store_import!` in the helpers to pass `import.plan` (already so) and run `bin/rspec spec/models/import_upload_spec.rb` — still PASS (it uses a stand-in plan).
- [ ] Commit: `feat(028): the plan of an import and its fingerprint`

---

## Phase 5: The apply step

**Implements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-9, decisions 2–5, 7, 12, 13 | **Satisfies:** AC-1.2 to AC-1.9, AC-2.1 to AC-2.5, AC-3.1 to AC-3.6, AC-4.1, AC-5.6
**Files:** `app/models/collection_import/apply.rb`, `app/models/collection_import/working_state.rb`, `spec/models/collection_import/apply_spec.rb`
**Interfaces:** Consumes: `CollectionImport#applicable?`, `#plan`, `#replan`, `#entry_id`, `Plan`, `ImportUpload#read/#checksum/#expired?/#destroy!`, `Lot.key_for`. Produces: `CollectionImport::Apply.new(account:, fingerprint:, confirmed:).call` → `Result` (`Data.define(:outcome, :import, :plan, :upload, :fingerprint)`) with `outcome` one of `:applied, :missing, :expired, :unreadable, :refused, :nothing_to_change, :stale, :unconfirmed`; `CollectionImport::WorkingState.clear!(account)`.

- [ ] Write the failing spec (the whole apply behaviour; each example cites its criterion):

```ruby
# spec/models/collection_import/apply_spec.rb
require "rails_helper"

# Spec 028: applying the account's stored upload, all or nothing.
RSpec.describe CollectionImport::Apply, type: :model do
  let(:user) { create(:user, name: "Grace", email_address: "grace@example.test") }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }
  let(:c) { import_printing }
  let(:d) { import_printing }
  let(:e) { import_printing }

  def preview!(lots, **fields) = store_import!(account:, data: import_file(user, lots, **fields))

  def apply(upload = account.reload.import_upload, confirmed: true, fingerprint: upload&.fingerprint)
    described_class.new(account: account.reload, fingerprint:, confirmed:).call
  end

  def lots_state = account.lots.order(:id).map { |lot| lot.attributes.except("id") }

  def snapshot
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata active_storage_blobs active_storage_attachments import_uploads]).sort.to_h do |table|
      [ table, connection.select_rows("SELECT * FROM #{connection.quote_table_name(table)} ORDER BY 1") ]
    end
  end

  describe "replacing the collection (AC-1.2 to AC-1.4, FR-9)" do
    it "makes the collection hold exactly the file's lots, keeping the changed lot's id", :aggregate_failures do
      held_a = held_lot(account, a, quantity: 3)
      held_b = held_lot(account, b, quantity: 2)
      held_c = held_lot(account, c, quantity: 4)
      held_lot(account, d, quantity: 7)
      preview!([ import_row(a, quantity: 3), import_row(b, quantity: 5, changed_at: "2026-10-02T10:00:00Z"), import_row(c, quantity: 4),
                 import_row(e, quantity: 6, finish: "foil", condition: "near_mint", price_paid: "12.50", added_at: "2026-09-01T00:00:00Z", changed_at: "2026-09-02T00:00:00Z") ])
      a_before = held_a.reload.attributes

      result = apply

      expect(result.outcome).to eq(:applied)
      expect(account.lots.count).to eq(4)
      expect(held_a.reload.attributes).to eq(a_before)
      expect(held_c.reload.updated_at).to eq(Time.iso8601("2026-10-01T10:00:00Z"))
      expect(held_b.reload).to have_attributes(quantity: 5, updated_at: Time.iso8601("2026-10-02T10:00:00Z"))
      added = account.lots.find_by!(catalog_entry_id: e.id)
      expect(added).to have_attributes(quantity: 6, finish: "foil", condition: "near_mint", price_paid_cents: 1250,
        created_at: Time.iso8601("2026-09-01T00:00:00Z"), updated_at: Time.iso8601("2026-09-02T00:00:00Z"))
      expect(account.lots.where(catalog_entry_id: d.id)).to be_empty
    end

    it "fills an empty account, and empties one for a file with no lots (AC-1.3, AC-1.4)", :aggregate_failures do
      preview!([ import_row(a), import_row(b, finish: "foil"), import_row(c, quantity: 9) ])
      apply
      expect(account.lots.count).to eq(3)

      empty_user = create(:user)
      held_lot(empty_user.account, a, quantity: 1)
      held_lot(empty_user.account, b, quantity: 2)
      store_import!(account: empty_user.account, data: import_file(empty_user, []))
      result = described_class.new(account: empty_user.account.reload, fingerprint: empty_user.account.import_upload.fingerprint, confirmed: true).call

      expect([ result.outcome, empty_user.account.lots.count ]).to eq([ :applied, 0 ])
    end
  end

  describe "afterwards (AC-1.5, AC-1.7, AC-1.9)" do
    it "previews as nothing to change, and writes no lot's updated_at again", :aggregate_failures do
      held_lot(account, d, quantity: 7)
      preview!([ import_row(a, quantity: 2), import_row(b) ])
      apply
      state = lots_state

      again = CollectionImport.new(account:, file: import_io(import_file(user, [ import_row(a, quantity: 2), import_row(b) ])))

      expect(again.plan.nothing_to_change?).to be(true)
      expect(lots_state).to eq(state)
    end

    it "removes the upload, its blob and its file, and queues no job; a second apply is refused (AC-1.9)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      key = upload.file.blob.key

      expect { apply(upload) }.not_to have_enqueued_job
      expect([ ImportUpload.count, ActiveStorage::Blob.service.exist?(key) ]).to eq([ 0, false ])
      expect(described_class.new(account: account.reload, fingerprint: upload.fingerprint, confirmed: true).call.outcome).to eq(:missing)
    end
  end

  describe "the profile (AC-1.6)" do
    it "sets a known view with a lot change, and never the name or email address", :aggregate_failures do
      preview!([ import_row(a) ], profile: { "name" => "Other Name", "email_address" => "other@example.test", "collection_view" => "table" })
      apply

      expect(user.reload).to have_attributes(collection_view: "table", name: "Grace", email_address: "grace@example.test")
    end

    it "ignores a view the instance doesn't know", :aggregate_failures do
      preview!([ import_row(a) ], profile: { "name" => "Grace", "email_address" => "grace@example.test", "collection_view" => "gallery" })
      apply

      expect(user.reload.collection_view).to eq("grid")
    end
  end

  describe "working state (decision 7, AC-1.8)" do
    def working_state_for(lot)
      entry = NumberEntry.create!(account:)
      line = entry.lines.create!(account:, entry: lot.entry, lot:, quantity: 1, finish: nil, line_key: SecureRandom.hex(16))
      sitting = Scanner::Sitting.create!(account:)
      sitting.entries.create!(account:, printing: lot.entry, lot:, finish: nil, reading_key: SecureRandom.hex(16))
      session = user.sessions.create!
      selection = BulkSelection.for(session)
      selection.marks.create!(account:, lot:)
      removal = BulkRemoval.create!(session:, account:, copies: 1, lots_data: [ { "catalog_entry_id" => lot.catalog_entry_id, "quantity" => 1 } ])
      [ line, sitting, selection, removal ]
    end

    it "clears the lists that point at lots when the apply writes", :aggregate_failures do
      lot = held_lot(account, d, quantity: 3)
      _line, _sitting, _selection, removal = working_state_for(lot)
      preview!([ import_row(a) ])
      apply

      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count + BulkSelection::Mark.count).to eq(0)
      expect(removal.reload).not_to be_undoable
      expect(NumberEntry::Line.count + Scanner::SittingEntry.count).to eq(0)
    end

    it "clears nothing when the apply is refused", :aggregate_failures do
      lot = held_lot(account, a, quantity: 3)
      working_state_for(lot)
      upload = preview!([ import_row(a, quantity: 4) ])
      lot.update_columns(quantity: 9) # stale
      before = snapshot

      expect(apply(upload).outcome).to eq(:stale)
      expect(snapshot).to eq(before)
    end
  end

  describe "all or nothing (AC-2.1, AC-2.2)" do
    it "rolls everything back when a write fails after the lots were written, keeping the upload", :aggregate_failures do
      held_lot(account, d, quantity: 3)
      held_lot(account, a, quantity: 1)
      upload = preview!([ import_row(a, quantity: 2), import_row(b) ])
      before = snapshot
      allow(CollectionImport::WorkingState).to receive(:clear!).and_raise(RuntimeError, "disk full")

      expect { apply(upload) }.to raise_error(RuntimeError, "disk full")
      expect(snapshot).to eq(before)
      expect(account.reload.import_upload).to eq(upload)
      expect(upload.read).to be_present

      allow(CollectionImport::WorkingState).to receive(:clear!).and_call_original
      expect(apply(upload).outcome).to eq(:applied)
    end

    it "refuses a second apply of the same upload as nothing to change, changing nothing", :aggregate_failures do
      upload = preview!([ import_row(a, quantity: 2) ])
      first = upload.fingerprint
      apply(upload)
      state = lots_state
      ImportUpload.create!(account:, fingerprint: first, expires_at: 1.hour.from_now).file.attach(io: import_io(import_file(user, [ import_row(a, quantity: 2) ])), filename: "x.json", content_type: "application/json")
      before = snapshot

      result = described_class.new(account: account.reload, fingerprint: first, confirmed: true).call

      expect(result.outcome).to eq(:nothing_to_change)
      expect(lots_state).to eq(state)
      expect(snapshot).to eq(before)
    end
  end

  describe "a lost race (AC-2.3, AC-2.5, AC-5.6)" do
    it "answers :missing when the upload was removed after it was read, writing nothing", :aggregate_failures do
      held_lot(account, d, quantity: 3)
      upload = preview!([ import_row(a) ])
      before = lots_state
      allow(CollectionImport).to receive(:new).and_wrap_original do |original, **args|
        original.call(**args).tap { ImportUpload.where(id: upload.id).delete_all } # removed between reading and the transaction
      end

      expect(apply(upload).outcome).to eq(:missing)
      expect(lots_state).to eq(before)
    end

    it "judges expiry inside the transaction, whatever the sweep's timing", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      allow(CollectionImport).to receive(:new).and_wrap_original do |original, **args|
        original.call(**args).tap { upload.update_columns(expires_at: 1.minute.ago) }
      end

      expect(apply(upload).outcome).to eq(:expired)
      expect(account.lots).to be_empty
    end

    it "answers :unreadable for a stored file that is gone", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      ActiveStorage::Blob.service.delete(upload.file.blob.key)

      expect(apply(upload).outcome).to eq(:unreadable)
      expect(account.lots).to be_empty
    end
  end

  describe "valid lots (AC-2.4, FR-3)" do
    it "writes lots that Lot would accept, with the key Lot gives", :aggregate_failures do
      preview!([ import_row(a, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid: "0.05"), import_row(b, finish: nil) ])
      apply

      account.lots.each do |lot|
        expect(lot).to be_valid
        expect(lot.lot_key).to eq(Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents))
      end
    end
  end

  describe "bounded statements (FR-4)" do
    it "runs as many statements for 30 rows as for 2", :aggregate_failures do
      counts = [ 2, 30 ].map do |size|
        other = create(:user)
        entries = Array.new(size) { import_printing }
        store_import!(account: other.account, data: import_file(other, entries.map { |entry| import_row(entry) }))
        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\ASAVEPOINT|\ARELEASE/) }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          described_class.new(account: other.account.reload, fingerprint: other.account.import_upload.fingerprint, confirmed: true).call
        end
        queries
      end

      expect(counts.first).to eq(counts.last)
    end
  end

  describe "what was previewed is what is applied (AC-3.1 to AC-3.6)" do
    it "refuses a changed collection as stale and stores the new fingerprint (AC-3.1)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      upload = preview!([ import_row(a, quantity: 5) ])
      old = upload.fingerprint
      lot.update!(quantity: 3)
      before = lots_state

      result = apply(upload)

      expect(result.outcome).to eq(:stale)
      expect(lots_state).to eq(before)
      expect(upload.reload.fingerprint).not_to eq(old)
      expect(result.fingerprint).to eq(upload.fingerprint)
    end

    it "refuses a form from a replaced upload as stale (AC-3.2)", :aggregate_failures do
      first = preview!([ import_row(a) ])
      old = first.fingerprint
      preview!([ import_row(b) ])

      result = apply(account.reload.import_upload, fingerprint: old)

      expect(result.outcome).to eq(:stale)
      expect(account.lots).to be_empty
    end

    it "says missing or expired when there is no upload or it has expired (AC-3.3)", :aggregate_failures do
      expect(apply(nil, fingerprint: "x").outcome).to eq(:missing)
      upload = preview!([ import_row(a) ])
      travel_to(ImportUpload::EXPIRES_IN.from_now + 1.minute) { expect(apply(upload).outcome).to eq(:expired) }
    end

    it "refuses a stored file the catalog no longer resolves and removes it (AC-3.4)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      Catalog::Entry.where(id: a.id).update_all(external_key: "moved") # rubocop:disable Rails/SkipsModelValidations -- the spec changes the catalog under the stored file
      key = upload.file.blob.key

      result = apply(upload)

      expect(result.outcome).to eq(:refused)
      expect([ ImportUpload.count, ActiveStorage::Blob.service.exist?(key) ]).to eq([ 0, false ])
    end

    it "needs the removal confirmed, and only when lots are removed (AC-3.5)", :aggregate_failures do
      held_lot(account, d, quantity: 1)
      upload = preview!([ import_row(a) ])
      expect(apply(upload, confirmed: false).outcome).to eq(:unconfirmed)
      expect(account.lots.count).to eq(1)
      expect(account.reload.import_upload).to eq(upload)
      expect(apply(upload, confirmed: true).outcome).to eq(:applied)

      other = create(:user)
      store_import!(account: other.account, data: import_file(other, [ import_row(b) ]))
      result = described_class.new(account: other.account.reload, fingerprint: other.account.import_upload.fingerprint, confirmed: false).call
      expect(result.outcome).to eq(:applied)
    end

    it "gives decision 13's response for combined causes (AC-3.6)", :aggregate_failures do
      lot = held_lot(account, d, quantity: 1)
      upload = preview!([ import_row(a) ])
      lot.update_columns(quantity: 2)
      expect(apply(upload, confirmed: false).outcome).to eq(:stale) # stale and unconfirmed: the 409

      other = create(:user)
      held = held_lot(other.account, a, quantity: 1)
      up = store_import!(account: other.account, data: import_file(other, [ import_row(a, quantity: 2) ]))
      held.update_columns(quantity: 2) # the file's change was made some other way
      expect(described_class.new(account: other.account.reload, fingerprint: up.fingerprint, confirmed: true).call.outcome).to eq(:nothing_to_change)
    end
  end

  describe "only this account (AC-4.1)" do
    it "leaves every other account's rows as they were", :aggregate_failures do
      stranger = create(:user)
      held_lot(stranger.account, a, quantity: 5)
      store_import!(account: stranger.account, data: import_file(stranger, [ import_row(b) ]))
      held_lot(account, a, quantity: 1)
      upload = preview!([ import_row(a, quantity: 9) ])
      theirs = stranger.account.lots.map(&:attributes)
      their_upload = stranger.account.import_upload.attributes

      apply(upload)

      expect(stranger.account.lots.reload.map(&:attributes)).to eq(theirs)
      expect(stranger.account.reload.import_upload.attributes).to eq(their_upload)
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/collection_import/apply_spec.rb` — expect FAIL (`uninitialized constant CollectionImport::Apply`).
- [ ] Implement the working-state clearing and the apply:

```ruby
# app/models/collection_import/working_state.rb
# Ends the per-account lists that point at lots, which a replaced collection makes wrong (spec 028 decision 7): bulk
# removals can no longer be undone, bulk selections go, and the number-entry list and scanner sitting are done.
module CollectionImport::WorkingState
  def self.clear!(account)
    account.number_entry&.destroy!
    account.scanner_sitting&.destroy!
    account.bulk_selections.destroy_all
    account.bulk_removals.undoable.find_each { |removal| removal.update!(lots_data: nil) }
  end
end
```

```ruby
# app/models/collection_import/apply.rb
# Applies the account's stored upload (spec 028): reads and judges the file outside any transaction, then decides and
# writes inside one short all-or-nothing transaction. It touches +account+ only. Collectible-agnostic.
class CollectionImport::Apply
  Result = Data.define(:outcome, :import, :plan, :upload, :fingerprint)

  def initialize(account:, fingerprint:, confirmed:)
    @account = account
    @fingerprint = fingerprint.to_s
    @confirmed = confirmed
  end

  # Decision 13's order. The early outs before the transaction answer the same as the transaction would; the
  # transaction decides presence, expiry and fingerprints once more (FR-2).
  def call
    upload = @account.import_upload
    return result(:missing) unless upload
    return result(:expired, upload:) if upload.expired?

    bytes = upload.read
    return result(:unreadable, upload:) unless bytes

    import = CollectionImport.new(account: @account, file: StringIO.new(bytes))
    return refuse(upload, import, :refused) unless import.applicable?

    decide(upload, import)
  end

  private
    def decide(upload, import)
      result = ImportUpload.transaction do
        current = ImportUpload.find_by(account_id: @account.id)
        next result(:missing) unless current&.id == upload.id
        next result(:expired, upload: current) if current.expired?

        plan = import.replan
        next result(:nothing_to_change, import:, plan:, upload: current) if plan.nothing_to_change?

        now = plan.fingerprint(current.checksum)
        next result(:stale, import:, plan:, upload: current, fingerprint: now) unless [ @fingerprint, current.fingerprint ].all?(now)
        next result(:unconfirmed, import:, plan:, upload: current, fingerprint: now) if plan.removes? && !@confirmed

        write!(plan, import)
        current.destroy!
        result(:applied, import:, plan:)
      end
      settle(result, upload)
    end

    # Outside the transaction: the blob and file of an applied or refused upload are purged by the destroy's callback
    # (applied) or here; a stale plan keeps the upload with its new fingerprint.
    def settle(result, upload)
      case result.outcome
      when :nothing_to_change then upload.destroy!
      when :stale then upload.update!(fingerprint: result.fingerprint)
      end
      result
    end

    def refuse(upload, import, outcome)
      upload.destroy!
      result(outcome, import:, upload:)
    end

    def result(outcome, import: nil, plan: nil, upload: nil, fingerprint: nil) = Result.new(outcome:, import:, plan:, upload:, fingerprint:)

    # One statement per BATCH_SIZE lots, never one per lot (FR-4). The upsert is on the lot's identity, so a changed
    # lot keeps its id (FR-9); the rows were validated by the reader. The bulk statements skip Lot's callbacks and
    # validations on purpose (spec 028 FR-3, ruled 2026-10-20; AC-2.4 checks the rows against Lot).
    def write!(plan, import)
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |rows|
        Lot.upsert_all(rows.map { |row| lot_attributes(row, import) }, unique_by: %i[account_id catalog_entry_id lot_key],
          update_only: %i[quantity created_at updated_at], record_timestamps: false)
      end
      CollectionImport::WorkingState.clear!(@account)
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end

    def lot_attributes(row, import)
      lot = row.lot
      finish = lot["finish"].presence
      condition = lot["condition"].presence
      cents = lot["price_paid"]&.delete(".")&.to_i
      { account_id: @account.id, catalog_entry_id: import.entry_id(row), quantity: lot["quantity"], finish:, condition:,
        price_paid_cents: cents, lot_key: Lot.key_for(finish, condition, cents),
        created_at: Time.iso8601(lot["added_at"]), updated_at: Time.iso8601(lot["changed_at"]) }
    end
end
```

- [ ] Run the spec — expect PASS. Expected adjustments, allowed within this phase: the stale-fingerprint comparison reads `[ @fingerprint, current.fingerprint ].all?(now)`; `account.bulk_selections.destroy_all` relies on `BulkSelection has_many :marks, dependent: :delete_all`; keep the `# rubocop:disable` comment justified as written or build the moved entry with `update_columns` if the cop doesn't fire. If `account.import_upload` is cached in `call`, load it with `ImportUpload.find_by(account_id: @account.id)`.
- [ ] Run `bin/rspec spec/models` — expect PASS; `bin/rubocop -a app/models spec/models`.
- [ ] Commit: `feat(028): apply a stored import in one transaction`

---

## Phase 6: The preview stores the upload and offers the apply

**Implements:** decisions 1, 6, 8, 10, 11 (preview side); FR-7 | **Satisfies:** AC-1.1, AC-1.11, AC-5.1 to AC-5.3, AC-7.1
**Files:** `app/controllers/collections/import_previews_controller.rb`, `app/views/collections/import_previews/show.html.erb`, `app/views/collections/import_previews/_apply.html.erb`, `spec/requests/collection_import_previews_spec.rb`, `spec/models/collection_import_spec.rb`
**Interfaces:** Consumes: `ImportUpload.store!`, `CollectionImport#plan`. Produces: ivars `@upload` (`ImportUpload` or nil), `@store_failed` for `show`; the partial `import_previews/apply` with locals `import:, upload:`; route helpers used: `collection_import_path` (added in Phase 7; Phase 6's spec for the form reads the form's `action` string `/collection/import`, and the route is added at the start of this phase's implementation).

- [ ] Add the route now (the form needs it): in `config/routes.rb`, inside the `scope module: :collections` block after `resource :import_preview`: `resource :import, only: :create`. Run `bin/rails routes -g "collection/import"` — expect `POST /collection/import collections/imports#create`.
- [ ] Write the failing request examples (added to `spec/requests/collection_import_previews_spec.rb`, inside "when signed in"; the file's own helpers `row`, `file`, `upload`, `preview`, `snapshot` stay):

```ruby
    describe "the stored upload and the apply form (spec 028)" do
      let(:entry) { printing }

      def form = html.at_css("form[action='#{collection_import_path}']")

      it "offers the apply for a file with something to change, outside Turbo, with the fingerprint (AC-1.1, AC-7.1)", :aggregate_failures do
        create(:lot, account: user.account, entry: printing(name: "Held"), quantity: 7)
        preview(file([ row(entry, quantity: 2) ]))

        expect(form["data-turbo"]).to eq("false")
        expect(form.at_css("input[name=authenticity_token]")).to be_present
        expect(form.at_css("input[type=file]")).to be_nil
        expect(form.at_css("input[name=fingerprint]")["value"]).to eq(user.account.import_upload.fingerprint)
        expect(form.at_css("input[type=submit]")["value"]).to eq("Apply import")
        expect(form.at_css("input[name=confirm_removal]")).to be_present # a lot is removed
        expect(html.at_css("a[href='#{collection_export_path}']")).to be_present
        expect(response.body).to match(/removes 1 lot/).and match(/can't be undone/).and match(/kept for an hour/)
      end

      it "needs no checkbox when nothing is removed (AC-3.5)" do
        preview(file([ row(entry) ]))

        expect(form.at_css("input[name=confirm_removal]")).to be_nil
      end

      it "stores nothing for a file with problems, a refused file or a file with nothing to change (AC-1.1, AC-1.11)", :aggregate_failures do
        create(:lot, account: user.account, entry:, quantity: 1)
        [ file([ row(entry, quantity: 1) ]), file([ stranger ]), "not json" ].each do |data|
          before = snapshot
          expect { preview(data) }.not_to have_enqueued_job
          expect(html.css("form[action='#{collection_import_path}']")).to be_empty
          expect(snapshot).to eq(before)
        end
        expect(ImportUpload.count + ActiveStorage::Blob.count).to eq(0)
        preview(file([ row(entry, quantity: 1) ]))
        expect(response.body).to include("nothing to change")
      end

      it "writes only the upload, its blob and its attachment (AC-1.11)", :aggregate_failures do
        before = snapshot
        expect { preview(file([ row(entry) ])) }.not_to have_enqueued_job
        changed = snapshot.reject { |table, rows| before[table] == rows }

        expect(changed.keys).to match_array(%w[import_uploads active_storage_blobs active_storage_attachments])
      end

      it "stores the file as application/json by content, one per account, replacing the earlier (AC-5.1, AC-5.2)", :aggregate_failures do
        preview(file([ row(entry) ]), type: "image/png", name: "cards.txt")
        first = user.account.reload.import_upload
        expect(first.file.blob.content_type).to eq("application/json")
        expect(first.expires_at).to be_within(1.minute).of(ImportUpload::EXPIRES_IN.from_now)

        preview(file([ row(entry, quantity: 4) ]))
        expect(ImportUpload.count).to eq(1)
        expect(ImportUpload.first.id).not_to eq(first.id)
        preview(file([ stranger ]))
        expect(ImportUpload.count).to eq(1) # a preview that stores nothing leaves the earlier one
      end

      it "shows the counts and no apply when the store fails (spec 028 error scenarios)", :aggregate_failures do
        allow(ImportUpload).to receive(:store!).and_raise(Errno::ENOSPC)
        preview(file([ row(entry) ]))

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("couldn't keep this file")
        expect(form).to be_nil
      end

      it "stores nothing over 32 MB or that isn't an export (AC-5.3)", :aggregate_failures do
        preview("not json")
        expect(ImportUpload.count).to eq(0)
      end
    end
```

- [ ] Run `bin/rspec spec/requests/collection_import_previews_spec.rb` — expect FAIL on the new examples (no form).
- [ ] Update the preview controller:

```ruby
# app/controllers/collections/import_previews_controller.rb
# Spec 025: a collector uploads an export file and sees what applying it would do. Spec 028 (decisions 1, 10): a file that
# can be applied and has something to change is kept for an hour, so that it can be applied with one click.
class Collections::ImportPreviewsController < ApplicationController
  def new
    no_store
  end

  def create
    no_store
    file = params[:export_file]
    @import = CollectionImport.new(account: Current.account, file:)
    return render(:new, status: :unprocessable_content) if @import.refused?

    @unloaded_catalogs = @import.unloaded_catalog_titles
    @catalogs_named = Catalog.sources.many?
    @upload = keep(file) if @import.applicable? && !@import.plan.nothing_to_change?
    render :show
  end

  private
    def keep(file)
      file.rewind
      ImportUpload.store!(account: Current.account, bytes: file.read, plan: @import.plan)
    rescue ActiveStorage::Error, SystemCallError, ActiveRecord::ActiveRecordError => error
      Rails.logger.error("The previewed import file was not kept: #{error.class}")
      @store_failed = true
      nil
    end
end
```

- [ ] Update `show.html.erb`: replace the "This file can be applied." paragraph's neighbour with the new cases and render the partial below the stats and above the profile notes:

```erb
    <% if @import.applicable? && @import.plan.nothing_to_change? %>
      <p class="c-status__message">This file has nothing to change: your collection already holds what it describes.</p>
    <% end %>
    ...stats...
    <%= render "collections/import_previews/apply", import: @import, upload: @upload, store_failed: @store_failed if @import.applicable? && !@import.plan.nothing_to_change? %>
```

```erb
<%# app/views/collections/import_previews/_apply.html.erb %>
<% plan = import.plan %>
<% if upload %>
  <%= form_with url: collection_import_path, class: "c-form c-import__apply", data: { turbo: false } do |form| %>
    <%= hidden_field_tag :fingerprint, upload.fingerprint %>
    <% if plan.removes? %>
      <p class="c-import__note">Applying removes <%= pluralize(number_with_delimiter(plan.removed_lots.size), "lot") %> (<%= pluralize(number_with_delimiter(import.removed.copies), "copy") %>) and can't be undone. <%= link_to "Download your current collection first", collection_export_path %>.</p>
      <div class="c-field">
        <label class="c-check"><%= check_box_tag :confirm_removal, "1", false, required: true %> I understand this removes <%= pluralize(number_with_delimiter(plan.removed_lots.size), "lot") %></label>
      </div>
    <% else %>
      <p class="c-import__note">Applying can't be undone. <%= link_to "Download your current collection first", collection_export_path %>.</p>
    <% end %>
    <p class="c-import__note">This preview is kept for an hour.</p>
    <div class="c-form__actions"><%= form.submit "Apply import", class: "c-btn c-btn--primary" %></div>
  <% end %>
<% elsif store_failed %>
  <p class="c-status__message c-status__message--alert">We couldn't keep this file, so it can't be applied. Choose it again.</p>
<% end %>
```

  (If the design system has no `c-check`, use the checkbox markup of `docs/design-system/components/Form.md`; do not invent classes.)
- [ ] Update spec 025's superseded examples: in `spec/models/collection_import_spec.rb` leave "writes nothing (FR-6)" (the model still writes nothing); in `spec/requests/collection_import_previews_spec.rb` change "writes nothing and queues nothing (AC-1.8)" so that its file is one with nothing to change or problem rows and its title cites spec 028 decision 10 ("still writes nothing for a refused file, problem rows or nothing to change").
- [ ] Run `bin/rspec spec/requests/collection_import_previews_spec.rb spec/models/collection_import_spec.rb spec/requests/active_storage_gate_spec.rb` — expect PASS.
- [ ] Commit: `feat(028): the preview keeps an applicable file and offers the apply`

---

## Phase 7: POST /collection/import

**Implements:** decisions 2, 11, 12, 13; FR-5, FR-6 | **Satisfies:** AC-1.2 to AC-1.4 (HTTP), AC-1.9, AC-2.1 (500), AC-2.3, AC-3.1 to AC-3.6 (HTTP), AC-4.2, AC-4.3
**Files:** `app/controllers/collections/imports_controller.rb`, `app/views/collections/imports/failed.html.erb`, `spec/requests/collection_imports_spec.rb`
**Interfaces:** Consumes: `CollectionImport::Apply`, `Result`, the preview views. Produces: `POST /collection/import` per `contracts/api.md`.

- [ ] Write the failing request spec:

```ruby
# spec/requests/collection_imports_spec.rb
require "rails_helper"

# Spec 028: applying the stored upload.
RSpec.describe "Apply an import", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }

  def preview!(lots) = store_import!(account:, data: import_file(user, lots))
  def apply(upload = account.reload.import_upload, **params) = post(collection_import_path, params: { fingerprint: upload&.fingerprint, confirm_removal: "1" }.merge(params))
  def html = Nokogiri::HTML5(response.body)

  context "when signed in" do
    before { sign_in_as(user) }

    it "applies and redirects with the counts (AC-1.2)", :aggregate_failures do
      held_lot(account, import_printing, quantity: 7)
      preview!([ import_row(a, quantity: 6) ])

      apply

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path)
      follow_redirect!
      expect(response.body).to include("Imported: 1 lot added, 0 changed, 1 removed")
      expect(account.lots.pluck(:quantity)).to eq([ 6 ])
      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "refuses a second post with 'Preview the file again.' and writes nothing (AC-1.9)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      apply(upload)
      apply(upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview the file again.")
      expect(account.lots.count).to eq(1)
    end

    it "answers 409 with a fresh preview and a new fingerprint when the plan changed (AC-3.1, AC-3.2)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      upload = preview!([ import_row(a, quantity: 5) ])
      lot.update!(quantity: 3)

      apply(upload)

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("changed since you looked")
      expect(html.at_css("input[name=fingerprint]")["value"]).to eq(upload.reload.fingerprint)
      expect(lot.reload.quantity).to eq(3)
    end

    it "answers 422 on the upload page for a missing or expired upload (AC-3.3)", :aggregate_failures do
      post collection_import_path, params: { fingerprint: "x" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview the file again.")

      upload = preview!([ import_row(a) ])
      travel_to(2.hours.from_now) { apply(upload) }
      expect(response.body).to include("Your preview has expired. Choose the file again.")
    end

    it "answers 422 with the preview's reasons when the stored file no longer resolves (AC-3.4)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      Catalog::Entry.where(id: a.id).update_all(external_key: "moved")

      apply(upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("can't be applied")
      expect(ImportUpload.count).to eq(0)
    end

    it "asks for the confirmation of a removal (AC-3.5)", :aggregate_failures do
      held_lot(account, import_printing, quantity: 1)
      upload = preview!([ import_row(a) ])

      post collection_import_path, params: { fingerprint: upload.fingerprint }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirm the removal to apply this file")
      expect(account.lots.count).to eq(1)
      expect(account.reload.import_upload).to eq(upload)
    end

    it "says nothing to change when the plan is empty (decision 12)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      held_lot(account, a, quantity: 1)

      apply(upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("This file has nothing to change")
    end

    it "answers 500 with a page saying nothing changed, keeping the upload (AC-2.1)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      allow(CollectionImport::WorkingState).to receive(:clear!).and_raise(RuntimeError, "disk full")

      apply(upload)

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("Nothing was changed")
      expect([ account.lots.count, account.reload.import_upload ]).to eq([ 0, upload ])
    end

    it "ignores account, upload and lot parameters (AC-4.2)", :aggregate_failures do
      other = create(:user)
      their_upload = store_import!(account: other.account, data: import_file(other, [ import_row(b) ]))
      upload = preview!([ import_row(a) ])

      apply(upload, account_id: other.account.id, upload_id: their_upload.id, lot_id: 1)

      expect(account.lots.pluck(:catalog_entry_id)).to eq([ a.id ])
      expect(other.account.lots).to be_empty
      expect(other.account.reload.import_upload).to eq(their_upload)
    end
  end

  it "sends a visitor to sign in without reading anything (AC-4.3)", :aggregate_failures do
    allow(CollectionImport).to receive(:new)

    post collection_import_path, params: { fingerprint: "x" }

    expect(response).to redirect_to(new_session_path)
    expect(CollectionImport).not_to have_received(:new)
  end
end
```

- [ ] Run `bin/rspec spec/requests/collection_imports_spec.rb` — expect FAIL (`uninitialized constant Collections::ImportsController`).
- [ ] Implement:

```ruby
# app/controllers/collections/imports_controller.rb
# Spec 028: applies the signed-in collector's stored upload. Nothing in the request names an account, an upload or a lot.
class Collections::ImportsController < ApplicationController
  PREVIEW_AGAIN = "Preview the file again.".freeze

  def create
    no_store
    result = CollectionImport::Apply.new(account: Current.account, fingerprint: params[:fingerprint], confirmed: params[:confirm_removal] == "1").call
    respond_to_result(result)
  rescue StandardError => error
    Rails.logger.error("Applying an import failed: #{error.class}")
    render :failed, status: :internal_server_error
  end

  private
    def respond_to_result(result)
      case result.outcome
      when :applied then redirect_to collection_path, notice: notice_for(result.plan.counts), status: :see_other
      when :missing, :unreadable then upload_page(PREVIEW_AGAIN)
      when :expired then upload_page("Your preview has expired. Choose the file again.")
      when :refused then refused(result.import)
      when :nothing_to_change then preview(result, "This file has nothing to change", :unprocessable_content)
      when :stale then preview(result, "The collection or the file changed since you looked. This is what applying would do now.", :conflict)
      when :unconfirmed then preview(result, "Confirm the removal to apply this file", :unprocessable_content)
      end
    end

    def notice_for(counts)
      "Imported: #{pluralize(counts[:added], "lot")} added, #{counts[:changed]} changed, #{counts[:removed]} removed"
    end

    def upload_page(message)
      flash.now[:alert] = message
      render "collections/import_previews/new", status: :unprocessable_content
    end

    def refused(import)
      @import = import
      return render("collections/import_previews/new", status: :unprocessable_content) if @import.refused?

      render_preview(import, nil, :unprocessable_content)
    end

    def preview(result, message, status)
      flash.now[:alert] = message
      render_preview(result.import, result.upload, status)
    end

    def render_preview(import, upload, status)
      @import = import
      @upload = upload
      @unloaded_catalogs = import.unloaded_catalog_titles
      @catalogs_named = Catalog.sources.many?
      render "collections/import_previews/show", status:
    end
end
```

  `pluralize` in a controller: use `helpers.pluralize`; format "1 lot added" with `helpers.pluralize(counts[:added], "lot")`. `Result#upload` for a stale/unconfirmed/nothing-to-change outcome is `current`, whose fingerprint was updated in `settle`; `@upload` for `:nothing_to_change` is destroyed — pass `nil` there (the `show` page then offers no form, matching the plan): in `preview`, use `upload = nil if result.outcome == :nothing_to_change`. The stale page shows the form with the fresh fingerprint via `@upload` (reloaded by `settle`'s `update!`).

```erb
<%# app/views/collections/imports/failed.html.erb %>
<% content_for :title, "Import failed · Collector" %>
<%= render "layouts/appbar", section: nil %>
<main class="c-main c-page">
  <div class="c-pagehead"><div><h1 class="c-pagehead__title">The import didn't finish</h1></div></div>
  <p class="c-status__message c-status__message--alert">Nothing was changed. Your collection is as it was, and the preview is still kept, so you can try again.</p>
  <div class="c-form__actions"><%= link_to "Back to your collection", collection_path, class: "c-btn c-btn--secondary" %></div>
</main>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Run the spec — expect PASS; `bin/rspec spec/requests spec/models` — expect PASS.
- [ ] Commit: `feat(028): POST /collection/import applies the stored upload`

---

## Phase 8: The round trip

**Implements:** Story 6 | **Satisfies:** AC-6.1 to AC-6.4
**Files:** `spec/models/collection_import/round_trip_spec.rb`
**Interfaces:** Consumes: `CollectionExport`, `CollectionImport`, `Apply`, `ExportFormatRules.same_collection?`. Produces: the round-trip evidence.

- [ ] Write the spec (it fails only if applying does not restore the collection; it is written before any adjustment, so a first red here is a bug to fix in Phases 4–5):

```ruby
# spec/models/collection_import/round_trip_spec.rb
require "rails_helper"

# Spec 028 Story 6: export → import restores the collection (the 1.0 test's second check).
RSpec.describe "Export and import round trip", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let(:target) { create(:user, name: "Target", email_address: "target@example.test") }

  def export(user, at: Time.utc(2026, 10, 20, 12)) = JSON.parse(CollectionExport.new(account: user.account, at:).to_json)

  # The same collection under the format's rule, the profile's name and email address apart (apply never changes them).
  def same_collection?(one, other)
    ExportFormatRules.same_collection?(one.merge("profile" => one["profile"].except("name", "email_address")),
      other.merge("profile" => other["profile"].except("name", "email_address")))
  end

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  before do
    a = import_printing
    b = import_printing
    c = import_printing
    held_lot(source.account, a, quantity: 4, finish: "foil", condition: "near_mint", price_paid_cents: 1250, added_at: "2026-01-02T03:04:05Z", changed_at: "2026-02-03T04:05:06Z")
    held_lot(source.account, a, quantity: 1, finish: "nonfoil", added_at: "2026-03-01T00:00:00Z")
    held_lot(source.account, b, quantity: 9_999, condition: "damaged", price_paid_cents: 5, added_at: "2026-04-01T00:00:00Z")
    held_lot(source.account, c, quantity: 2)
  end

  it "has nothing to change for the collection that was exported, and stores nothing (AC-6.1)", :aggregate_failures do
    import = CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(export(source))))

    expect(import.unchanged.lots).to eq(4)
    expect(import.plan.nothing_to_change?).to be(true)
    expect(ImportUpload.count).to eq(0)
  end

  it "restores an export into an empty account of the same catalog (AC-6.2)", :aggregate_failures do
    original = export(source)

    expect(apply!(target, original).outcome).to eq(:applied)
    restored = export(target)

    expect(same_collection?(original, restored)).to be(true)
    expect(ExportFormatRules.problems(JSON.generate(restored))).to be_empty
  end

  it "restores a changed collection from the file (AC-6.3)", :aggregate_failures do
    original = export(source)
    source.account.lots.order(:id).first.update!(quantity: 1)
    source.account.lots.order(:id).last.destroy!
    held_lot(source.account, import_printing, quantity: 3)

    expect(apply!(source, original).outcome).to eq(:applied)

    expect(same_collection?(original, export(source))).to be(true)
    expect(CollectionImport.new(account: source.account, file: StringIO.new(JSON.generate(original))).plan.nothing_to_change?).to be(true)
  end

  describe "the format's valid examples (AC-6.4)" do
    ExportFormatRules.examples("valid").each do |path, bytes|
      it "applies #{path} to an empty account and exports the same collection", :aggregate_failures do
        data = JSON.parse(bytes)
        data["lots"].each do |lot|
          entry = lot["entry"]
          set = Catalog::Set.find_by(collectible_type: entry["collectible_type"], code: entry["set_code"]) || create(:catalog_set, code: entry["set_code"])
          created = create(:catalog_entry, external_key: entry["source_id"], set:, number: entry["collector_number"], language: entry["language"], name: entry["name"])
          create(:mtg_printing, entry: created, finishes: [ "nonfoil", "foil", "etched", lot["finish"] ].compact.uniq)
        end
        user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

        if data["lots"].empty?
          import = CollectionImport.new(account: user.account, file: StringIO.new(bytes))
          expect([ import.plan.nothing_to_change?, ImportUpload.count ]).to eq([ true, 0 ])
        else
          expect(apply!(user, data).outcome).to eq(:applied)
          expect(same_collection?(data, export(user))).to be(true)
        end
      end
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/collection_import/round_trip_spec.rb` — expect PASS once Phases 4–5 hold; any red is a defect there (fix, then rerun). If `Catalog::Set` is named differently, use the constant `spec/factories/catalog.rb` builds; the instance currency is USD, as the examples' (`docs/export-format/examples/valid/*.json` `"currency"`); if an example uses another currency, set `Rails.configuration.x.currency` for the example with `allow(Rails.configuration.x).to receive(:currency).and_return(...)` using the type `Collector::Currency` already offers.
- [ ] Commit: `test(028): export and import round trip`

---

## Phase 9: The flow in the browser, and the pages' look

**Implements:** Story 7 | **Satisfies:** AC-7.2, AC-7.3, AC-7.4
**Files:** `spec/system/collection_import_apply_spec.rb`, `spec/system/narrow_pages_spec.rb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/ImportPreview.md`
**Interfaces:** Consumes: the pages of Phases 6–7. Produces: the system spec and, only if a new class is needed, its CSS and doc.

- [ ] Write the failing system spec:

```ruby
# spec/system/collection_import_apply_spec.rb
require "rails_helper"

# Spec 028 AC-7.2: choose a file, preview it, apply it.
RSpec.describe "Apply an import", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:path) { Rails.root.join("tmp/import-apply-#{SecureRandom.hex(4)}.json") }

  after { FileUtils.rm_f(path) }

  it "ends on the collection with a notice and the file's lots", :aggregate_failures do
    kept = create(:mtg_printing).entry
    other = create(:mtg_printing).entry
    create(:lot, account: user.account, entry: other, quantity: 2)
    path.write(JSON.generate(import_file(user, [ import_row(kept, quantity: 3) ])))

    visit new_collection_import_preview_path
    attach_file "Export file", path.to_s
    click_on "Preview import"
    expect(page).to have_button("Apply import")
    check "I understand this removes 1 lot"
    click_on "Apply import"

    expect(page).to have_css("#status", text: "Imported: 1 lot added, 0 changed, 1 removed")
    expect(page).to have_text(kept.name)
    expect(user.account.lots.pluck(:quantity)).to eq([ 3 ])
  end
end
```

  Add the preview-with-apply page (a stored upload) to `spec/system/narrow_pages_spec.rb`'s list of narrow pages, following the entries already there for the upload page (no sideways scroll at 360 px).
- [ ] Run `bin/rspec spec/system/collection_import_apply_spec.rb` — expect FAIL until the label text and flow match; adjust the partial's label if needed, then expect PASS.
- [ ] Read `docs/design-system/README.md`; confirm the apply form uses only existing tokens and `c-*` classes (`c-form`, `c-field`, `c-btn`, `c-import__note`, `c-status__message`). If a class was added (`c-import__apply`, the checkbox label), define it in `additions.css` with tokens only and add a section to `docs/design-system/components/ImportPreview.md` showing the apply form and the stale-plan notice markup.
- [ ] Capture screenshots at 1280 px and 390 px, light and dark, for: the preview with the apply form, the stale-plan page (409), a refused apply (422), the notice after applying (method of spec 025's `screenshots/`: headless Firefox; memory "Headless Firefox narrow frame"); save under `docs/specs/028-apply-import/screenshots/`; they are recorded in `verification.md` (Phase 13).
- [ ] Commit: `feat(028): the apply flow in the browser and its pages`

---

## Phase 10: The core stays collectible-agnostic, and the file stays out of logs

**Implements:** FR-6, FR-8 | **Satisfies:** FR-6, FR-8 (no AC)
**Files:** `spec/import_apply_core_spec.rb`
**Interfaces:** Consumes: file paths of Phases 0–7. Produces: the FR-8 guard.

- [ ] Write the spec (modelled on `spec/collection_import_core_spec.rb`):

```ruby
# spec/import_apply_core_spec.rb
require "rails_helper"

# Spec 028 FR-8: the apply and the stored upload name no collectible type or source. FR-6: the file isn't logged.
RSpec.describe "Apply an import, core code" do
  FILES = %w[
    app/models/import_upload.rb app/jobs/import_upload/sweep_job.rb app/models/collection_import/plan.rb
    app/models/collection_import/apply.rb app/models/collection_import/working_state.rb
    app/controllers/collections/imports_controller.rb app/controllers/concerns/active_storage_gate.rb
    app/views/collections/import_previews/_apply.html.erb app/views/collections/imports/failed.html.erb
  ].freeze

  it "exists, every file of it", :aggregate_failures do
    FILES.each { |file| expect(Rails.root.join(file)).to exist, file }
  end

  it "never names a collectible type or a source" do
    FILES.each { |file| expect(Rails.root.join(file).read).not_to match(/MTG|Scryfall/), file }
  end

  it "keeps the uploaded file out of the logs" do
    expect(Rails.application.config.filter_parameters).to include(:export_file)
  end
end
```

- [ ] Run — expect PASS (written after the files exist; to see it fail first, run it before Phase 5 with a file missing, then re-run). Commit: `test(028): keep the apply collectible-agnostic`

---

## Phase 11: Measure the bars

**Implements:** decision 3 | **Satisfies:** AC-1.10, AC-6.5 (outside the suite)
**Files:** a throwaway script in the session scratchpad (never committed); results in `docs/specs/028-apply-import/verification.md` (Phase 13)
**Interfaces:** Consumes: Phases 0–7. Produces: the measurements, or the fallback question for the maintainer.

- [ ] Method: reuse spec 025's (`docs/specs/025-import-preview/verification.md`, AC-1.10): a throwaway `bin/rails runner` script inserts one set, 50,000 identities, entries and `mtg_printings`; a verify user; writes the files **(a)** 50,000 resolvable rows; **(b)** the same file with every row changed (quantities +1); **(c)** an empty file with 50,000 held lots. For each: a fresh `bin/dev` server; sign in with curl; preview the file (also record the preview's time and RSS for (a), P3); read `VmRSS`/`VmHWM`; `curl` the apply with the form's `fingerprint`, `confirm_removal=1` for (c); read RSS again. Time the write transaction with a temporary `Rails.logger` subscriber in the runner (start of `BEGIN` to commit) or by running `CollectionImport::Apply#call` in the runner with `ActiveSupport::Notifications` around `decide`'s transaction.
- [ ] Bars: whole request < 30 s, RSS growth < 500 MB, **write transaction < 4 s**; the preview of (a) with the store still < 30 s / 500 MB.
- [ ] If the transaction bar is missed: stop and **ask the maintainer through the coordinator** for the fallback (decision 3). Do not choose one. Likely first levers, for the maintainer to rule on: batching size, deleting working state before the lot deletes, a covering index check.
- [ ] AC-6.5 by hand: export a development instance holding a real catalog, apply it through the pages to a second, empty instance (second worktree), export that, compare with `ExportFormatRules.same_collection?` in a runner, profile name and email apart. Record steps and result.
- [ ] Remove the inserted rows afterwards (as spec 025 did). No commit (results go in Phase 13).

---

## Phase 12: Documents

**Implements:** "Documents that change", decision 10 | **Satisfies:** AC-5.5 (Coverage, done in Phase 0), documents (by reading)
**Files:** `CLAUDE.md`, `README.md`, `docs/roadmap.md`, `docs/adr/0013-active-storage-variants-with-vips.md`, `docs/adr/0022-stored-import-upload-retention.md`, `docs/adr/README.md` (done), `docs/specs/README.md`, `docs/architecture/` area docs if they exist by then, `docs/specs/028-apply-import/spec.md` (only the Plan link, through `sdd-spec-update`)
**Interfaces:** Consumes: the finished feature. Produces: the documents in step with the code.

No test: prose documents are verified by reading (`.claude/rules/testing.md`), recorded in `verification.md`.

- [ ] `CLAUDE.md`: Project Status (applying an import is built: a collector previews and applies an export file; the previewed upload is kept an hour), the "Import preview" fact (it now stores the upload for an applicable file with something to change; add `POST /collection/import`, the 4 s write-transaction bar, the sweep), the "Active Storage variants" fact (the owed validation is met by the stored upload; the routes are gated, ADR 0022).
- [ ] `README.md`: the "Your data" paragraph (import applies; kept for an hour; no undo, export first); the 40 MB request limit stays.
- [ ] `docs/roadmap.md`: Theme A item 5 marked done.
- [ ] ADR 0022: change Status to "Accepted" when the maintainer approves the plan; `docs/adr/0013-active-storage-variants-with-vips.md`: in the consequence about the owed validation, add "met for the import upload by [0022](0022-stored-import-upload-retention.md); pixel limits still owed to the first image upload" (a link, not a rewrite).
- [ ] `docs/specs/README.md`: spec 025's row "Superseded by" cell: "028 decision 10 (the preview now stores an applicable upload)"; spec 028's row: status per the process (Approved → Shipped when merged); do not edit spec 025's own file.
- [ ] Area docs: the data-portability and release-and-deploy docs under `docs/architecture/` if they exist when this merges (spec 027 slice C); otherwise their rows stay "not written yet". The `distill-feature` skill runs at session end and writes them.
- [ ] `docs/specs/028-apply-import/spec.md`: its `Plan:` line → `plan.md` (through `sdd-spec-update`, only that line).
- [ ] Commit: `docs(028): document applying an import`

---

## Phase 13: Verification and review

**Implements:** the completion gate | **Satisfies:** all
**Files:** `docs/specs/028-apply-import/verification.md`
**Interfaces:** Consumes: everything. Produces: `verification.md` with `## Implementation review`.

- [ ] Run `bin/ci` — expect all steps green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec). Run the full suite with the CI seed if a failure appears (memory: reproduce CI with its seed).
- [ ] Write `verification.md`: a row per AC and FR with the spec, example or measurement that holds it (as spec 025's does), the Phase 11 measurements, the screenshots, the by-reading document checks.
- [ ] Run `sdd-superpowers:sdd-review` Mode B; record its verdict on the first line under `## Implementation review` (the heading `distill-feature` reads).
- [ ] Run `sdd-superpowers:session-wrap`, then `distill-feature`.

---

## Risks

1. **The 4 s transaction bar (decision 3).** The read of 50,000 held lots, the comparison, 50,000 deletes with the foreign-key cascade to `bulk_selection_marks`, and the upserts all sit in it. Mitigation: bulk statements; working-state clearing is small; measured in Phase 11. If missed, the maintainer rules the fallback; the plan does not pick one.
2. **Parse and resolve time.** Spec 025 measured the preview at about 10.6 s for 50,000 rows; the apply repeats that work, plus the store, inside the 30 s request bar and kamal-proxy's 30 s default timeout. Measured in Phase 11 (P3).
3. **Gating Active Storage app-wide.** The gate sits in `ActiveStorage::BaseController`; a Rails upgrade that renames its internals (`SetBlob`, signed-id params) breaks it, but the gate's specs (AC-1.12) fail loudly. Records attached to blobs must answer `account_id`; ADR 0022 says so for later uploads. Direct-upload creation is sign-in only, which a future upload feature must tighten.
4. **A purge whose file delete fails** after its row is gone leaves a file the sweep cannot find (it never walks `storage/`, which holds the databases). Rare; logged by Active Storage; noted in ADR 0022.
5. **`Lot.upsert_all` skips validations and callbacks** (FR-3, ruled). AC-2.4's example and the round trip check the rows against `Lot`; a later `Lot` validation needs the apply updated (the round trip fails first).
6. **Memory.** The stored file is read whole, parsed whole (32 MB cap); the upload and the apply each hold the bytes. Inside the 500 MB bar by measurement only.
7. **`ImportUpload.store!` is not atomic with its file.** A crash between the blob and the record leaves a marked blob; the sweep removes it after 10 minutes (P4).
8. **Catalog change between resolving and writing.** A finish a refresh stops listing is accepted (spec error scenario).
9. **Reading beyond the spec (fingerprint).** The fingerprint covers each changed and removed lot's `created_at` at full precision as well as `updated_at`, so that AC-3.7's "either time" holds literally; spec decision 2 names id, quantity and `updated_at`. To be confirmed at plan review; no spec change needed.
10. **Spec 029 (locations)** will touch `Plan`, `Apply#write!` and `lot_attributes`. They are kept as the single places for it.

## Self-Review

- **Spec coverage:** every FR (1–10) and AC (1.1–1.12, 2.1–2.5, 3.1–3.7, 4.1–4.4, 5.1–5.6, 6.1–6.5, 7.1–7.4) appears in the Requirement Map with a phase and a first failing test. AC-1.10 and AC-6.5 are measured outside the suite, by design; AC-7.3, AC-7.4 and the documents are verified by screenshots and reading.
- **Placeholder scan:** none; the two places that depend on what the code shows at implementation (the Active Storage install migration is generated by the framework, and the checkbox classes are chosen from the design system) say exactly what to run or read.
- **Type consistency:** `ImportUpload.store!(account:, bytes:, plan:)`, `CollectionImport#plan/#replan/#entry_id`, `Plan#fingerprint(checksum)`, `Apply.new(account:, fingerprint:, confirmed:).call → Result(outcome, import, plan, upload, fingerprint)`, `WorkingState.clear!(account)` are used identically across phases.
- **Order:** each phase ends green on its own: 0 (tables) → 1 (store) → 2 (sweep) → 3 (gate) → 4 (plan) → 5 (apply) → 6 (preview) → 7 (controller) → 8 (round trip) → 9 (browser) → 10 (core) → 11 (measure) → 12 (docs) → 13 (verification).
- **Independent review:** `sdd-review` Mode A on this plan is recommended before execution (read-only, Opus, per the project's default); not run in this session.
