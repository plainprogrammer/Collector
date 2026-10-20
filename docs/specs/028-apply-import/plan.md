# Implementation Plan: Apply an Import

**Spec:** docs/specs/028-apply-import/spec.md (v1.3.1, Approved)
**Decisions:** docs/adr/0022-stored-import-upload-retention.md (drafted with this plan, revised by [plan-review.md](plan-review.md)); ADR 0013, 0016, 0017, 0020, 0021 apply
**Created:** 2026-10-20 · **Revised:** 2026-10-20 against two independent reviews (spec 1.3.2); see [plan-review.md](plan-review.md)
**Supporting:** [data-model.md](data-model.md), [contracts/api.md](contracts/api.md)

## Global Constraints

Copied from the spec; each applies to every phase.

- Replace semantics of spec 025 decision 1; a file with problem rows, a refused file, or one with nothing to change is never stored and never applied (decisions 1, 4, 12).
- The order of an apply's checks is decision 13's: no upload or expired (422) → stored file unreadable (422) → refused or problem rows (422) → nothing to change (422) → fingerprints not all equal (409) → removal unconfirmed (422).
- Applying is one all-or-nothing write transaction; parse and resolve before it; its bar is **under 4 s for 50,000 rows**; the whole request under 30 s and 500 MB RSS growth (decision 3, AC-1.10).
- The stored upload: one per account, `application/json` by content, at most `CollectionImport::MAX_BYTES` (32 MB), `ImportUpload::EXPIRES_IN` = 1 hour; created analyzed; every removal purges synchronously, outside the write transaction; the sweep (every 15 minutes, `default`, development and production) only calls `purge`, never walks `storage/`; orphan = marked blob, no attachment, older than 10 minutes (decisions 8, 9).
- Active Storage routes stay drawn but gated: sign-in plus ownership of original blobs; direct-upload creation and the disk service's upload PUT answer 404, signed in or not, until a feature needs them (decision 8, spec 1.3.2).
- Every removal of an upload goes through `ImportUpload#remove!`: row and attachment destroyed, then after the commit the blob released inside `begin/rescue` (log the class only); a failure never fails the request and leaves a marked unattached blob for the sweep (decision 9).
- Presence and expiry are checked once early (an optimisation) and once inside the transaction, which is authoritative (decision 13, spec 1.3.2).
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

- **Simplicity (≤3 components):** (1) `ImportUpload` (+ sweep), (2) `CollectionImport` plan/fingerprint + `CollectionImport::Apply`, (3) `Collections::ImportsController` with the preview's changes. The gate concern (Active Storage) is the fourth piece, forced by decision 8; justified in Phase 4's Complexity note.
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
| `app/controllers/concerns/active_storage_gate.rb` + `config/initializers/active_storage_gate.rb` | 404 for uploads, sign-in and ownership of original blobs for Active Storage's routes |
| `app/models/collection_import.rb` (edit) | Entry ids per row, `plan`, `replan`, exact times on `HeldLot` |
| `app/models/collection_import/plan.rb` | What applying does; the fingerprint |
| `app/models/collection_import/apply.rb` | The apply step: checks, transaction, writes, result |
| `app/models/collection_import/working_state.rb` | Clears the lists that point at lots (decision 7) |
| `app/controllers/collections/imports_controller.rb`, `config/routes.rb` | `POST /collection/import` |
| `app/controllers/collections/import_previews_controller.rb` (edit) | Stores the upload |
| `app/views/collections/import_previews/{show,_apply}.html.erb`, `app/views/collections/imports/failed.html.erb` | The pages |
| `app/models/account.rb` (edit) | Associations |
| `spec/support/active_storage.rb` | Empties the test Disk service after the suite |
| `spec/import_apply_core_spec.rb` | FR-8 and FR-6 guards (first example in Phase 0) |
| `.rubocop.yml` (edit) | `DescribeClass` exclusion for the core spec; `ExampleLength` and `MultipleMemoizedHelpers` exclusions for the three scenario specs, with comments |
| `docs/specs/028-apply-import/plan-review.md` | How each finding of the two reviews was resolved |
| `spec/support/import_helpers.rb` | Row/file builders shared by the specs |
| `docs/...` | See Phase 12 |
---

## Requirement Map

Every AC and FR → phase → the first failing test (named in the phase). `P#` = phase.

| Requirement | Phase | First failing test |
|---|---|---|
| FR-1 | 3, 5 | `plan_spec` "lists what applying does"; `apply_spec` "refuses in decision 13's order" |
| FR-2 | 5 | `apply_spec` "decides presence, expiry and fingerprint inside the transaction" |
| FR-3 | 5 | `apply_spec` "writes lots that pass Lot's validations (AC-2.4)" |
| FR-4 | 5 | `apply_spec` "reads and writes in a bounded number of statements" |
| FR-5 | 5, 7 | `apply_spec` AC-4.1; `collection_imports_spec` AC-4.2 |
| FR-6 | 7, 10 | `collection_imports_spec` "sends no-store"; filter-parameter example |
| FR-7 | 6 | `collection_import_previews_spec` AC-5.3 |
| FR-8 | 0, 10 | `import_apply_core_spec` "never names a collectible type or a source" (written in Phase 0) |
| FR-9 | 5 | `apply_spec` AC-1.2 "keeps the changed lot's id" |
| FR-10 | 0 | `import_upload_spec` "allows one per account" |
| AC-1.1 | 6 | `collection_import_previews_spec` "offers the apply form only for an applicable file with something to change" |
| AC-1.2–1.4 | 5 (model), 7 (HTTP 303) | `apply_spec` "replaces exactly (AC-1.2)", "(AC-1.3)", "(AC-1.4)" |
| AC-1.5, 1.7 | 3, 5 | `apply_spec` "previews as nothing to change after an apply (AC-1.5)", "(AC-1.7)" |
| AC-1.6 | 5 | `apply_spec` "the profile" (known, unknown and own view; outcome asserted) |
| AC-1.8 | 5 | `apply_spec` "clears working state only when it writes" |
| AC-1.9 | 5, 7 | `apply_spec` "removes the upload"; request "refuses a second post" |
| AC-1.10 | 5 (transaction spike), 11 | Measured, `verification.md` |
| AC-1.11 | 6 | `collection_import_previews_spec` "writes only the upload, its blob and attachment" |
| AC-1.12 | 4 | `active_storage_gate_spec` (incl. direct uploads 404) |
| AC-2.1 | 5, 7 | `apply_spec` "rolls everything back (AC-2.1)"; request 500 |
| AC-2.2 | 5 | `apply_spec` "refuses a second apply as nothing to change" |
| AC-2.3 | 5, 7, 11 | `apply_spec` "a lost race"; concurrent posts by hand in Phase 11 |
| AC-2.4 | 5 | `apply_spec` "writes lots that pass Lot's validations" |
| AC-2.5 | 5 | `apply_spec` "treats an upload removed after reading as gone" |
| AC-3.1–3.5 | 5, 7 | `apply_spec` per criterion |
| AC-3.6 | 5 | `apply_spec` "gives decision 13's response for combined causes" |
| AC-3.7 | 3 | `plan_spec` "fingerprints" (view change compared) |
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
**Files:** `spec/support/import_helpers.rb`, `spec/support/active_storage.rb`, `spec/import_apply_core_spec.rb`, `.rubocop.yml`, `spec/models/import_upload_spec.rb`, the two migrations, `app/models/import_upload.rb`, `app/models/account.rb`, `db/schema.rb`, `spec/export_format_document_spec.rb`, `docs/export-format/README.md`
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

  # Previews +data+ for +account+ and stores it, as the preview page does; returns the ImportUpload. A file the preview
  # would not store (refused, problem rows, nothing to change) raises, so a spec cannot pass on a state the page never
  # reaches; +forced+ stores it anyway, for a spec that needs a stale upload.
  def store_import!(account:, data:, forced: false)
    bytes = data.is_a?(String) ? data : JSON.generate(data)
    import = CollectionImport.new(account:, file: StringIO.new(bytes))
    raise ArgumentError, "the preview would not store this file" unless forced || (import.applicable? && !import.plan.nothing_to_change?)

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
  has_one_attached :file, dependent: false # removal is ImportUpload#remove!, added in Phase 1 (spec 028 decision 9)
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
- [ ] Clean the test Disk service after the suite (the specs create blobs under `tmp/storage`):

```ruby
# spec/support/active_storage.rb
RSpec.configure do |config|
  config.after(:suite) { FileUtils.rm_rf(ActiveStorage::Blob.service.root) }
end
```

- [ ] Write the first example of the FR-8 core spec, before any of the feature's files exist (Phase 10 shows it and completes the file), and the `.rubocop.yml` changes with their justification:

```yaml
# .rubocop.yml
# (RSpec/DescribeClass, Exclude) add:
    - "spec/import_apply_core_spec.rb"   # checks the files of a feature, like the other core specs

# The apply, plan and round-trip specs are scenarios (a collection, a file, a stored upload, an apply, then the
# collection again); their examples and helpers are longer and more numerous than the integration default.
RSpec/ExampleLength:
  Max: 15
  Exclude:
    - "spec/models/collection_import/apply_spec.rb"
    - "spec/models/collection_import/plan_spec.rb"
    - "spec/models/collection_import/round_trip_spec.rb"
RSpec/MultipleMemoizedHelpers:
  Exclude:
    - "spec/models/collection_import/apply_spec.rb"
    - "spec/models/collection_import/round_trip_spec.rb"
```

  (merge the two `Exclude` lists into the existing `RSpec/ExampleLength` entry; add `MultipleMemoizedHelpers` as a new entry.) Run `bin/rubocop spec/import_apply_core_spec.rb` — expect clean.
- [ ] Commit: `feat(028): install Active Storage and add the import uploads table`
---

## Phase 1: The stored upload

**Implements:** decisions 1, 8, 9 (store, replace, expiry, removal, sweep rule) | **Satisfies:** AC-4.4, AC-5.1, AC-5.2, AC-5.4
**Files:** `app/models/import_upload.rb`, `spec/models/import_upload_spec.rb`
**Interfaces:** Consumes: Phase 0. Produces: `ImportUpload.store!(account:, bytes:, plan:)` → `ImportUpload` (`plan` answers `fingerprint(checksum)`); `#remove!` (the one removal path: destroys the row and its attachment, then after the commit releases the blob, rescuing and logging); `ImportUpload.release(blob)`; `#expired?`; `#checksum`; `#read` → String or nil; `ImportUpload.sweep!`; constants `EXPIRES_IN`, `ORPHAN_GRACE`, `MARKER`.

Every removal goes through `remove!`: `store!` replacing the earlier upload, the sweep, a refused apply, an applied or nothing-to-change apply, and an account's deletion (`Account has_one :import_upload, dependent: :destroy` calls the same destroy callbacks). The attachment is `dependent: false`, so Active Storage never purges inside a callback of its own and a failing delete can never fail the request (maintainer ruling 2026-10-20). `release(blob)` deletes the file first and then the blob row, which differs from `Blob#purge` (it destroys the row before deleting the file, `activestorage-8.1.4/app/models/active_storage/blob.rb:345`): with this order, a failed file delete leaves a marked, unattached blob row that the 10-minute sweep finds, which is the outcome the ruling asks for (plan-review.md, S-M3/O-M1).

Phase 1 specs build their uploads with a stand-in plan (`FakePlan`, in `spec/support/import_helpers.rb`), so this phase is green without Phase 3.

- [ ] Add the stand-in to `spec/support/import_helpers.rb` (inside `ImportHelpers`):

```ruby
  FakePlan = Data.define(:value) { def fingerprint(_checksum) = value }
```

  (a constant inside a support module, not inside an `RSpec.describe`, so `RSpec/LeakyConstantDeclaration` does not apply.)
- [ ] Write the failing specs:

```ruby
# spec/models/import_upload_spec.rb (added to the Phase 0 file)
  let(:account) { create(:user).account }
  let(:plan) { ImportHelpers::FakePlan.new("fp-1") }
  let(:service) { ActiveStorage::Blob.service }

  def store(bytes = '{"a":1}', for_account: account) = described_class.store!(account: for_account, bytes:, plan:)

  describe ".store! (AC-5.1, AC-5.2)" do
    it "keeps the file as application/json, analyzed, expiring after EXPIRES_IN", :aggregate_failures do
      upload = store
      blob = upload.file.blob

      expect(blob.content_type).to eq("application/json")
      expect(blob).to be_analyzed
      expect(blob.metadata).to include("identified" => true, "import_upload" => true)
      expect(blob.filename.to_s).to match(/\Aimport-#{account.id}-\d{8}T\d{6}Z\.json\z/)
      expect(upload.fingerprint).to eq("fp-1")
      expect(upload.expires_at).to be_within(5.seconds).of(described_class::EXPIRES_IN.from_now)
      expect(upload.read).to eq('{"a":1}')
    end

    it "queues no job" do
      expect { store }.not_to have_enqueued_job
    end

    it "replaces the account's earlier upload and releases its file", :aggregate_failures do
      key = store("1").file.blob.key
      second = store("22")

      expect(account.reload.import_upload).to eq(second)
      expect(described_class.count).to eq(1)
      expect(ActiveStorage::Blob.exists?(key:)).to be(false)
      expect(service.exist?(key)).to be(false)
    end
  end

  describe "#expired? and #read" do
    it "is expired at expires_at, and reads nil when the file is gone", :aggregate_failures do
      upload = store
      expect(upload).not_to be_expired
      travel_to(described_class::EXPIRES_IN.from_now + 1.second) { expect(upload).to be_expired }

      service.delete(upload.file.blob.key)
      expect(upload.read).to be_nil
    end
  end

  describe "going with its account (AC-4.4)" do
    it "releases the blob and its file when the user is deleted" do
      user = create(:user)
      key = store(for_account: user.account).file.blob.key

      user.destroy!

      expect([ described_class.count, service.exist?(key) ]).to eq([ 0, false ])
    end
  end

  describe "a file that can't be deleted (decision 9, maintainer ruling 2026-10-20)" do
    it "still removes the row, leaves a marked unattached blob, and the sweep clears it later", :aggregate_failures do
      blob = store.file.blob
      allow(service).to receive(:delete).and_raise(Errno::EIO)

      expect { account.reload.import_upload.remove! }.not_to raise_error
      expect(described_class.count).to eq(0)
      expect(ActiveStorage::Blob.find(blob.id).attachments).to be_empty

      allow(service).to receive(:delete).and_call_original
      travel_to(described_class::ORPHAN_GRACE.from_now + 1.minute) { described_class.sweep! }
      expect([ ActiveStorage::Blob.exists?(blob.id), service.exist?(blob.key) ]).to eq([ false, false ])
    end

    it "logs the class only, never the file", :aggregate_failures do
      store
      allow(service).to receive(:delete).and_raise(Errno::EIO)
      allow(Rails.logger).to receive(:error)

      account.reload.import_upload.remove!

      expect(Rails.logger).to have_received(:error).with(a_string_including("Errno::EIO")).at_least(:once)
    end
  end

  describe ".sweep! (AC-5.4)" do
    def blob(created_at: Time.current, marked: true)
      metadata = { "identified" => true, "analyzed" => true }.merge(marked ? { described_class::MARKER => true } : {})
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("{}"), filename: "x.json", content_type: "application/json",
        identify: false, metadata:).tap { |created| created.update_columns(created_at:) }
    end

    it "purges expired uploads and old orphans only, and is idempotent", :aggregate_failures do
      expired = store(for_account: create(:user).account).tap { |upload| upload.update!(expires_at: 1.minute.ago) }
      fresh = store(for_account: create(:user).account)
      old_orphan = blob(created_at: 11.minutes.ago)
      kept = [ blob(created_at: 1.minute.ago), blob(created_at: 1.day.ago, marked: false), fresh.file.blob ]
      expired_key = expired.file.blob.key

      2.times { described_class.sweep! }

      expect(described_class.all).to contain_exactly(fresh)
      expect(service.exist?(expired_key)).to be(false)
      expect(ActiveStorage::Blob.exists?(old_orphan.id)).to be(false)
      expect(ActiveStorage::Blob.where(id: kept.map(&:id)).count).to eq(3)
    end

    it "keeps sweeping past an item that fails", :aggregate_failures do
      first = blob(created_at: 20.minutes.ago)
      second = blob(created_at: 20.minutes.ago)
      allow(service).to receive(:delete).and_wrap_original do |original, key|
        key == first.key ? raise(Errno::EIO) : original.call(key)
      end

      expect { described_class.sweep! }.not_to raise_error
      expect(ActiveStorage::Blob.exists?(second.id)).to be(false)
      expect(ActiveStorage::Blob.exists?(first.id)).to be(true) # retried by the next run
    end
  end
```

- [ ] Run `bin/rspec spec/models/import_upload_spec.rb` — expect FAIL (`undefined method store!`).
- [ ] Implement:

```ruby
# app/models/import_upload.rb
# The account's previewed export file, kept briefly so that it can be applied (spec 028 decisions 1, 9; ADR 0022).
class ImportUpload < ApplicationRecord
  EXPIRES_IN = 1.hour
  ORPHAN_GRACE = 10.minutes
  MARKER = "import_upload".freeze

  belongs_to :account
  # No dependent purge: the one removal path below releases the blob after the commit, rescuing every failure.
  has_one_attached :file, dependent: false

  scope :expired, -> { where(expires_at: ..Time.current) }

  before_destroy :remember_blob, prepend: true
  after_destroy_commit :release_blob

  # Keeps +bytes+, replacing the account's earlier upload (decision 1). The blob is made first, outside any transaction
  # (file I/O), already identified and analyzed so Active Storage queues no job (decision 8); a failure after it releases it.
  def self.store!(account:, bytes:, plan:)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes),
      filename: "import-#{account.id}-#{Time.current.utc.strftime("%Y%m%dT%H%M%SZ")}.json",
      content_type: "application/json", identify: false,
      metadata: { "identified" => true, "analyzed" => true, MARKER => true })
    transaction do
      find_by(account_id: account.id)&.remove!
      create!(account:, fingerprint: plan.fingerprint(blob.checksum), expires_at: EXPIRES_IN.from_now, file: blob)
    end
  rescue StandardError
    release(blob) if blob
    raise
  end

  # Deletes the file first, then the blob row, so that a failure leaves a marked, unattached blob for the sweep (the
  # order Blob#purge does not have). Never raises: a removal that fails must not fail the request (decision 9).
  def self.release(blob)
    blob.delete
    blob.destroy
  rescue StandardError => error
    Rails.logger.error("An import upload's blob was not released: #{error.class}")
  end

  # Removes every expired upload, and every marked blob that no attachment holds and that is older than the grace
  # (a preview that crashed between its blob and its record, or a release that failed). Cross-tenant by nature: it runs
  # for the instance. It never lists or deletes paths on disk, and goes on past an item that fails (decision 9).
  def self.sweep!
    expired.find_each { |upload| sweeping { upload.remove! } }
    ActiveStorage::Blob.where.missing(:attachments).where(created_at: ..ORPHAN_GRACE.ago)
      .where("json_extract(active_storage_blobs.metadata, '$.import_upload') = 1").find_each { |blob| release(blob) }
  end

  def self.sweeping
    yield
  rescue StandardError => error
    Rails.logger.error("An import upload was not swept: #{error.class}")
  end

  # The one removal path (store! replacing, the sweep, applying, refusing); an account's deletion reaches the same
  # callbacks through dependent: :destroy.
  def remove! = destroy!

  def expired? = expires_at <= Time.current

  def checksum = file.blob.checksum

  # The stored file's bytes, or nil when it can't be read (removed by the sweep, a newer preview or a fault).
  def read
    file.download
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  private
    def remember_blob = @blob_to_release = (file.blob if file.attached?)

    def release_blob = (self.class.release(@blob_to_release) if @blob_to_release)
end
```

- [ ] Run the spec — expect PASS. If `find_by` inside `store!`'s transaction conflicts with the unique index, the earlier row is removed first in the same transaction, so it cannot.
- [ ] Run `bin/rubocop app/models/import_upload.rb spec/models/import_upload_spec.rb spec/support/import_helpers.rb` — expect clean (the spec's examples stay within `ExampleLength` 15 or are covered by the `.rubocop.yml` change of Phase 0).
- [ ] Commit: `feat(028): store, expire, release and sweep a previewed upload`
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
# spec/config/recurring_spec.rb: extend the existing file (it already checks refresh_mtg_catalog, tagged `type: :config`
# with its justified DescribeClass disable); add inside its describe:
  %w[development production].each do |environment|
    it "schedules the import upload sweep every 15 minutes in #{environment} (spec 028 AC-5.5)" do
      task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).dig(environment, "sweep_import_uploads")

      expect(task).to include("class" => "ImportUpload::SweepJob", "queue" => "default", "schedule" => "every 15 minutes")
    end
  end
```

- [ ] Run `bin/rspec spec/jobs/import_upload spec/config/recurring_spec.rb` — expect FAIL.
- [ ] Implement:

```ruby
# app/jobs/import_upload/sweep_job.rb
# Removes expired stored uploads and orphaned upload blobs (spec 028 decision 9). Idempotent; queued every 15 minutes
# by config/recurring.yml. It has no retry_on: a run that fails is followed by the next one, and the sweep rescues and
# logs per item, so one failing item never stops the others.
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

- [ ] The `development:` block carries the sweep only. `clear_solid_queue_finished_jobs` stays production-only: finished sweep jobs pile up in a development queue database at 96 a day, which is accepted (plan-review.md, S-m8) rather than widening this feature.
- [ ] Run the specs — expect PASS. Run `bin/rails runner 'puts SolidQueue::Configuration.new.send(:recurring_tasks).map(&:key)'` in development — expect `sweep_import_uploads`.
- [ ] Commit: `feat(028): sweep expired import uploads every 15 minutes`
---

## Phase 3: The plan and its fingerprint

**Implements:** FR-1 (plan and fingerprint from the reader), decision 2, decision 12 (`nothing_to_change?`) | **Satisfies:** AC-3.7, AC-1.5 (preview side), AC-1.7 (preview side)
**Files:** `app/models/collection_import.rb`, `app/models/collection_import/plan.rb`, `spec/models/collection_import/plan_spec.rb`, `spec/support/import_helpers.rb`
**Interfaces:** Consumes: the existing `outcomes`. Produces: `CollectionImport#plan` (memoized), `#replan` (re-reads the account's lots and the user, no re-parse, and becomes the import's plan and outcomes, so the pages show what the transaction decided), `#entry_id(row)`, `CollectionImport::Plan` with `added_rows`, `changed_rows` (rows), `held_for(row)` (HeldLot), `removed_lots` (all, HeldLot), `view_change`, `nothing_to_change?`, `removes?`, `counts` → `{ added:, changed:, removed: }` lots, `fingerprint(file_checksum)` → hex String; `HeldLot#created_exact`, `#updated_exact` (ISO 8601, 6 fractional digits).

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
    def view_profile(view) = { "name" => user.name, "email_address" => user.email_address, "collection_view" => view }

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
      same = import([ import_row(a, quantity: 5) ], profile: view_profile("grid")).plan.fingerprint("sum")
      changing = import([ import_row(a, quantity: 5) ], profile: view_profile("table")).plan.fingerprint("sum")
      expect(changing).not_to eq(same) # the view change
    end
  end

  it "re-reads the collection on replan without parsing again, and becomes the import's plan", :aggregate_failures do
    held_lot(account, a, quantity: 3)
    parsed = import([ import_row(a, quantity: 3) ])
    expect(parsed.plan.nothing_to_change?).to be(true) # as the preview saw it

    account.lots.update_all(quantity: 4)
    expect(parsed.plan.nothing_to_change?).to be(true) # memoized

    expect(parsed.replan.changed_rows.size).to eq(1)
    expect(parsed.plan.changed_rows.size).to eq(1)
    expect(parsed.changed.lots).to eq(1) # the page's counts follow the new plan
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

  # The same, against the collection as it is now: one read of the lots and of the user, no parsing (spec 028 FR-2). It
  # replaces the memoized plan and outcomes, so that the page an apply renders afterwards shows what the apply decided.
  def replan
    user.reload
    @removed_lots = nil
    @outcomes = outcomes_for(held_lots)
    @plan = Plan.new(@outcomes, view_change)
  end
```

  In `entry_problems` (called with `index`) record the entry: in `resolution_problems`' inner loop add `@entry_ids[index + 1] = entries[lot["entry"]["source_id"]]&.id` before `entry_problems`. In `held_lots`, pluck the extra values and pass `created_exact: created.getutc.iso8601(6), updated_exact: changed.getutc.iso8601(6)`. Split `outcomes`:

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

## Phase 4: Gate Active Storage's routes

**Implements:** decision 8 (routes gated, app-wide; direct uploads answer 404) | **Satisfies:** AC-1.12
**Files:** `app/controllers/concerns/active_storage_gate.rb`, `config/initializers/active_storage_gate.rb`, `spec/requests/active_storage_gate_spec.rb`
**Interfaces:** Consumes: `Authentication` (sign-in), `store_import!` (Phase 0 helper, which needs Phase 3's `CollectionImport#plan`; this is why the gate follows the plan). Produces: `ActiveStorageGate`, included in `ActiveStorage::BaseController`: direct-upload creation and the disk service's upload `PUT` answer 404 (signed in or not); every other action needs a sign-in; every action that reads a blob needs an original blob that a record of the signed-in account holds.

Complexity note (fourth component): the gate exists because Active Storage's routes are public and decision 8 rules them gated app-wide. It is the framework's documented "Authenticated Controllers" pattern, not a wrapper. It authorises **original blobs only**: variant records and preview images hang off other records without an `account_id`, so they are served to no one until the first image feature extends ownership to them (ADR 0022, maintainer ruling 2026-10-20). Nothing of variants is implemented here.

- [ ] Write the failing spec:

```ruby
# spec/requests/active_storage_gate_spec.rb
require "rails_helper"

# Spec 028 AC-1.12: Active Storage's routes need a sign-in and an owner; uploads through them are closed.
RSpec.describe "Active Storage gate", type: :request do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let!(:upload) { store_import!(account: owner.account, data: import_file(owner, [ import_row(import_printing) ])) }
  let(:blob) { upload.file.blob }

  def disk_path
    token = ActiveStorage.verifier.generate({ key: blob.key, content_type: blob.content_type, disposition: "attachment",
      service_name: blob.service_name }, expires_in: 5.minutes, purpose: :blob_key)
    rails_disk_service_path(token, filename: blob.filename)
  end

  it "sends a signed-out visitor to sign in and returns no content", :aggregate_failures do
    get rails_blob_path(blob)

    expect(response).to redirect_to(new_session_path)
    expect(response.body).not_to include("collector-export")
  end

  it "returns 404 to another account's collector, for the blob and for the disk URL", :aggregate_failures do
    sign_in_as(other)
    [ rails_blob_path(blob), disk_path ].each do |path|
      get path
      expect(response).to have_http_status(:not_found)
    end
  end

  it "serves the file to its owner, through the redirect to the disk service", :aggregate_failures do
    sign_in_as(owner)
    get rails_blob_path(blob)
    expect(response).to have_http_status(:redirect)
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("collector-export")
  end

  it "returns 404 for a blob no record holds" do
    orphan = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    sign_in_as(owner)

    get rails_blob_path(orphan)

    expect(response).to have_http_status(:not_found)
  end

  describe "direct uploads and the disk service's upload (decision 8, ruled 2026-10-20)" do
    let(:declared) { { blob: { filename: "a.png", byte_size: 1, checksum: "x", content_type: "image/png" } } }

    it "answer 404 signed out and signed in, and create no blob", :aggregate_failures do
      before = ActiveStorage::Blob.count
      2.times do
        post rails_direct_uploads_path, params: declared, as: :json
        expect(response).to have_http_status(:not_found)
        put update_rails_disk_service_path("anything"), params: "bytes"
        expect(response).to have_http_status(:not_found)
        sign_in_as(owner)
      end
      expect(ActiveStorage::Blob.count).to eq(before)
    end
  end

  it "never puts a blob URL, key or signed id in the preview page", :aggregate_failures do
    sign_in_as(owner)
    post collection_import_preview_path, params: { export_file: import_upload_file(import_file(owner, [ import_row(import_printing, quantity: 2) ])) }
    kept = owner.account.reload.import_upload.file.blob

    expect(response.body).not_to include("active_storage", kept.key, kept.signed_id)
  end
end
```

  (the last example passes trivially until Phase 6 renders the apply form and stays as a guard.)
- [ ] Run `bin/rspec spec/requests/active_storage_gate_spec.rb` — expect FAIL (the signed-out and other-account examples get 302 to the blob / 200; the direct-upload example gets 302 or an error).
- [ ] Implement:

```ruby
# app/controllers/concerns/active_storage_gate.rb
# Active Storage's routes are public by default. They are gated app-wide (spec 028 decision 8, ADR 0022):
# - direct-upload creation and the disk service's upload PUT answer 404 until a feature needs them (that feature defines
#   its owner rule, quota and clean-up);
# - every other action needs a sign-in;
# - every action that reads a blob needs an original blob that a record of the signed-in account holds. Variant records and
#   preview images are not authorised yet: the first image feature extends ownership to them (ADR 0022).
module ActiveStorageGate
  extend ActiveSupport::Concern

  included do
    before_action :refuse_uploads, prepend: true
    include Authentication
    before_action :require_blob_owner
  end

  private
    def refuse_uploads
      head :not_found if (controller_name == "direct_uploads" && action_name == "create") || (controller_name == "disk" && action_name == "update")
    end

    def require_blob_owner
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

- [ ] Run the spec — expect PASS. Run `bin/rails zeitwerk:check` and `bin/brakeman -q` — expect no new warning (the `where("json_extract…")` in Phase 1 is a constant string; the gate has no dynamic SQL).
- [ ] Commit: `feat(028): gate Active Storage's routes and close its uploads`
---

## Phase 5: The apply step, and the transaction spike

**Implements:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-9, decisions 2–5, 7, 12, 13 | **Satisfies:** AC-1.2 to AC-1.9, AC-2.1 to AC-2.5, AC-3.1 to AC-3.6, AC-4.1, AC-5.6; the first measurement of AC-1.10's transaction bar
**Files:** `app/models/collection_import/apply.rb`, `app/models/collection_import/working_state.rb`, `spec/models/collection_import/apply_spec.rb`
**Interfaces:** Consumes: `CollectionImport#applicable?`, `#plan`, `#replan`, `#entry_id`, `Plan`, `ImportUpload#read/#checksum/#expired?/#remove!`, `Lot.key_for`. Produces: `CollectionImport::Apply.new(account:, fingerprint:, confirmed:).call` → `Result` (`Data.define(:outcome, :import, :plan, :upload, :fingerprint)`) with `outcome` one of `:applied, :missing, :expired, :unreadable, :refused, :nothing_to_change, :stale, :unconfirmed`; for `:stale` and `:unconfirmed`, `result.upload` is the stored upload carrying the **new** fingerprint, and `result.fingerprint` equals `result.upload.fingerprint`; `CollectionImport::WorkingState.clear!(account)`.

Two checks of presence and expiry, on purpose (maintainer ruling 2026-10-20, spec 1.3.2 decision 13): the one before the stored file is read avoids reading 32 MB for an upload that is gone or expired and gives the same answer; the one inside the transaction is authoritative, and AC-5.6 tests the inside one.

All Ruby work that is not a write happens before the transaction: reading and parsing, resolving, and building every attribute hash of the upsert (time parsing, price, lot key). Inside the transaction there are the re-check, one read of the account's lots and the user (`replan`), the fingerprint comparison, and the statements (maintainer ruling 5).

- [ ] Write the failing spec (each example cites its criterion; `ExampleLength` and `MultipleMemoizedHelpers` are excluded for this file in `.rubocop.yml` by Phase 0, because each example is a scenario of collection, file and upload):

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
  let(:service) { ActiveStorage::Blob.service }

  def preview!(lots, **fields) = store_import!(account:, data: import_file(user, lots, **fields))

  def apply(upload = account.reload.import_upload, confirmed: true, fingerprint: upload&.fingerprint, for_account: account)
    described_class.new(account: for_account.reload, fingerprint:, confirmed:).call
  end

  def lots_state = account.lots.order(:id).map(&:attributes)

  # Every table's rows, except the upload's own (a refusal may keep or remove it).
  def snapshot
    connection = ActiveRecord::Base.connection
    skipped = %w[schema_migrations ar_internal_metadata active_storage_blobs active_storage_attachments import_uploads]
    (connection.tables - skipped).sort.to_h do |table|
      [ table, connection.select_rows("SELECT * FROM #{connection.quote_table_name(table)} ORDER BY 1") ]
    end
  end

  def working_state_for(lot)
    NumberEntry.create!(account:).lines.create!(account:, entry: lot.entry, lot:, quantity: 1, finish: nil, line_key: SecureRandom.hex(16))
    Scanner::Sitting.create!(account:).entries.create!(account:, printing: lot.entry, lot:, finish: nil, reading_key: SecureRandom.hex(16))
    session = user.sessions.create!
    BulkSelection.for(session).marks.create!(account:, lot:)
    BulkRemoval.create!(session:, account:, copies: 1, lots_data: [ { "catalog_entry_id" => lot.catalog_entry_id, "quantity" => 1 } ])
  end

  describe "replacing the collection (AC-1.2 to AC-1.4, FR-9)" do
    it "makes the collection hold exactly the file's lots, keeping the changed lot's id", :aggregate_failures do
      held_a = held_lot(account, a, quantity: 3)
      held_b = held_lot(account, b, quantity: 2)
      held_c = held_lot(account, c, quantity: 4)
      held_lot(account, d, quantity: 7)
      preview!([ import_row(a, quantity: 3), import_row(b, quantity: 5, changed_at: "2026-10-02T10:00:00Z"), import_row(c, quantity: 4),
                 import_row(e, quantity: 6, finish: "foil", condition: "near_mint", price_paid: "12.50",
                   added_at: "2026-09-01T00:00:00Z", changed_at: "2026-09-02T00:00:00Z") ])
      untouched = [ held_a, held_c ].map { |lot| lot.reload.attributes }

      expect(apply.outcome).to eq(:applied)

      expect(account.lots.count).to eq(4)
      expect([ held_a, held_c ].map { |lot| lot.reload.attributes }).to eq(untouched)
      expect(held_b.reload).to have_attributes(quantity: 5, updated_at: Time.iso8601("2026-10-02T10:00:00Z"))
      expect(account.lots.find_by!(catalog_entry_id: e.id)).to have_attributes(quantity: 6, finish: "foil", condition: "near_mint",
        price_paid_cents: 1250, created_at: Time.iso8601("2026-09-01T00:00:00Z"), updated_at: Time.iso8601("2026-09-02T00:00:00Z"))
      expect(account.lots.where(catalog_entry_id: d.id)).to be_empty
    end

    it "fills an empty account (AC-1.3)", :aggregate_failures do
      preview!([ import_row(a), import_row(b, finish: "foil"), import_row(c, quantity: 9) ])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.count).to eq(3)
    end

    it "empties an account for a file with no lots (AC-1.4)", :aggregate_failures do
      held_lot(account, a, quantity: 1)
      held_lot(account, b, quantity: 2)
      preview!([])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.count).to eq(0)
    end
  end

  describe "afterwards (AC-1.5, AC-1.7, AC-1.9)" do
    it "previews as nothing to change, and no lot is written again", :aggregate_failures do
      held_lot(account, d, quantity: 7)
      preview!([ import_row(a, quantity: 2), import_row(b) ])
      apply
      state = lots_state

      again = CollectionImport.new(account:, file: import_io(import_file(user, [ import_row(a, quantity: 2), import_row(b) ])))

      expect(again.plan.nothing_to_change?).to be(true)
      expect(lots_state).to eq(state)
    end

    it "does not write a lot with fractional times that a row matches, while writing the others (AC-1.7)", :aggregate_failures do
      fractional = held_lot(account, a, quantity: 3)
      fractional.update_columns(created_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.25, updated_at: Time.iso8601("2026-10-01T10:00:00Z") + 0.75)
      before = fractional.reload.attributes
      preview!([ import_row(a, quantity: 3), import_row(b) ])

      apply

      expect(fractional.reload.attributes).to eq(before)
      expect(account.lots.count).to eq(2)
    end

    it "removes the upload, its blob and its file, and queues no job; a second apply finds nothing (AC-1.9)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      key = upload.file.blob.key
      first = upload.fingerprint

      expect { apply(upload) }.not_to have_enqueued_job
      expect([ ImportUpload.count, service.exist?(key) ]).to eq([ 0, false ])
      expect(apply(nil, fingerprint: first).outcome).to eq(:missing)
    end

    it "still applies when the file can't be deleted afterwards, leaving a marked orphan for the sweep", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      blob = upload.file.blob
      allow(service).to receive(:delete).and_raise(Errno::EIO)

      expect(apply(upload).outcome).to eq(:applied)
      expect(account.lots.count).to eq(1)
      expect(ActiveStorage::Blob.find(blob.id).attachments).to be_empty
    end
  end

  describe "the profile (AC-1.6)" do
    def profile(view) = { "name" => "Other Name", "email_address" => "other@example.test", "collection_view" => view }

    it "sets a known view with a lot change, and never the name or email address", :aggregate_failures do
      preview!([ import_row(a) ], profile: profile("table"))

      expect(apply.outcome).to eq(:applied)
      expect(user.reload).to have_attributes(collection_view: "table", name: "Grace", email_address: "grace@example.test")
    end

    it "leaves the view alone for one the instance doesn't know, and for the collector's own", :aggregate_failures do
      preview!([ import_row(a) ], profile: profile("gallery"))
      expect(apply.outcome).to eq(:applied)
      expect(user.reload.collection_view).to eq("grid")

      other = create(:user)
      store_import!(account: other.account, data: import_file(other, [ import_row(b) ], profile: profile("grid")))
      expect(apply(for_account: other.account, upload: other.account.import_upload, fingerprint: other.account.import_upload.fingerprint).outcome).to eq(:applied)
      expect(other.reload.collection_view).to eq("grid")
    end
  end

  describe "working state (decision 7, AC-1.8)" do
    it "clears the lists that point at lots when the apply writes", :aggregate_failures do
      removal = working_state_for(held_lot(account, d, quantity: 3))
      preview!([ import_row(a) ])

      apply

      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count + BulkSelection::Mark.count).to eq(0)
      expect(NumberEntry::Line.count + Scanner::SittingEntry.count).to eq(0)
      expect(removal.reload).not_to be_undoable
    end

    it "clears nothing when the apply is refused as stale, unconfirmed or nothing to change", :aggregate_failures do
      lot = held_lot(account, a, quantity: 3)
      working_state_for(held_lot(account, d, quantity: 1))
      stale = preview!([ import_row(a, quantity: 4) ])
      lot.update_columns(quantity: 9)
      before = snapshot
      expect(apply(stale).outcome).to eq(:stale)
      expect(snapshot).to eq(before)

      unconfirmed = preview!([ import_row(a, quantity: 9) ]) # removes lot d, so needs the confirmation
      expect(apply(unconfirmed, confirmed: false).outcome).to eq(:unconfirmed)
      expect(snapshot).to eq(before)

      empty = preview!([ import_row(a, quantity: 2) ])
      lot.update_columns(quantity: 2)
      account.lots.where.not(id: lot.id).delete_all
      expect(apply(empty).outcome).to eq(:nothing_to_change)
      expect(NumberEntry.count).to eq(1)
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

    it "refuses a second apply of a file already applied as nothing to change, changing nothing", :aggregate_failures do
      upload = preview!([ import_row(a, quantity: 2) ])
      first = upload.fingerprint
      apply(upload)
      state = lots_state
      store_import!(account:, data: import_file(user, [ import_row(a, quantity: 2) ]), forced: true).update_columns(fingerprint: first) # kept by the spec
      before = snapshot

      result = apply(account.reload.import_upload, fingerprint: first)

      expect(result.outcome).to eq(:nothing_to_change)
      expect(lots_state).to eq(state)
      expect(snapshot).to eq(before)
    end
  end

  describe "a lost race (AC-2.3, AC-2.5, AC-5.6)" do
    def remove_after_reading(upload)
      allow(CollectionImport).to receive(:new).and_wrap_original do |original, **args|
        original.call(**args).tap { yield upload }
      end
    end

    it "answers :missing when the upload was removed after it was read, writing nothing", :aggregate_failures do
      held_lot(account, d, quantity: 3)
      upload = preview!([ import_row(a) ])
      before = lots_state
      remove_after_reading(upload) { |stored| ImportUpload.where(id: stored.id).delete_all }

      expect(apply(upload).outcome).to eq(:missing)
      expect(lots_state).to eq(before)
    end

    it "judges expiry inside the transaction, whatever the sweep's timing (AC-5.6)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      remove_after_reading(upload) { |stored| stored.update_columns(expires_at: 1.minute.ago) }

      expect(apply(upload).outcome).to eq(:expired)
      expect(account.lots).to be_empty
    end

    it "answers :unreadable for a stored file that is gone", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      service.delete(upload.file.blob.key)

      expect(apply(upload).outcome).to eq(:unreadable)
      expect(account.lots).to be_empty
    end
  end

  describe "valid lots (AC-2.4, FR-3)" do
    it "writes lots that Lot would accept, with the key Lot gives and the identity of their row", :aggregate_failures do
      rows = [ import_row(a, quantity: 9_999, finish: "foil", condition: "near_mint", price_paid: "0.05"), import_row(b, finish: nil) ]
      preview!(rows)
      apply

      account.lots.each do |lot|
        expect(lot).to be_valid
        expect(lot.lot_key).to eq(Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents))
      end
      identities = CollectionImport.new(account:, file: import_io(import_file(user, rows))).rows.map(&:identity)
      held = CollectionImport.new(account:, file: import_io(import_file(user, rows))).send(:held_lots).map(&:identity)
      expect(held).to match_array(identities)
    end
  end

  describe "bounded statements (FR-4)" do
    def statements_for(size)
      other = create(:user)
      entries = Array.new(size) { import_printing }
      upload = store_import!(account: other.account, data: import_file(other, entries.map { |entry| import_row(entry) }))
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\ASAVEPOINT|\ARELEASE/) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { apply(upload, for_account: other.account) }
      queries
    end

    it "runs as many statements for 30 rows as for 2 within one batch, and one more per batch past it", :aggregate_failures do
      stub_const("CollectionImport::BATCH_SIZE", 10)
      small = statements_for(2)

      expect(statements_for(9)).to eq(small)
      expect(statements_for(25)).to eq(small + 2) # two more upserts
    end
  end

  describe "what was previewed is what is applied (AC-3.1 to AC-3.6)" do
    it "refuses a changed collection as stale, with the new fingerprint stored and returned (AC-3.1)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      upload = preview!([ import_row(a, quantity: 5) ])
      old = upload.fingerprint
      lot.update!(quantity: 3)
      before = lots_state

      result = apply(upload)

      expect(result.outcome).to eq(:stale)
      expect(lots_state).to eq(before)
      expect(result.fingerprint).not_to eq(old)
      expect(result.upload.fingerprint).to eq(result.fingerprint)
      expect(upload.reload.fingerprint).to eq(result.fingerprint)
    end

    it "refuses a form from a replaced upload as stale (AC-3.2)", :aggregate_failures do
      old = preview!([ import_row(a) ]).fingerprint
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
      Catalog::Entry.where(id: a.id).update_columns(external_key: "moved")
      key = upload.file.blob.key

      expect(apply(upload).outcome).to eq(:refused)
      expect([ ImportUpload.count, service.exist?(key) ]).to eq([ 0, false ])
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
      stored = other.account.import_upload
      expect(apply(stored, confirmed: false, for_account: other.account).outcome).to eq(:applied)
    end

    it "gives decision 13's response for combined causes (AC-3.6)", :aggregate_failures do
      lot = held_lot(account, d, quantity: 1)
      upload = preview!([ import_row(a) ])
      lot.update_columns(quantity: 2)
      expect(apply(upload, confirmed: false).outcome).to eq(:stale) # stale and unconfirmed: the 409

      other = create(:user)
      held = held_lot(other.account, a, quantity: 1)
      stored = store_import!(account: other.account, data: import_file(other, [ import_row(a, quantity: 2) ]))
      held.update_columns(quantity: 2) # the file's change was made some other way
      expect(apply(stored, for_account: other.account).outcome).to eq(:nothing_to_change)

      refused = create(:user)
      kept = store_import!(account: refused.account, data: import_file(refused, [ import_row(c) ]))
      Catalog::Entry.where(id: c.id).update_columns(external_key: "gone")
      held_lot(refused.account, import_printing, quantity: 1) # also makes the plan stale
      expect(apply(kept, for_account: refused.account).outcome).to eq(:refused)
    end
  end

  describe "only this account (AC-4.1)" do
    it "leaves every other account's rows as they were", :aggregate_failures do
      stranger = create(:user)
      held_lot(stranger.account, a, quantity: 5)
      store_import!(account: stranger.account, data: import_file(stranger, [ import_row(b) ]))
      working_state_for(held_lot(account, c, quantity: 1))
      upload = preview!([ import_row(a, quantity: 9) ])
      theirs = [ stranger.account.lots.map(&:attributes), stranger.account.import_upload.attributes, stranger.attributes, stranger.sessions.map(&:attributes) ]

      apply(upload)

      expect([ stranger.account.lots.reload.map(&:attributes), stranger.account.reload.import_upload.attributes, stranger.reload.attributes,
               stranger.sessions.reload.map(&:attributes) ]).to eq(theirs)
    end
  end
end
```

- [ ] Run `bin/rspec spec/models/collection_import/apply_spec.rb` — expect FAIL (`uninitialized constant CollectionImport::Apply`).
- [ ] Implement:

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
# Applies the account's stored upload (spec 028): reads, judges and prepares everything outside any transaction, then
# decides and writes inside one short all-or-nothing transaction. It touches +account+ only. Collectible-agnostic.
class CollectionImport::Apply
  Result = Data.define(:outcome, :import, :plan, :upload, :fingerprint)

  def initialize(account:, fingerprint:, confirmed:)
    @account = account
    @fingerprint = fingerprint.to_s
    @confirmed = confirmed
  end

  # Decision 13's order. The checks before the transaction are an optimisation that gives the same answer; the
  # transaction decides presence, expiry and the fingerprints once more and its answer is the authoritative one (FR-2).
  def call
    upload = ImportUpload.find_by(account_id: @account.id)
    return result(:missing) unless upload
    return result(:expired, upload:) if upload.expired?

    bytes = upload.read
    return result(:unreadable, upload:) unless bytes

    import = CollectionImport.new(account: @account, file: StringIO.new(bytes))
    return refuse(upload, import) unless import.applicable?

    decide(upload, import, rows_to_write(import))
  end

  private
    def decide(upload, import, rows)
      ImportUpload.transaction do
        current = ImportUpload.find_by(account_id: @account.id)
        next result(:missing) unless current&.id == upload.id
        next result(:expired, upload: current) if current.expired?

        plan = import.replan
        next remove(current, result(:nothing_to_change, import:, plan:)) if plan.nothing_to_change?

        now = plan.fingerprint(current.checksum)
        next stale(current, import, plan, now) unless @fingerprint == now && current.fingerprint == now
        next result(:unconfirmed, import:, plan:, upload: current, fingerprint: now) if plan.removes? && !@confirmed

        write!(plan, rows)
        remove(current, result(:applied, import:, plan:))
      end
    end

    # The stored plan changed: keep the upload with the fingerprint of the plan the collector is about to be shown.
    def stale(current, import, plan, now)
      current.update!(fingerprint: now)
      result(:stale, import:, plan:, upload: current, fingerprint: now)
    end

    # The file is destroyed row first; its blob is released after the commit, rescuing every failure (ImportUpload).
    def remove(upload, result)
      upload.remove!
      result
    end

    def refuse(upload, import)
      upload.remove!
      result(:refused, import:, upload:)
    end

    def result(outcome, import: nil, plan: nil, upload: nil, fingerprint: nil) = Result.new(outcome:, import:, plan:, upload:, fingerprint:)

    # Every attribute hash of the upsert, by row number, built before the lock (time parsing, price, lot key).
    def rows_to_write(import)
      import.rows.reject(&:problem?).to_h { |row| [ row.number, lot_attributes(row, import) ] }
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

    # One statement per BATCH_SIZE lots, never one per lot (FR-4). The upsert is on the lot's identity, so a changed
    # lot keeps its id (FR-9); the rows were validated by the reader. The bulk statements skip Lot's callbacks and
    # validations on purpose (spec 028 FR-3, ruled 2026-10-20; AC-2.4 checks the rows against Lot).
    def write!(plan, rows)
      plan.removed_lots.map(&:id).each_slice(CollectionImport::BATCH_SIZE) { |ids| @account.lots.where(id: ids).delete_all }
      (plan.added_rows + plan.changed_rows).each_slice(CollectionImport::BATCH_SIZE) do |slice|
        Lot.upsert_all(slice.map { |row| rows.fetch(row.number) }, unique_by: %i[account_id catalog_entry_id lot_key],
          update_only: %i[quantity created_at updated_at], record_timestamps: false, returning: false)
      end
      CollectionImport::WorkingState.clear!(@account)
      @account.user.update!(collection_view: plan.view_change) if plan.view_change
    end
end
```

- [ ] Run the spec — expect PASS. Allowed adjustments inside this phase: the `Time.iso8601` rows are built for every non-problem row (50,000 hashes, held in memory until the transaction ends); if `returning: false` is refused with `update_only` on this Rails, drop it and keep the rest.
- [ ] Run `bin/rspec spec/models` — expect PASS; `bin/rubocop -a app/models spec/models`.
- [ ] Commit: `feat(028): apply a stored import in one transaction`
- [ ] **Spike: measure the transaction now, before building on it (maintainer ruling 5).** With the method of Phase 11 (a throwaway `bin/rails runner` script in the session scratchpad, never committed; data for cases (a), (b) and (c) of AC-1.10), call `CollectionImport::Apply.new(...).call` in-process and take the transaction's time from `ActiveSupport::Notifications.subscribe("transaction.active_record")` (its `duration` for the outermost transaction), plus a `Benchmark` of each stage for diagnosis. Record the three numbers in a note for `verification.md`.
  - **Under 4 s for all three:** continue with Phase 6.
  - **Over 4 s:** first profile the stages. If the read of the lots, the outcomes or the fingerprint dominate, the author may rework the fingerprint over raw `lots` columns with one lean read, with no visible change: `account.lots.pluck(:id, :catalog_entry_id, :lot_key, :quantity, :created_at, :updated_at)`, no joins; the lot's identity is `(catalog_entry_id, lot_key)`, matched to the file's rows through `entry_id(row)` and `Lot.key_for`; the same function computes the preview's fingerprint, so the values agree; names and set codes for the pages are read in the preview only. Re-measure.
  - **Still over 4 s after that:** stop and ask the maintainer through the coordinator (`orca orchestration ask`) for the fallback decision 3 names (a job on the stored upload). Do not choose it.
---

## Phase 6: The preview stores the upload and offers the apply

**Implements:** decisions 1, 6, 8, 10, 11 (preview side); FR-7 | **Satisfies:** AC-1.1, AC-1.11, AC-5.1 to AC-5.3, AC-7.1
**Files:** `app/controllers/collections/import_previews_controller.rb`, `app/views/collections/import_previews/show.html.erb`, `app/views/collections/import_previews/new.html.erb`, `app/views/collections/import_previews/_apply.html.erb`, `spec/requests/collection_import_previews_spec.rb`, `spec/models/collection_import_spec.rb`
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
        expect(form.at_css("input[type=file]")).to be_nil
        expect(form.at_css("input[name=fingerprint]")["value"]).to eq(user.account.import_upload.fingerprint)
        expect(form.at_css("input[type=submit]")["value"]).to eq("Apply import")
        expect(form.at_css("input[name=confirm_removal]")).to be_present # a lot is removed
        expect(html.at_css("a[href='#{collection_export_path}']")).to be_present
        expect(response.body).to match(/removes 1 lot/).and match(/can't be undone/).and match(/kept for an hour/)
      end

      it "puts the CSRF token in the apply form (FR-5)" do
        ActionController::Base.allow_forgery_protection = true
        preview(file([ row(entry) ]))

        expect(form.at_css("input[name=authenticity_token]")).to be_present
      ensure
        ActionController::Base.allow_forgery_protection = false
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

        stub_const("CollectionImport::MAX_BYTES", 10)
        preview(file([ row(entry) ]))
        expect(response).to have_http_status(:unprocessable_content)
        expect([ ImportUpload.count, ActiveStorage::Blob.count ]).to eq([ 0, 0 ])
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
- [ ] The page says it changed nothing; with a stored upload that is no longer wholly true of the instance, so reword the copy to be exact: `show.html.erb` "Previewing changed nothing." → "Previewing changed nothing in your collection." (both messages), and `new.html.erb`'s hint "…and changes nothing." → "…and changes nothing in your collection." Update the two assertions of `spec/requests/collection_import_previews_spec.rb` (lines 78 and 91) to the new wording, and list both strings among the AC-7.4 readings.
- [ ] Update spec 025's superseded examples: in `spec/models/collection_import_spec.rb` leave "writes nothing (FR-6)" (the model still writes nothing); in `spec/requests/collection_import_previews_spec.rb` change "writes nothing and queues nothing (AC-1.8)" so that its file is one with nothing to change or problem rows and its title cites spec 028 decision 10 ("still writes nothing for a refused file, problem rows or nothing to change").
- [ ] Run `bin/rspec spec/requests/collection_import_previews_spec.rb spec/models/collection_import_spec.rb spec/requests/active_storage_gate_spec.rb` — expect PASS.
- [ ] Commit: `feat(028): the preview keeps an applicable file and offers the apply`
---

## Phase 7: POST /collection/import

**Implements:** decisions 2, 11, 12, 13; FR-5, FR-6 | **Satisfies:** AC-1.2 to AC-1.4 (HTTP), AC-1.9, AC-2.1 (500), AC-2.3 (the lost-upload branch), AC-3.1 to AC-3.6 (HTTP), AC-4.1 (responses), AC-4.2, AC-4.3
**Files:** `app/controllers/collections/imports_controller.rb`, `app/views/collections/imports/failed.html.erb`, `spec/requests/collection_imports_spec.rb`
**Interfaces:** Consumes: `CollectionImport::Apply`, `Result`, the preview views (which read `@import.plan` and `@upload`; `Apply` leaves the import's plan as the transaction's, see Phase 3's `replan`). Produces: `POST /collection/import` per `contracts/api.md`.

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
  def no_store? = response.headers["Cache-Control"].to_s.include?("no-store")

  context "when signed in" do
    before { sign_in_as(user) }

    it "applies and redirects with the counts, no-store on the 303 itself (AC-1.2, FR-6)", :aggregate_failures do
      held_lot(account, import_printing, quantity: 7)
      preview!([ import_row(a, quantity: 6) ])

      apply

      expect(response).to have_http_status(:see_other).and redirect_to(collection_path)
      expect(no_store?).to be(true)
      follow_redirect!
      expect(response.body).to include("Imported: 1 lot added, 0 changed, 1 removed")
      expect(account.lots.pluck(:quantity)).to eq([ 6 ])
    end

    it "answers 303 even when the stored file can't be deleted afterwards", :aggregate_failures do
      preview!([ import_row(a) ])
      allow(ActiveStorage::Blob.service).to receive(:delete).and_raise(Errno::EIO)

      apply

      expect(response).to have_http_status(:see_other)
      expect(account.lots.count).to eq(1)
    end

    it "refuses a second post with 'Preview the file again.' and writes nothing (AC-1.9)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      apply(upload)
      apply(upload)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview the file again.")
      expect(account.lots.count).to eq(1)
    end

    it "answers 409 with a fresh preview whose form carries the new fingerprint (AC-3.1, AC-3.2)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      upload = preview!([ import_row(a, quantity: 5) ])
      old = upload.fingerprint
      lot.update!(quantity: 3)

      apply(upload)

      expect(response).to have_http_status(:conflict)
      expect(no_store?).to be(true)
      expect(response.body).to include("changed since you looked")
      form_fingerprint = html.at_css("input[name=fingerprint]")["value"]
      expect(form_fingerprint).to eq(upload.reload.fingerprint)
      expect(form_fingerprint).not_to eq(old)
      expect(lot.reload.quantity).to eq(3)

      post collection_import_path, params: { fingerprint: form_fingerprint } # the form's own post
      expect(response).to have_http_status(:see_other)
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
      Catalog::Entry.where(id: a.id).update_columns(external_key: "moved")

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
      expect(html.at_css("input[name=fingerprint]")).to be_nil
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
      theirs = store_import!(account: other.account, data: import_file(other, [ import_row(b) ]))
      upload = preview!([ import_row(a) ])

      apply(upload, account_id: other.account.id, upload_id: theirs.id, lot_id: 1)

      expect(account.lots.pluck(:catalog_entry_id)).to eq([ a.id ])
      expect(other.account.lots).to be_empty
      expect(other.account.reload.import_upload).to eq(theirs)
    end

    it "shows nothing of another account in any response (AC-4.1)", :aggregate_failures do
      stranger = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
      held_lot(stranger.account, a, quantity: 7_919)
      lot = held_lot(account, a, quantity: 2)
      upload = preview!([ import_row(a, quantity: 5) ])
      lot.update!(quantity: 3)

      apply(upload) # 409
      conflict = response.body
      apply(account.reload.import_upload) # 303
      follow_redirect!

      [ conflict, response.body ].each { |body| expect(body).not_to include("Zebulon Otherperson", "zebulon.otherperson@example.test", "7,919") }
      expect(stranger.account.lots.pluck(:quantity)).to eq([ 7_919 ])
    end

    it "refuses a post without the CSRF token (FR-5)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      ActionController::Base.allow_forgery_protection = true

      post collection_import_path, params: { fingerprint: upload.fingerprint }

      expect(response).to have_http_status(:unprocessable_content)
      expect(account.lots).to be_empty
    ensure
      ActionController::Base.allow_forgery_protection = false
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
      when :nothing_to_change then preview(result, "This file has nothing to change", :unprocessable_content, upload: nil)
      when :stale then preview(result, "The collection or the file changed since you looked. This is what applying would do now.", :conflict)
      when :unconfirmed then preview(result, "Confirm the removal to apply this file", :unprocessable_content)
      end
    end

    def notice_for(counts)
      "Imported: #{helpers.pluralize(counts[:added], "lot")} added, #{counts[:changed]} changed, #{counts[:removed]} removed"
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

    def preview(result, message, status, upload: result.upload)
      flash.now[:alert] = message
      render_preview(result.import, upload, status)
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

  The exceptions after the commit cannot reach the `rescue`: the blob's release rescues and logs inside `ImportUpload` (Phase 1), so a failing delete is a 303, never "Nothing was changed". The refused-file page for `:refused` shows the problem rows through `import_previews/show`, whose `@import.applicable?` branch is false.
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

  describe "the format's valid example with lots (AC-6.4)" do
    # One entry and printing per source id (collection.json repeats ids across lots), with the finishes of its lots.
    def build_catalog(data)
      data["lots"].group_by { |lot| lot.dig("entry", "source_id") }.each_value do |lots|
        entry = lots.first["entry"]
        set = Catalog::Set.find_by(collectible_type: entry["collectible_type"], code: entry["set_code"]) || create(:catalog_set, code: entry["set_code"])
        created = create(:catalog_entry, external_key: entry["source_id"], set:, number: entry["collector_number"], language: entry["language"], name: entry["name"])
        create(:mtg_printing, entry: created, finishes: (%w[nonfoil foil etched] + lots.filter_map { |lot| lot["finish"] }).uniq)
      end
    end

    it "applies collection.json to an empty account and exports the same collection", :aggregate_failures do
      bytes = ExportFormatRules.examples("valid").fetch("valid/collection.json")
      data = JSON.parse(bytes)
      build_catalog(data)
      user = create(:user, name: data.dig("profile", "name"), email_address: data.dig("profile", "email_address"))

      expect(apply!(user, data).outcome).to eq(:applied)
      expect(same_collection?(data, export(user))).to be(true)
      expect(user.account.lots.count).to eq(data["lots"].size)
    end
  end

- [ ] `empty.json` is a different case: its currency is EUR, so it is refused unless the instance uses EUR, and an example that skips that proves nothing. Add to `spec/requests/collection_import_previews_spec.rb`:

```ruby
    it "previews the format's empty example, in its own currency, as nothing to change with no apply offered (AC-6.4)", :aggregate_failures do
      allow(Rails.configuration.x).to receive(:currency).and_return(Collector::Currency.fetch!("EUR"))
      bytes = ExportFormatRules.examples("valid").fetch("valid/empty.json")

      post collection_import_preview_path, params: { export_file: import_upload_file(bytes) }

      expect(response).to have_http_status(:ok) # not refused as another currency
      expect(response.body).to include("nothing to change")
      expect(html.css("form[action='#{collection_import_path}']")).to be_empty
      expect(ImportUpload.count).to eq(0)
    end
```

- [ ] Run `bin/rspec spec/models/collection_import/round_trip_spec.rb spec/requests/collection_import_previews_spec.rb` — expect PASS once Phases 4–5 hold; any red is a defect there (fix, then rerun). If `Catalog::Set` is named differently, use the constant `spec/factories/catalog.rb` builds; the instance currency is USD, as the examples' (`docs/export-format/examples/valid/*.json` `"currency"`).
- [ ] Commit: `test(028): export and import round trip`
---

## Phase 9: The flow in the browser, and the pages' look

**Implements:** Story 7 | **Satisfies:** AC-7.2, AC-7.3, AC-7.4
**Files:** `spec/system/collection_import_apply_spec.rb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/ImportPreview.md`
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

  `spec/system/narrow_pages_spec.rb` lists GET paths and the preview with an apply form is the result of a POST, so it is not added there; AC-7.3 is verified by the screenshots below (plan-review.md, O-m11).
- [ ] Run `bin/rspec spec/system/collection_import_apply_spec.rb` — expect PASS. It is a characterization test (it adds no code); a red is a defect in Phase 6 or 7 to fix there, and `verification.md` lists it as characterization.
- [ ] Read `docs/design-system/README.md`; confirm the apply form uses only existing tokens and `c-*` classes (`c-form`, `c-field`, `c-btn`, `c-import__note`, `c-status__message`). If a class was added (`c-import__apply`, the checkbox label), define it in `additions.css` with tokens only and add a section to `docs/design-system/components/ImportPreview.md` showing the apply form and the stale-plan notice markup.
- [ ] Capture screenshots at 1280 px and 390 px, light and dark, for: the preview with the apply form, the stale-plan page (409), a refused apply (422), the notice after applying (method of spec 025's `screenshots/`: headless Firefox; memory "Headless Firefox narrow frame"); save under `docs/specs/028-apply-import/screenshots/`; they are recorded in `verification.md` (Phase 13).
- [ ] Commit: `feat(028): the apply flow in the browser and its pages`
---

## Phase 10: The core stays collectible-agnostic, and the file stays out of logs

**Implements:** FR-6, FR-8 | **Satisfies:** FR-6, FR-8 (no AC)
**Files:** `spec/import_apply_core_spec.rb` (created in Phase 0 with its first example; completed here), `.rubocop.yml`
**Interfaces:** Consumes: the files of Phases 0–7. Produces: the FR-8 guard.

The "never names a collectible type or a source" example is written in **Phase 0**, before any of these files exist, over the files that do exist (so it can fail the moment any of them names `MTG` or `Scryfall`). This phase adds the example that every file of the feature exists, and the log-filter example. Both are characterization tests (they pass when written, as spec 025's core spec did); they are listed as such in `verification.md`.

- [ ] Phase 0's example, for reference (tag `type: :config`; the describe is a string, so `spec/import_apply_core_spec.rb` is added to `RSpec/DescribeClass`'s `Exclude` in `.rubocop.yml` with the comment that it checks the files of a feature, like `spec/collection_import_core_spec.rb`):

```ruby
# spec/import_apply_core_spec.rb
require "rails_helper"

# Spec 028 FR-8: the apply and the stored upload name no collectible type or source. FR-6: the file isn't logged.
RSpec.describe "Apply an import, core code", type: :config do
  let(:files) do
    %w[
      app/models/import_upload.rb app/jobs/import_upload/sweep_job.rb app/models/collection_import/plan.rb
      app/models/collection_import/apply.rb app/models/collection_import/working_state.rb
      app/controllers/collections/imports_controller.rb app/controllers/concerns/active_storage_gate.rb
      app/views/collections/import_previews/_apply.html.erb app/views/collections/imports/failed.html.erb
    ]
  end

  it "never names a collectible type or a source" do
    named = files.select { |file| Rails.root.join(file).exist? && Rails.root.join(file).read.match?(/\b(mtg|scryfall)\b/i) }

    expect(named).to be_empty
  end
end
```

- [ ] Add the two examples (characterization):

```ruby
  it "exists, every file of it" do
    expect(files.reject { |file| Rails.root.join(file).exist? }).to be_empty
  end

  it "keeps the uploaded file out of the logs" do
    expect(Rails.application.config.filter_parameters).to include(:export_file)
  end
```

- [ ] Run `bin/rspec spec/import_apply_core_spec.rb` — expect PASS; `bin/rubocop` — expect clean.
- [ ] Commit: `test(028): keep the apply collectible-agnostic`
---

## Phase 11: Measure the whole request, and the checks no example makes

**Implements:** decision 3 | **Satisfies:** AC-1.10 (whole request, RSS, preview re-measure), AC-6.5, AC-2.3 (concurrency, by hand)
**Files:** a throwaway script in the session scratchpad (never committed); results in `docs/specs/028-apply-import/verification.md` (Phase 13)
**Interfaces:** Consumes: Phases 0–7. Produces: the measurements, or the fallback question for the maintainer.

The transaction's bar was first measured in Phase 5's spike. This phase measures the whole request and the other checks, with the final code.

- [ ] Method: reuse spec 025's (`docs/specs/025-import-preview/verification.md`, AC-1.10): a throwaway `bin/rails runner` script inserts one set, 50,000 identities, entries and `mtg_printings`; a verify user; writes the files **(a)** 50,000 resolvable rows; **(b)** the same file with every row changed (quantities +1); **(c)** an empty file with 50,000 held lots. For each: a fresh `bin/dev` server; sign in with curl; preview the file; read `VmRSS`/`VmHWM`; `curl` the apply with the form's `fingerprint`, `confirm_removal=1` for (c); read RSS again. Record the preview's time and RSS for (a) as well (P3).
- [ ] Bars: whole request < 30 s, RSS growth < 500 MB, **write transaction < 4 s** (re-timed with `transaction.active_record`, as in the spike); the preview of (a) with the store still < 30 s / 500 MB.
- [ ] If the transaction bar is missed here after passing in the spike, or after the spike's lean-read rework: stop and **ask the maintainer through the coordinator** for the fallback (decision 3). Do not choose it.
- [ ] AC-2.3 by hand (the examples simulate the lost upload; only two real connections show "neither answers 500"): preview a file, then post the form twice at once (`curl … & curl … & wait`). Expect exactly one 303 and the other a 422 "Preview the file again." (or 409), no 500, and the collection equal to the file. Repeat ten times with fresh previews.
- [ ] AC-6.5 by hand: export a development instance holding a real catalog, apply it through the pages to a second, empty instance (second worktree), export that, compare with `ExportFormatRules.same_collection?` in a runner, profile name and email apart. Record steps and result.
- [ ] Remove the inserted rows afterwards (as spec 025 did). No commit (results go in Phase 13).
---

## Phase 12: Documents

**Implements:** "Documents that change", decision 10 | **Satisfies:** AC-5.5 (Coverage, done in Phase 0), documents (by reading)
**Files:** `CLAUDE.md`, `README.md`, `docs/roadmap.md`, `docs/adr/0013-active-storage-variants-with-vips.md`, `docs/adr/0022-stored-import-upload-retention.md`, `docs/adr/README.md` (done), `docs/specs/README.md`, `docs/architecture/` area docs if they exist by then, `docs/specs/028-apply-import/spec.md` (only the Plan link, through `sdd-spec-update`)
**Interfaces:** Consumes: the finished feature. Produces: the documents in step with the code.

No test: prose documents are verified by reading (`.claude/rules/testing.md`), recorded in `verification.md`.

- [ ] Upgrade notes (`.claude/rules/external-data-and-portability.md`): in `docs/releasing.md`'s release notes convention, say that this release runs two migrations (Active Storage's tables and `import_uploads`) on boot, adds blob files under `storage/` (at most one per account, removed within an hour, 10 minutes more for an orphan), and needs nothing from the operator.
- [ ] `docs/architecture/catalog-operations.md`: the sweep is a second recurring job and shows on `/admin/jobs`; add a line under the recurring-jobs part with its source (spec 028 AC-5.5, ADR 0022), or record in `verification.md` why the area doc does not cover it.
- [ ] `docs/architecture/README.md`: add 028 to the "Data portability" and "Release and deploy" rows' "Specs it covers" (the area docs themselves are written by `distill-feature`).
- [ ] `CLAUDE.md`: Project Status (applying an import is built: a collector previews and applies an export file; the previewed upload is kept an hour), the "Import preview" fact (it now stores the upload for an applicable file with something to change; add `POST /collection/import`, the 4 s write-transaction bar, the sweep), the "Active Storage variants" fact (the owed validation is met by the stored upload; the routes are gated by `ActiveStorageGate` in `config/initializers/active_storage_gate.rb`, direct uploads answer 404, ADR 0022).
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
- [ ] List the characterization tests (Phases 8, 9 and 10 add no code, so they pass when written) and the Phase 5 spike numbers in `verification.md`.
- [ ] Write `verification.md`: a row per AC and FR with the spec, example or measurement that holds it (as spec 025's does), the Phase 11 measurements, the screenshots, the by-reading document checks.
- [ ] Run `sdd-superpowers:sdd-review` Mode B; record its verdict on the first line under `## Implementation review` (the heading `distill-feature` reads).
- [ ] Run `sdd-superpowers:session-wrap`, then `distill-feature`.
---

## Risks

1. **The 4 s transaction bar (decision 3).** The read of 50,000 held lots, the comparison, 50,000 deletes (with the cascade to `bulk_selection_marks`) and the upserts sit in it. Mitigations, in order: all Ruby work that is not a write is done before `BEGIN`; `returning: false`; Phase 5's spike measures it before anything is built on it; if missed, the author may rework the fingerprint over raw `lots` columns with one lean read (no visible change); only if it is still missed does the maintainer rule the fallback.
2. **Parse and resolve time.** Spec 025 measured the preview at about 10.6 s for 50,000 rows; the apply repeats that work, plus the store, inside the 30 s request bar and kamal-proxy's 30 s default timeout. Measured in Phase 11 (P3).
3. **The Active Storage gate authorises original blobs only.** Variant records and preview images hang off records without an `account_id`, so the gate serves them to no one. The first image feature must extend ownership to variant records and preview images before its variants can be served; nothing of variants is built here (ADR 0022). The gate also depends on Active Storage's controller internals; a Rails upgrade that renames `signed_id`/`encoded_key` breaks it, and AC-1.12's examples fail first. Direct-upload creation and the disk PUT answer 404 until a feature needs them; that feature defines its owner rule, quota and clean-up.
4. **A blob release that fails** (the file delete raises after commit) leaves a marked, unattached blob row, which the sweep finds after 10 minutes; the request still succeeds. If the row delete itself keeps failing, the sweep logs and retries every 15 minutes.
5. **`Lot.upsert_all` skips validations and callbacks** (FR-3, ruled). AC-2.4's example and the round trip check the rows against `Lot`; a later `Lot` validation needs the apply updated (the round trip fails first).
6. **Memory.** The stored file is read whole and parsed whole (32 MB cap), and the apply holds one attribute hash per row until the transaction ends. Inside the 500 MB bar by measurement only.
7. **`ImportUpload.store!` is not atomic with its file.** A crash between the blob and the record leaves a marked blob; the sweep removes it after 10 minutes (P4).
8. **Catalog change between resolving and writing.** A finish a refresh stops listing is accepted (spec error scenario).
9. **Spec 029 (locations)** will touch `Plan`, `Apply#write!` and `lot_attributes`. They are kept as the single places for it.
10. **AC-2.3 is simulated in the suite** (the upload removed between reading and the transaction); the concurrent case is checked by hand in Phase 11.

## Self-Review

- **Spec coverage:** every FR (1–10) and AC (1.1–1.12, 2.1–2.5, 3.1–3.7, 4.1–4.4, 5.1–5.6, 6.1–6.5, 7.1–7.4) appears in the Requirement Map with a phase and a first failing test. AC-1.10 and AC-6.5 are measured outside the suite, by design; AC-7.3, AC-7.4 and the documents are verified by screenshots and reading.
- **Placeholder scan:** none; the two places that depend on what the code shows at implementation (the Active Storage install migration is generated by the framework, and the checkbox classes are chosen from the design system) say exactly what to run or read.
- **Type consistency:** `ImportUpload.store!(account:, bytes:, plan:)`, `CollectionImport#plan/#replan/#entry_id`, `Plan#fingerprint(checksum)`, `Apply.new(account:, fingerprint:, confirmed:).call → Result(outcome, import, plan, upload, fingerprint)`, `WorkingState.clear!(account)` are used identically across phases.
- **Order:** each phase ends green on its own: 0 (tables) → 1 (store; stand-in plan) → 2 (sweep) → 3 (plan) → 4 (gate; needs the plan for `store_import!`) → 5 (apply, then the transaction spike) → 6 (preview) → 7 (controller) → 8 (round trip) → 9 (browser) → 10 (core) → 11 (measure) → 12 (docs) → 13 (verification).
- **Independent review:** two read-only reviews (Sonnet 5.5 and Opus) of the first version; every finding is resolved or rejected with a reason in [plan-review.md](plan-review.md). The revised plan has not been reviewed again.
