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
      expect(apply(other.account.import_upload, for_account: other.account).outcome).to eq(:applied)
      expect(other.reload.collection_view).to eq("grid")
    end
  end

  describe "working state (decision 7, AC-1.8)" do
    it "clears the lists that point at lots when the apply writes", :aggregate_failures do
      removal = working_state_for(held_lot(account, d, quantity: 3))
      Scanner::Sitting.sole.update!(location: create(:location, account:), condition: "near_mint") # a sitting with its choices goes too (spec 040 AC-5.3, spec 042 AC-5.3)
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

    it "answers :unreadable, removing the row, for an upload that has lost its attachment (maintainer ruling 2026-10-21)", :aggregate_failures do
      upload = preview!([ import_row(a) ])
      ActiveStorage::Attachment.where(record: upload).delete_all

      expect(apply(upload).outcome).to eq(:unreadable)
      expect([ account.lots.count, ImportUpload.count ]).to eq([ 0, 0 ])
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

  describe "locations (spec 029 decisions 10 and 11)" do
    def preview_v2!(lots, locations: [], **fields) = store_import!(account:, data: import_file_v2(user, lots, locations:, **fields))

    def location_rows = account.locations.order(:id).pluck(:id, :name, :name_key, :created_at, :updated_at)

    def location_statements
      statements = []
      counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\b(INSERT INTO|UPDATE|DELETE FROM) "locations"/) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      statements.size
    end

    it "makes the account's locations the file's, keeping a renamed one's id and not writing an unchanged one (AC-9.1)", :aggregate_failures do
      trade, box = travel_to(Time.utc(2026, 10, 1)) { [ create(:location, account:, name: "Trade binder"), create(:location, account:, name: "box") ] }
      create(:location, account:, name: "Old crate")
      trade_before = trade.reload.attributes
      preview_v2!([ import_row(a) ], locations: [ "Blue binder", "Box", "Trade binder" ])

      expect(apply.outcome).to eq(:applied)

      expect(account.locations.ordered.pluck(:name)).to eq([ "Blue binder", "Box", "Trade binder" ])
      expect(box.reload.name).to eq("Box")
      expect(box.name_key).to eq("box")
      expect(box.updated_at).to be > Time.utc(2026, 10, 1)
      expect(trade.reload.attributes).to eq(trade_before)
    end

    it "fills an empty account with the file's lots and locations and nothing else (AC-9.2)", :aggregate_failures do
      preview_v2!([ import_row(a), import_row(b, quantity: 2), import_row(c) ], locations: [ "Blue binder", "Box", "Crate" ])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.count).to eq(3)
      expect(account.locations.ordered.pluck(:name)).to eq(%w[Blue\ binder Box Crate])
      expect(Location.where.not(account_id: account.id)).to be_empty
    end

    it "leaves the account's locations as they were for a version 1 file, with the same ids and times (AC-9.3)", :aggregate_failures do
      travel_to(Time.utc(2026, 10, 1)) { create(:location, account:, name: "Box") }
      before = location_rows
      preview!([ import_row(a) ])

      expect(apply.outcome).to eq(:applied)
      expect(location_rows).to eq(before)
    end

    it "applies a file whose only change is a location, changing no lot and clearing no working state (AC-9.4, AC-9.17)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      removal = working_state_for(lot)
      Scanner::Sitting.sole.update!(location: create(:location, account:, name: "Old crate")) # spec 040 AC-3.2
      preview_v2!([ import_row(a, quantity: 2) ], locations: [ "Blue binder" ])
      lots_before = lots_state

      expect(apply.outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
      expect(lots_state).to eq(lots_before)
      expect([ NumberEntry.count, Scanner::Sitting.count, BulkSelection.count, BulkSelection::Mark.count ]).to eq([ 1, 1, 1, 1 ])
      expect(Scanner::Sitting.sole.location_id).to be_nil # the removed location clears the sitting's place (spec 040 AC-3.2)
      expect(removal.reload).to be_undoable
    end

    it "clears the working state when a lot is written, and leaves it for a change of view alone (AC-9.17)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      removal = working_state_for(lot)
      profile = { "name" => user.name, "email_address" => user.email_address, "collection_view" => "table" }
      preview_v2!([ import_row(a, quantity: 2) ], locations: [], profile:)

      expect(apply.outcome).to eq(:applied)
      expect(user.reload.collection_view).to eq("table")
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count).to eq(3) # a view change writes no lot
      expect(removal.reload).to be_undoable # the fourth kind of working state (plan review m8)

      preview_v2!([ import_row(a, quantity: 5) ], locations: [], profile:)
      expect(apply.outcome).to eq(:applied)
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count).to eq(0)
    end

    it "writes nothing the second time, and the same file then previews as nothing to change (AC-9.7)", :aggregate_failures do
      create(:location, account:, name: "box")
      upload = preview_v2!([ import_row(a) ], locations: [ "Box", "Crate" ])
      first = apply(upload)
      after = location_rows

      expect(first.outcome).to eq(:applied)
      import = CollectionImport.new(account: account.reload, file: StringIO.new(JSON.generate(import_file_v2(user, [ import_row(a) ], locations: [ "Box", "Crate" ]))))
      expect(import.plan.nothing_to_change?).to be(true)
      expect(import.locations.unchanged).to eq(2)
      forced = store_import!(account:, data: import_file_v2(user, [ import_row(a) ], locations: [ "Box", "Crate" ]), forced: true)
      expect(apply(forced).outcome).to eq(:nothing_to_change)
      expect(location_rows).to eq(after)
    end

    it "rolls everything back when a location can't be written after the lots were, keeping the upload (AC-9.8)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      held_lot(account, d, quantity: 3)
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])
      before = snapshot
      allow(CollectionImport::DeckChanges).to receive(:write!).and_raise(RuntimeError, "disk full")

      expect { apply(upload) }.to raise_error(RuntimeError, "disk full")
      expect(snapshot).to eq(before)
      expect(account.reload.import_upload).to eq(upload)

      allow(CollectionImport::DeckChanges).to receive(:write!).and_call_original
      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to eq([ "Blue binder" ])
    end

    describe "a location changed after the preview (AC-9.9)" do
      let!(:box) { create(:location, account:, name: "box") }
      let!(:upload) { preview_v2!([ import_row(a) ], locations: [ "Box", "Same" ]) }

      it "is refused as stale when one was added, writing nothing", :aggregate_failures do
        create(:location, account:, name: "Late")
        before = snapshot

        expect(apply(upload).outcome).to eq(:stale)
        expect(snapshot).to eq(before)
        expect(account.locations.pluck(:name)).to match_array(%w[box Late])
      end

      it "is refused as stale when one was respelled, with the fresh plan showing it (a change of case alone)", :aggregate_failures do
        box.update!(name: "Box") # the rename became unchanged
        before = snapshot

        result = apply(upload)

        expect(result.outcome).to eq(:stale)
        expect(result.import.locations.counts).to eq(added: 1, renamed: 0, unchanged: 1, removed: 0)
        expect(snapshot).to eq(before)
      end

      it "is refused as stale when one was removed, writing nothing", :aggregate_failures do
        box.destroy!
        before = snapshot

        expect(apply(upload).outcome).to eq(:stale)
        expect(snapshot).to eq(before)
      end
    end

    it "applies after a renamed, a removed and an unchanged location were each deleted and added again with the same spelling (AC-9.9, ruled 2026-10-21)", :aggregate_failures do
      box, crate, same = [ "box", "Old crate", "Same" ].map { |name| create(:location, account:, name:) } # box is renamed, Old crate removed
      upload = preview_v2!([ import_row(a) ], locations: [ "Box", "Same", "New" ])
      recreated = [ box, crate, same ].map do |location|
        name = location.name
        location.destroy!
        create(:location, account:, name:) # new ids, the same names
      end

      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.ordered.pluck(:name)).to eq(%w[Box New Same])
      expect(account.locations.find_by!(name: "Box").id).to eq(recreated.first.id) # the apply wrote by the ids it read inside its transaction
    end

    it "needs the confirmation only when it removes lots or locations (AC-9.10)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      removes = preview_v2!([ import_row(a) ], locations: [])

      expect(apply(removes, confirmed: false).outcome).to eq(:unconfirmed)
      expect(account.locations.count).to eq(1)
      expect(apply(removes, confirmed: true).outcome).to eq(:applied)
      expect(account.locations.count).to eq(0)

      create(:location, account:, name: "Old crate")
      renames = preview_v2!([ import_row(a) ], locations: [ "OLD CRATE", "New" ])
      expect(apply(renames, confirmed: false).outcome).to eq(:applied) # only additions and renames: no checkbox
      expect(account.locations.pluck(:name)).to contain_exactly("OLD CRATE", "New")
    end

    it "removes a location without touching a lot (AC-9.11)", :aggregate_failures do
      held_lot(account, a, quantity: 4)
      create(:location, account:, name: "Old crate")
      upload = preview_v2!([ import_row(a, quantity: 4) ], locations: [])
      lots_before = lots_state

      expect(apply(upload).outcome).to eq(:applied)
      expect(lots_state).to eq(lots_before)
      expect(account.locations.count).to eq(0)
    end

    it "replaces 500 held locations with the file's 500 others, with no failure from the limit (AC-9.12)", :aggregate_failures do
      Location.insert_all!(Array.new(500) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })
      names = Array.new(500) { |index| "Other #{index}" }
      upload = preview_v2!([ import_row(a) ], locations: names)

      expect(apply(upload).outcome).to eq(:applied)
      expect(account.locations.pluck(:name)).to match_array(names)
    end

    it "touches only this account's locations (AC-9.13)", :aggregate_failures do
      other = create(:user)
      create(:location, account:, name: "Box")
      create(:location, account: other.account, name: "Box")
      theirs = other.account.locations.order(:id).pluck(:id, :name, :updated_at)
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])

      expect(apply(upload).outcome).to eq(:applied)
      expect(other.account.locations.order(:id).pluck(:id, :name, :updated_at)).to eq(theirs)
    end

    it "writes locations that Location would accept, with the key it gives (FR-3 of spec 028, for locations)", :aggregate_failures do
      create(:location, account:, name: "box")
      preview_v2!([ import_row(a) ], locations: [ "Box", "Straße", "Café", "日本語のバインダー" ])

      apply

      account.locations.each do |location|
        expect(location).to be_valid, location.name
        expect(location.name_key).to eq(Location::Name.key(location.name))
        expect(location.name).to eq(Location::Name.normalise(location.name))
      end
      expect(account.locations.pluck(:name)).to include("Café")
    end

    it "reads a name in NFD as its NFC spelling: unchanged against a held one, added as NFC without one, renamed when only the case differs (AC-9.18)", :aggregate_failures do
      held = create(:location, account:, name: "Café")
      before = held.reload.attributes
      preview_v2!([ import_row(a) ], locations: [ "Café", "Straße" ])
      expect(apply.outcome).to eq(:applied)
      expect(held.reload.attributes).to eq(before)
      expect(account.locations.pluck(:name)).to contain_exactly("Café", "Straße")

      preview_v2!([ import_row(a) ], locations: [ "CAFÉ", "Straße" ])
      expect(apply.outcome).to eq(:applied)
      expect(held.reload.name).to eq("CAFÉ")
    end

    it "writes the locations in as many statements for 150 changes of each kind as for one (NFR)", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:location, account:, name: "Old crate")
      few = preview_v2!([ import_row(a) ], locations: [ "Box", "New" ])
      few_statements = location_statements { apply(few) }

      Location.where(account_id: account.id).delete_all
      Location.insert_all!((1..300).map { |number| { account_id: account.id, name: format("old %03d", number), name_key: format("old %03d", number) } })
      many = preview_v2!([ import_row(a, quantity: 2) ], locations: (1..150).map { |number| format("OLD %03d", number) } + (1..150).map { |number| format("new %03d", number) })

      expect(location_statements { apply(many) }).to eq(few_statements)
    end
  end

  describe "bounded statements (FR-4)" do
    include QueryCounting # spec/support/query_counting.rb, which includes itself for request specs only

    def statements_for(size)
      other = create(:user)
      upload = store_import!(account: other.account, data: import_file(other, Array.new(size) { import_row(import_printing) }))
      count_queries { apply(upload, for_account: other.account) }
    end

    it "runs the same statements within one batch, and the same number more for each batch past it", :aggregate_failures do
      stub_const("CollectionImport::BATCH_SIZE", 10)
      one, two, three = [ 9, 15, 25 ].map { |size| statements_for(size) } # one, two and three batches

      expect(statements_for(2)).to eq(one)
      expect(two).to be > one
      expect(three - two).to eq(two - one) # linear in the number of batches, never in the number of rows
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
      Catalog::Entry.find(a.id).update_columns(external_key: "moved")
      key = upload.file.blob.key

      expect(apply(upload).outcome).to eq(:refused)
      expect([ ImportUpload.count, service.exist?(key) ]).to eq([ 0, false ])
    end

    it "refuses a stored file with a price that doesn't fit, and removes it (spec 028 1.3.4)", :aggregate_failures do
      upload = store_import!(account:, data: import_file(user, [ import_row(a, price_paid: "92233720368547758.08") ]), forced: true)

      expect(apply(upload).outcome).to eq(:refused)
      expect([ account.lots.count, ImportUpload.count ]).to eq([ 0, 0 ])
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
      Catalog::Entry.find(c.id).update_columns(external_key: "gone")
      held_lot(refused.account, import_printing, quantity: 1) # also makes the plan stale
      expect(apply(kept, for_account: refused.account).outcome).to eq(:refused)
    end
  end

  describe "the currency (spec 038 decision 7)" do
    it "sets the account's currency to the file's with its lots (AC-6.3)", :aggregate_failures do
      preview!([ import_row(a, price_paid: "12.50") ], currency: "EUR")
      expect(apply.outcome).to eq(:applied)
      expect([ account.reload.currency, account.lots.sole.price_paid_cents ]).to eq([ "EUR", 1250 ])
    end

    it "applies a file whose only difference is its currency, changing nothing else (AC-6.5)", :aggregate_failures do
      held_lot(account, a, quantity: 3)
      preview!([ import_row(a, quantity: 3) ], currency: "EUR")
      before = lots_state
      expect(apply.outcome).to eq(:applied)
      expect([ account.reload.currency, lots_state ]).to eq([ "EUR", before ])
    end

    it "leaves the currency as it was when the apply's transaction fails (AC-6.9)", :aggregate_failures do
      preview!([ import_row(a) ], currency: "EUR")
      ActiveRecord::Base.connection.execute("CREATE TRIGGER fail_lot_upsert BEFORE INSERT ON lots BEGIN SELECT RAISE(ABORT, 'forced'); END")

      expect { apply }.to raise_error(ActiveRecord::StatementInvalid)
      expect(account.reload.currency).to eq("USD")
    end

    it "is stale when the currency changed after the preview, and says the new plan (AC-6.7)", :aggregate_failures do
      preview!([ import_row(a) ], currency: "EUR")
      upload = account.reload.import_upload
      account.update!(currency: "GBP")

      result = apply(upload)
      expect(result.outcome).to eq(:stale)
      expect(result.plan.currency_change).to eq(CollectionImport::CurrencyChange.new(from: "GBP", to: "EUR"))
      expect(account.reload.currency).to eq("GBP")
    end

    it "has nothing to change when the account was changed to the file's currency and nothing else differs" do
      held_lot(account, a, quantity: 3)
      preview!([ import_row(a, quantity: 3) ], currency: "EUR")
      upload = account.reload.import_upload
      account.update!(currency: "EUR")

      expect(apply(upload).outcome).to eq(:nothing_to_change)
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

  describe "lots in locations (spec 032 Story 11)" do
    def preview_v3!(lots, locations: [], **fields) = store_import!(account:, data: import_file_v3(user, lots, locations:, **fields))

    def place_of(entry) = account.lots.where(catalog_entry_id: entry.id).map { |lot| lot.location&.name }.sort_by(&:to_s)

    def statements_during
      statements = []
      counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)/) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      statements.size
    end

    it "puts every lot in the file's location or none, with the key that carries the place (AC-11.1)", :aggregate_failures do
      preview_v3!([ import_row(a, location: "Blue binder"), import_row(a, finish: "foil", location: nil), import_row(b, location: "Box") ],
        locations: [ "Blue binder", "Box" ])

      expect(apply.outcome).to eq(:applied)
      expect(place_of(a)).to eq([ nil, "Blue binder" ])
      expect(place_of(b)).to eq([ "Box" ])
      account.lots.each do |lot|
        expect(lot).to be_valid
        expect(lot.lot_key).to eq(Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, lot.location_id))
      end
    end

    it "moves a lot from one place to another: one added, one removed (AC-11.3)", :aggregate_failures do
      long = create(:location, account:, name: "Long box")
      create(:location, account:, name: "Blue binder")
      held_lot(account, a, quantity: 2, location: long)
      preview_v3!([ import_row(a, quantity: 2, location: "Blue binder") ], locations: [ "Long box", "Blue binder" ])

      result = apply
      expect(result.outcome).to eq(:applied)
      expect(result.plan.counts).to eq(added: 1, changed: 0, removed: 1)
      expect(place_of(a)).to eq([ "Blue binder" ])
    end

    it "makes an older file's lots unplaced, needing the removal confirmation (AC-11.4)", :aggregate_failures do
      box = create(:location, account:, name: "Box")
      held_lot(account, a, quantity: 2, location: box)
      store_import!(account:, data: import_file_v2(user, [ import_row(a, quantity: 2) ], locations: [ "Box" ]))

      expect(apply(confirmed: false).outcome).to eq(:unconfirmed)
      expect(account.lots.sole.location).to eq(box)
      expect(apply.outcome).to eq(:applied)
      expect(account.lots.sole.location).to be_nil
      expect(account.locations.pluck(:name)).to eq([ "Box" ])
    end

    it "keeps a location's id and its lots untouched when only its spelling changes (AC-11.5)", :aggregate_failures do
      box = create(:location, account:, name: "box")
      lot = held_lot(account, a, quantity: 2, location: box)
      before = lot.reload.attributes
      preview_v3!([ import_row(a, quantity: 2, location: "Box"), import_row(b, location: nil) ], locations: [ "Box" ])

      expect(apply.outcome).to eq(:applied)
      expect(box.reload.name).to eq("Box")
      expect(lot.reload.attributes).to eq(before)
      expect(JSON.parse(CollectionExport.new(account:, at: Time.current).to_json)["lots"].map { |row| row["location"] }).to include("Box")
    end

    it "deletes the lots of a removed location first and answers stale when a lot was placed there after the preview (AC-11.6)", :aggregate_failures do
      gone = create(:location, account:, name: "Gone")
      held_lot(account, a, quantity: 1, location: gone)
      upload = preview_v3!([ import_row(b, location: nil) ], locations: [])
      held_lot(account, c, quantity: 1, location: gone)
      before = snapshot

      expect(apply(upload).outcome).to eq(:stale)
      expect(snapshot).to eq(before)
    end

    it "answers stale when a lot was moved to another place between preview and apply (AC-11.7)", :aggregate_failures do
      box = create(:location, account:, name: "Box")
      other = create(:location, account:, name: "Other")
      lot = held_lot(account, a, quantity: 1, location: box)
      upload = preview_v3!([ import_row(a, quantity: 5, location: "Box") ], locations: [ "Box", "Other" ])
      lot.update!(location: other)

      expect(apply(upload).outcome).to eq(:stale)
    end

    it "has nothing to change the second time (AC-11.8)", :aggregate_failures do
      data = import_file_v3(user, [ import_row(a, location: "Box") ], locations: [ "Box" ])
      store_import!(account:, data:)
      expect(apply.outcome).to eq(:applied)

      expect(CollectionImport.new(account: account.reload, file: import_io(data)).plan.nothing_to_change?).to be(true)
    end

    it "applies a file whose only change is one lot's place (AC-11.9)", :aggregate_failures do
      box = create(:location, account:, name: "Box")
      create(:location, account:, name: "Crate")
      held_lot(account, a, quantity: 2, location: box)
      preview_v3!([ import_row(a, quantity: 2, location: "Crate") ], locations: [ "Box", "Crate" ])

      expect(apply.outcome).to eq(:applied)
      expect(place_of(a)).to eq([ "Crate" ])
    end

    it "rolls back locations, lots and working state when a write fails after the locations were written (AC-11.10)", :aggregate_failures do
      held = held_lot(account, a, quantity: 1)
      working_state_for(held)
      preview_v3!([ import_row(b, location: "Box") ], locations: [ "Box" ])
      ActiveRecord::Base.connection.execute("CREATE TRIGGER fail_lot_upsert BEFORE INSERT ON lots BEGIN SELECT RAISE(ABORT, 'forced'); END")
      before = snapshot

      expect { apply }.to raise_error(ActiveRecord::StatementInvalid)
      expect(snapshot).to eq(before)
    end

    it "resolves 'Box' to its own account's location and leaves another account's alone (AC-11.11)", :aggregate_failures do
      other = create(:user).account
      theirs = create(:location, account: other, name: "Box")
      their_lot = create(:lot, account: other, entry: a, location: theirs, quantity: 4)
      mine_before = other.lots.map(&:attributes)
      preview_v3!([ import_row(a, location: "Box") ], locations: [ "Box" ])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.sole.location.account_id).to eq(account.id)
      expect(their_lot.reload.attributes).to eq(mine_before.sole)
      expect(theirs.reload.account_id).to eq(other.id)
    end

    it "clears the working state when a lot is written, not when only a location changes (AC-11.13)", :aggregate_failures do
      lot = held_lot(account, a, quantity: 2)
      working_state_for(lot)
      preview_v3!([ import_row(a, quantity: 2, location: nil) ], locations: [ "Box" ])
      expect(apply.outcome).to eq(:applied)
      expect([ NumberEntry.count, Scanner::Sitting.count, BulkSelection.count, BulkSelection::Mark.count ]).to eq([ 1, 1, 1, 1 ])

      preview_v3!([ import_row(a, quantity: 2, location: "Box") ], locations: [ "Box" ])
      expect(apply.outcome).to eq(:applied)
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count + BulkSelection::Mark.count).to eq(0)
    end

    it "writes the lots in one multi-row statement per batch, one that upserts on the lot's identity (spec 032 Phase 8 remedy)", :aggregate_failures do
      names = %w[Box Crate]
      stub_const("CollectionImport::BATCH_SIZE", 40)
      rows = Array.new(90) { |n| import_row(a, price_paid: format("%d.%02d", n / 100, n % 100), location: names[n % 2]) }
      preview_v3!(rows, locations: names)
      writes = []
      counter = ->(*, payload) { writes << payload[:sql] if payload[:sql].start_with?("INSERT INTO lots") }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { expect(apply.outcome).to eq(:applied) }

      expect(writes.size).to eq(3)
      expect(writes).to all(include("ON CONFLICT (account_id, catalog_entry_id, lot_key) DO UPDATE SET quantity = excluded.quantity, created_at = excluded.created_at, updated_at = excluded.updated_at"))
      expect(account.lots.count).to eq(90)
      expect(account.lots.map(&:lot_key)).to all(match(/\A\|\|\d+\|\d+\z/))
    end

    it "stores awkward text in a lot unchanged through the hand-built statement, and leaves the table intact", :aggregate_failures do
      awkward = %(x'?; DROP TABLE lots;-- "q" \\ \u00e9 \u{1F0A1})
      now = Time.utc(2026, 10, 2, 10, 0, 0, 123_456)
      row = { account_id: account.id, catalog_entry_id: a.id, quantity: 3, finish: awkward, condition: "it's ? fine", price_paid_cents: nil,
              location_id: nil, lot_key: "k", created_at: now, updated_at: now }

      described_class.new(account:, fingerprint: "unused", confirmed: true).send(:upsert_lots!, [ row ])

      expect(Lot.where(account_id: account.id).sole).to have_attributes(finish: awkward, condition: "it's ? fine", quantity: 3,
        price_paid_cents: nil, location_id: nil, lot_key: "k", created_at: now, updated_at: now)
    end

    it "runs the same number of write statements for 5,000 lots in 500 locations as for 50 in 5 (AC-11.12)", :aggregate_failures do
      measure = lambda do |lots, places|
        account.lots.delete_all
        account.locations.delete_all
        names = Array.new(places) { |n| "Place #{n}" }
        entry = import_printing
        rows = Array.new(lots) { |n| import_row(entry, price_paid: format("%d.%02d", n / 100, n % 100), location: names[n % places]) }
        store_import!(account:, data: import_file_v3(user, rows, locations: names))
        statements_during { expect(apply.outcome).to eq(:applied) }
      end

      small = measure.call(50, 5)
      expect(measure.call(5_000, 500)).to be <= small + 10 # upserts per BATCH_SIZE lots, not per lot or per location
    end
  end

  describe "decks and zones (spec 062 Story 8)" do
    def preview_v4!(lots, decks: [], locations: [], **fields) = store_import!(account:, data: import_file_v4(user, lots, decks:, locations:, **fields))

    def deck_of(name, format = "modern", type: "mtg") = { "name" => name, "collectible_type" => type, "format" => format }

    def zone(deck, key = "main") = { "deck" => deck, "zone" => key }

    def deck_named(name) = account.decks.joins(:location).find_by!(locations: { name: })

    def zones_of(deck) = deck.zones.pluck(:zone, :name, :name_key)

    def names(scope) = scope.order(:name_key).pluck(:name)

    # Every location and deck of the account checked against the models, as AC-2.4 does for lots (AC-8.9).
    def expect_written_rows_valid
      expect(account.locations.includes(:parent)).to all(be_valid)
      expect(account.decks).to all(be_valid)
    end

    # A vocabulary registered as the type "fake" whose one format "f" has these zones; calling it again is a release that changed them.
    def fake_vocabulary(*zones)
      format = Catalog::Formats::Format.new(key: "f", name: "F", default: true, zones: zones.map { |key, name| Catalog::Formats::Zone.new(key:, name:) })
      stub_const("FakeDeckVocabulary", Module.new { define_singleton_method(:formats) { [ format ] } })
      Catalog.collecting["fake"] = "FakeDeckVocabulary"
    end

    after { Catalog.collecting.delete("fake") }

    it "writes an added deck with the zones of its format in order, keys and names as registered (AC-8.1, AC-8.2, AC-8.9)", :aggregate_failures do
      preview_v4!([ import_row(a, location: nil) ], decks: [ deck_of("Izzet Tempo"), deck_of("Elves", "commander") ])

      expect(apply.outcome).to eq(:applied)

      izzet = deck_named("Izzet Tempo")
      expect([ izzet.collectible_type, izzet.format ]).to eq(%w[mtg modern])
      expect(izzet.location).to have_attributes(kind: "deck", parent_id: nil, zone: nil, name_key: "izzet tempo")
      expect(zones_of(izzet)).to eq([ %w[main Main main], %w[sideboard Sideboard sideboard], %w[considering Considering considering] ])
      expect(zones_of(deck_named("Elves"))).to eq([ %w[commander Commander commander], %w[main Main main], %w[considering Considering considering] ])
      expect_written_rows_valid
    end

    it "keeps a renamed deck's id, zones and lots, and changes a deck's format keeping its id, name and the zones both formats have (AC-8.2)", :aggregate_failures do
      izzet = create(:deck, account:, name: "izzet")
      elves = create(:deck, account:, name: "Elves", format: "commander")
      kept = create_lot_in_zone(izzet, "main", entry: a, quantity: 2)
      lost = create_lot_in_zone(elves, "commander", entry: b, quantity: 1)
      stays = create_lot_in_zone(elves, "main", entry: c, quantity: 3)
      izzet_zones = izzet.zones.pluck(:id)
      elves_main = elves.zone("main").id
      elves_considering = elves.zone("considering").id
      preview_v4!([ import_row(a, quantity: 2, location: zone("Izzet")), import_row(c, quantity: 3, location: zone("Elves")) ],
        decks: [ deck_of("Izzet"), deck_of("Elves", "modern") ])

      expect(apply.outcome).to eq(:applied)

      expect(izzet.location.reload.name).to eq("Izzet")
      expect([ izzet.zones.pluck(:id), kept.reload.location_id ]).to eq([ izzet_zones, izzet_zones.first ])
      expect([ elves.reload.format, elves.location.name ]).to eq(%w[modern Elves])
      expect(elves.zones.pluck(:zone)).to eq(%w[main considering sideboard]) # the commander zone went; the sideboard came after the kept ones
      expect([ elves.zone("main").id, elves.zone("considering").id ]).to eq([ elves_main, elves_considering ])
      expect(Lot.exists?(lost.id)).to be(false) # the lot of the lost zone is among the removed lots
      expect(stays.reload.location_id).to eq(elves_main)
      expect(account.lots.joins(:location).where(locations: { zone: "considering" })).to be_empty # an import moves no lot into Considering
      expect_written_rows_valid
    end

    it "changes a deck's collectible type with its format, keeping the zones both formats have", :aggregate_failures do
      create(:deck, account:, name: "Elves")
      fake_vocabulary(%w[main Main], %w[considering Considering])
      preview_v4!([ import_row(a, location: nil) ], decks: [ deck_of("Elves", "f", type: "fake") ])

      expect(apply.outcome).to eq(:applied)
      deck = deck_named("Elves")
      expect([ deck.collectible_type, deck.format, deck.zones.pluck(:zone) ]).to eq([ "fake", "f", %w[main considering] ])
    end

    describe "a format that has changed since a deck was made (AC-8.2a)" do
      it "creates the missing zones and rewrites the names of those it has, so a lot naming the new zone is placed", :aggregate_failures do
        fake_vocabulary(%w[main Main], %w[considering Considering])
        deck = create(:deck, account:, name: "Fake deck", pair: "fake/f")
        fake_vocabulary(%w[main Mainboard], %w[extra Extra], %w[considering Considering]) # a release renamed Main and added Extra
        preview_v4!([ import_row(a, location: zone("Fake deck", "extra")) ], decks: [ deck_of("Fake deck", "f", type: "fake") ])

        expect(apply.outcome).to eq(:applied)

        expect(zones_of(deck)).to eq([ %w[main Mainboard mainboard], %w[considering Considering considering], %w[extra Extra extra] ])
        expect(account.lots.sole.location).to eq(deck.zone("extra"))
        expect_written_rows_valid
      end

      it "rewrites the names of two zones that swap them, never meeting in the name index", :aggregate_failures do
        fake_vocabulary(%w[main Main], %w[side Side], %w[considering Considering])
        deck = create(:deck, account:, name: "Fake deck", pair: "fake/f")
        fake_vocabulary(%w[main Side], %w[side Main], %w[considering Considering])
        preview_v4!([ import_row(a, location: zone("Fake deck", "side")) ], decks: [ deck_of("Fake deck", "f", type: "fake") ])

        expect(apply.outcome).to eq(:applied)
        expect(zones_of(deck)).to eq([ %w[main Side side], %w[side Main main], %w[considering Considering considering] ])
      end

      it "is never a change of its own: a file equal to the collection has nothing to change and the zone stays missing", :aggregate_failures do
        deck = create(:deck, account:, name: "Izzet Tempo")
        deck.zone("considering").destroy!
        data = import_file_v4(user, [], decks: [ deck_of("Izzet Tempo") ])
        expect(CollectionImport.new(account:, file: import_io(data)).plan.nothing_to_change?).to be(true)
        upload = store_import!(account:, data:, forced: true)
        before = snapshot

        expect(apply(upload).outcome).to eq(:nothing_to_change)
        expect(snapshot).to eq(before)
        expect(deck.zones.pluck(:zone)).to eq(%w[main sideboard])
      end

      it "is written with an apply that changes something else, the zones of a deck the file lists unchanged included", :aggregate_failures do
        deck = create(:deck, account:, name: "Izzet Tempo")
        deck.zone("considering").destroy!
        held_lot(account, a, quantity: 1)
        preview_v4!([ import_row(a, quantity: 2, location: nil) ], decks: [ deck_of("Izzet Tempo") ])

        expect(apply.outcome).to eq(:applied)
        expect(deck.zones.pluck(:zone)).to eq(%w[main sideboard considering])
      end
    end

    it "removes every removed place and deck before it writes any addition, so a place and a deck can swap names (AC-8.3)", :aggregate_failures do
      create(:location, account:, name: "Alpha")
      old = create(:deck, account:, name: "Beta")
      preview_v4!([ import_row(a, location: nil) ], locations: [ "Beta" ], decks: [ deck_of("Alpha") ])

      expect(apply.outcome).to eq(:applied)

      expect([ names(account.locations.places), names(account.locations.decks) ]).to eq([ [ "Beta" ], [ "Alpha" ] ])
      expect(Location.exists?(old.location_id)).to be(false)
      expect(account.decks.count).to eq(1)
      expect_written_rows_valid
    end

    it "moves a place's name to a deck and a deck's name to a place in one file, with all their lots placed (AC-8.3)", :aggregate_failures do
      box = create(:location, account:, name: "Box")
      deck = create(:deck, account:, name: "Izzet Tempo")
      held_lot(account, a, quantity: 1, location: box)
      create_lot_in_zone(deck, "main", entry: b, quantity: 1)
      preview_v4!([ import_row(a, location: zone("Box")), import_row(b, location: "Izzet Tempo") ], locations: [ "Izzet Tempo" ], decks: [ deck_of("Box") ])

      expect(apply.outcome).to eq(:applied)
      expect(account.lots.map { |lot| [ lot.catalog_entry_id, lot.location.label ] }).to contain_exactly([ a.id, "Box › Main" ], [ b.id, "Izzet Tempo" ])
      expect_written_rows_valid
    end

    it "places a lot in its zone with the key that carries it, never mistaking a place Main for a zone main or one deck's zone for another's (AC-8.4)", :aggregate_failures do
      preview_v4!([ import_row(a, location: "Main"), import_row(a, location: zone("Izzet Tempo")), import_row(a, location: zone("Elves")) ],
        locations: [ "Main" ], decks: [ deck_of("Izzet Tempo"), deck_of("Elves", "commander") ])

      expect(apply.outcome).to eq(:applied)

      expect(account.lots.map { |lot| lot.location.label }).to contain_exactly("Main", "Izzet Tempo › Main", "Elves › Main")
      account.lots.each do |lot|
        expect(lot.lot_key).to eq(Lot.key_for(lot.finish, lot.condition, lot.price_paid_cents, lot.location_id))
        expect(lot).to be_valid
      end
      expect(deck_named("Elves").zone("main").lots.sole.catalog_entry_id).to eq(a.id)
    end

    it "deletes a removed deck's lots before its zones and never moves a lot (AC-8.6)", :aggregate_failures do
      deck = create(:deck, account:, name: "Izzet Tempo")
      create_lot_in_zone(deck, "main", entry: a, quantity: 2)
      create_lot_in_zone(deck, "sideboard", entry: b, quantity: 1)
      kept = held_lot(account, c, quantity: 1)
      zone_ids = deck.zones.pluck(:id)
      preview_v4!([ import_row(c, location: nil) ])
      kept_before = kept.reload.attributes

      expect(apply.outcome).to eq(:applied)

      expect(Location.where(id: [ deck.location_id, *zone_ids ])).to be_empty
      expect(Deck.exists?(deck.id)).to be(false)
      expect(account.lots.pluck(:id)).to eq([ kept.id ])
      expect(kept.reload.attributes).to eq(kept_before)
    end

    it "clears a scanner sitting's place through the foreign key when a place goes, keeping the sitting and every other list (AC-8.6, AC-8.7)", :aggregate_failures do
      removal = working_state_for(held_lot(account, a, quantity: 2))
      Scanner::Sitting.sole.update!(location: create(:location, account:, name: "Old crate"))
      preview_v4!([ import_row(a, quantity: 2, location: nil) ], decks: [ deck_of("Izzet Tempo") ])

      expect(apply.outcome).to eq(:applied)

      expect(account.locations.places).to be_empty
      expect([ NumberEntry.count, Scanner::Sitting.count, BulkSelection.count, BulkSelection::Mark.count ]).to eq([ 1, 1, 1, 1 ])
      expect(Scanner::Sitting.sole.location_id).to be_nil
      expect(removal.reload).to be_undoable
    end

    it "clears the working state only when it writes a lot, a deck change alone leaving it (AC-8.7)", :aggregate_failures do
      removal = working_state_for(held_lot(account, a, quantity: 2))
      create(:deck, account:, name: "Old deck")
      preview_v4!([ import_row(a, quantity: 2, location: nil) ], decks: [ deck_of("Izzet Tempo") ])

      expect(apply.outcome).to eq(:applied)
      expect([ NumberEntry.count, Scanner::Sitting.count, BulkSelection.count ]).to eq([ 1, 1, 1 ])
      expect(removal.reload).to be_undoable

      preview_v4!([ import_row(a, quantity: 5, location: nil) ], decks: [ deck_of("Izzet Tempo") ])
      expect(apply.outcome).to eq(:applied)
      expect(NumberEntry.count + Scanner::Sitting.count + BulkSelection.count).to eq(0)
    end

    it "leaves the decks and their zones of an older file's account as they are and removes the copies in them, with the confirmation (AC-7.4)", :aggregate_failures do
      deck = create(:deck, account:, name: "Izzet Tempo")
      box = create(:location, account:, name: "Main") # a place called Main beside a zone main
      create_lot_in_zone(deck, "main", entry: a, quantity: 2)
      held_lot(account, b, quantity: 1, location: box)
      zones = deck.zones.pluck(:id, :name)
      store_import!(account:, data: import_file_v3(user, [ import_row(b, location: "Main"), import_row(c, location: "Main") ], locations: [ "Main" ]))

      expect(apply(confirmed: false).outcome).to eq(:unconfirmed)
      expect(apply.outcome).to eq(:applied)

      expect(deck.reload.zones.pluck(:id, :name)).to eq(zones)
      expect(names(account.locations.decks)).to eq([ "Izzet Tempo" ])
      expect(account.lots.map { |lot| [ lot.catalog_entry_id, lot.location.label ] }).to contain_exactly([ b.id, "Main" ], [ c.id, "Main" ])
    end

    describe "an older file against decks that came after the preview (AC-7.4d)" do
      def bulk_decks(count)
        now = Time.current
        Location.insert_all!(Array.new(count) { |n| { account_id: account.id, kind: "deck", name: "Deck #{n}", name_key: "deck #{n}", created_at: now, updated_at: now } })
        Deck.insert_all!(account.locations.decks.pluck(:id).map { |id| { account_id: account.id, location_id: id, collectible_type: "mtg", format: "modern", created_at: now, updated_at: now } })
      end

      # Runs the block when the moment comes: at once (before `call` reads anything) or when the apply's transaction opens, after
      # `call` read the upload and judged it (the window only the transaction's own judgement covers).
      def when_the(moment, &arrange)
        return arrange.call if moment == :before_call

        allow(ImportUpload).to receive(:transaction).and_wrap_original do |original, *args, &block|
          arrange.call
          original.call(*args, &block)
        end
      end

      %i[before_call inside_call].each do |moment|
        it "refuses with the preview's reason when a deck is made with a file place's name (#{moment}), removing the upload and writing nothing", :aggregate_failures do
          upload = store_import!(account:, data: import_file_v3(user, [ import_row(a, location: nil) ], locations: [ "Izzet Tempo", "Box" ]))
          when_the(moment) { create(:deck, account:, name: "izzet tempo") }
          before = snapshot

          result = apply(upload)

          expect([ result.outcome, result.import.refusal.rule ]).to eq([ :refused, "deck_name_taken" ])
          expect(result.import.refusal.reason).to eq("A deck you have is called “izzet tempo”, like a place in this file. Rename one of them and preview again.")
          expect(snapshot.except("locations", "decks")).to eq(before.except("locations", "decks")) # the deck made after the preview is the one thing new
          expect(names(account.locations.top_level)).to eq([ "izzet tempo" ])
          expect(ImportUpload.count).to eq(0)
        end

        it "refuses when the decks made after the preview take the file's places past 500 (#{moment})", :aggregate_failures do
          upload = store_import!(account:, data: import_file_v3(user, [ import_row(a, location: nil) ], locations: Array.new(450) { |n| "Binder #{n}" }))
          when_the(moment) { bulk_decks(51) }

          result = apply(upload)

          expect([ result.outcome, result.import.refusal.rule ]).to eq([ :refused, "too_many_with_decks" ])
          expect(account.locations.places).to be_empty
          expect(account.lots).to be_empty
          expect(ImportUpload.count).to eq(0)
        end
      end

      it "applies a version 2 file when a deck made after the preview collides with nothing", :aggregate_failures do
        upload = store_import!(account:, data: import_file_v2(user, [ import_row(a) ], locations: [ "Box" ]))
        create(:deck, account:, name: "Izzet Tempo")

        expect(apply(upload).outcome).to eq(:applied)
        expect([ names(account.locations.places), names(account.locations.decks) ]).to eq([ [ "Box" ], [ "Izzet Tempo" ] ])
      end
    end

    describe "statements (AC-8.9)" do
      include QueryCounting

      # +decks+ held decks, half renamed and given another format by the file, half removed, and as many added.
      def statements_for(decks)
        other = create(:user)
        decks.times { |n| create(:deck, account: other.account, name: "held #{n}") }
        file = Array.new(decks / 2) { |n| deck_of("HELD #{n}", "commander") } + Array.new(decks / 2) { |n| deck_of("New #{n}") }
        upload = store_import!(account: other.account, data: import_file_v4(other, [ import_row(import_printing, location: nil) ], decks: file))
        count_queries { apply(upload, for_account: other.account) }.tap do
          expect(other.account.decks.joins(:location).pluck("locations.name").sort).to eq(file.pluck("name").sort) # it wrote them
        end
      end

      # +decks+ decks of a format that a release changed: every one lacks a zone and has a zone to rename; the file lists them all.
      def repair_statements_for(decks)
        other = create(:user)
        fake_vocabulary(%w[main Main], %w[considering Considering])
        decks.times { |n| create(:deck, account: other.account, name: "held #{n}", pair: "fake/f") }
        fake_vocabulary(%w[main Mainboard], %w[extra Extra], %w[considering Considering])
        file = Array.new(decks) { |n| deck_of("held #{n}", "f", type: "fake") }
        upload = store_import!(account: other.account, data: import_file_v4(other, [ import_row(import_printing, location: nil) ], decks: file))
        count_queries { apply(upload, for_account: other.account) }.tap do
          expect(other.account.locations.zones_of_decks.pluck(:zone, :name).tally).to eq([ %w[main Mainboard], %w[extra Extra], %w[considering Considering] ].to_h { |pair| [ pair, decks ] }) # it repaired them
        end
      end

      it "runs the same statements for 2 decks as for 40, every kind of change among them" do
        expect(statements_for(40)).to eq(statements_for(2))
      end

      it "runs the same statements to repair the zones of 2 decks as of 40" do
        expect(repair_statements_for(40)).to eq(repair_statements_for(2))
      end
    end
  end
end
