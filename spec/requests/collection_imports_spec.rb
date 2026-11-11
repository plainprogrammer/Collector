require "rails_helper"

# Spec 028: applying the stored upload.
RSpec.describe "Apply an import", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:a) { import_printing }
  let(:b) { import_printing }

  def preview!(lots) = store_import!(account:, data: import_file(user, lots))
  def preview_v3!(lots, locations: []) = store_import!(account:, data: import_file_v3(user, lots, locations:))
  def preview_v2!(lots, locations: []) = store_import!(account:, data: import_file_v2(user, lots, locations:))
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

    it "answers 409 when the currency changed after the preview, saying the new change (spec 038 AC-6.7)", :aggregate_failures do
      upload = store_import!(account:, data: import_file(user, [ import_row(a) ], currency: "EUR"))
      patch currency_path, params: { account: { currency: "GBP" } } # the Currency page, in another tab

      apply(upload)

      expect(response).to have_http_status(:conflict)
      expect(html.css("#profile_notes li").map { |item| item.text.squish }).to include("Your prices would be shown in EUR instead of GBP. Nothing is converted.")
      expect(html.at_css("input[name=fingerprint]")["value"]).to eq(upload.reload.fingerprint)
      expect(account.reload.currency).to eq("GBP")
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
      Catalog::Entry.find(a.id).update_columns(external_key: "moved")

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

    it "adds the locations to the notice, with no final period (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "box")
      create(:location, account:, name: "Old crate")
      preview_v2!([ import_row(a) ], locations: [ "Box", "Blue binder", "Trade binder" ])

      apply
      follow_redirect!

      expect(response.body).to include("Imported: 1 lot added, 0 changed, 0 removed; 2 locations added, 1 renamed, 1 removed")
      expect(html.at_css("#status").text.strip).not_to end_with(".") # never a final period (ruled 2026-10-21)
    end

    it "names only the location parts that are not zero, but keeps the zero lot parts, after a version 2 file that changes only locations (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      preview_v2!([], locations: [])

      apply
      follow_redirect!
      expect(html.at_css("#status").text.strip).to eq("Imported: 0 lots added, 0 changed, 0 removed; 1 location removed")
    end

    it "says the prices' new currency last, after a currency-only file and after locations (spec 038 AC-6.3)", :aggregate_failures do
      store_import!(account:, data: import_file(user, [], currency: "EUR"))
      apply
      follow_redirect!
      expect(html.at_css("#status").text.strip).to eq("Imported: 0 lots added, 0 changed, 0 removed; prices now shown in EUR")

      create(:location, account: account.reload, name: "Old crate") # reloaded: the apply changed the account's currency
      store_import!(account:, data: import_file_v2(user, [ import_row(a) ], locations: [ "Box" ], currency: "GBP"))
      apply
      follow_redirect!
      expect(html.at_css("#status").text.strip).to eq("Imported: 1 lot added, 0 changed, 0 removed; 1 location added, 1 removed; prices now shown in GBP")
      expect(account.reload.currency).to eq("GBP")
    end

    describe "the decks in the notice (spec 062 AC-8.8)" do
      def preview_v4!(lots, decks: [], locations: [], **fields) = store_import!(account:, data: import_file_v4(user, lots, decks:, locations:, **fields))

      def deck_of(name, format) = { "name" => name, "collectible_type" => "mtg", "format" => format }

      it "adds the decks after the locations and before the currency, zero parts left out, no final period", :aggregate_failures do
        create(:location, account:, name: "box")
        create(:location, account:, name: "Old crate")
        %w[tempo Elves Gone Same].each { |name| create(:deck, account:, name:) }
        preview_v4!([ import_row(a, location: nil) ], locations: [ "Box", "Blue binder", "Trade binder" ], currency: "EUR",
          decks: [ "Tempo", deck_of("Elves", "commander"), deck_of("Same", "modern"), deck_of("New", "modern"), deck_of("Newer", "modern") ])

        apply
        follow_redirect!

        expect(html.at_css("#status").text.strip).to eq(
          "Imported: 1 lot added, 0 changed, 0 removed; 2 locations added, 1 renamed, 1 removed; " \
          "2 decks added, 1 renamed, 1 format changed, 1 removed; prices now shown in EUR")
        expect(account.decks.joins(:location).order("locations.name_key").pluck("locations.name", :format)).to eq(
          [ %w[Elves commander], %w[New modern], %w[Newer modern], %w[Same modern], %w[Tempo modern] ])
      end

      it "names the one part that is not zero, with the noun on it", :aggregate_failures do
        create(:deck, account:, name: "Gone")
        held_lot(account, a, quantity: 1)
        preview_v4!([ import_row(a, location: nil) ])

        apply
        follow_redirect!

        expect(html.at_css("#status").text.strip).to eq("Imported: 0 lots added, 0 changed, 0 removed; 1 deck removed")
      end

      it "refuses an older file with its reason when a deck made after the preview has a file place's name, writing nothing (AC-7.4d)", :aggregate_failures do
        upload = preview_v3!([ import_row(a, location: nil) ], locations: [ "Izzet Tempo" ])
        create(:deck, account:, name: "izzet tempo")

        apply(upload)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("A deck you have is called “izzet tempo”, like a place in this file. Rename one of them and preview again.")
        expect(account.reload.import_upload).to be_nil
        expect([ account.lots.count, account.locations.places.count ]).to eq([ 0, 0 ])
      end

      it "says nothing about decks after a version 3 file, which leaves them alone", :aggregate_failures do
        create(:deck, account:, name: "Izzet Tempo")
        preview_v3!([ import_row(a, location: nil) ])

        apply
        follow_redirect!

        expect(html.at_css("#status").text.strip).to eq("Imported: 1 lot added, 0 changed, 0 removed")
      end
    end

    it "says nothing about locations after a version 1 file (AC-9.14)", :aggregate_failures do
      create(:location, account:, name: "Box")
      preview!([ import_row(a) ])

      apply
      follow_redirect!

      expect(html.at_css("#status").text.strip).to eq("Imported: 1 lot added, 0 changed, 0 removed")
    end

    it "answers 409 with a fresh preview, locations included, when a location changed after the preview (AC-9.9)", :aggregate_failures do
      upload = preview_v2!([ import_row(a) ], locations: [ "Blue binder" ])
      create(:location, account:, name: "Late")

      apply(upload)

      expect(response).to have_http_status(:conflict)
      expect(html.at_css("#locations")).to be_present
      expect(html.css("#removed_locations li").map { |item| item.text.squish }).to eq([ "Late" ])
      expect(html.at_css("input[name=fingerprint]")["value"]).not_to eq(upload.fingerprint)
      expect(account.locations.pluck(:name)).to eq([ "Late" ])
    end

    it "asks for the confirmation when only locations are removed, and writes nothing without it (AC-9.10)", :aggregate_failures do
      create(:location, account:, name: "Old crate")
      upload = preview_v2!([ import_row(a) ], locations: [])

      apply(upload, confirm_removal: "0")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirm the removal to apply this file", "I understand this removes 1 location")
      expect(account.locations.count).to eq(1)
    end

    it "shows nothing of another account's locations in any response (AC-9.13)", :aggregate_failures do
      create(:location, name: "Zebulon's crate")
      create(:location, account:, name: "Mine")
      upload = preview_v2!([ import_row(a) ], locations: [ "Mine", "New" ])
      create(:location, account:, name: "Late")

      apply(upload) # 409
      conflict = response.body
      apply(account.reload.import_upload) # 303
      follow_redirect!

      [ conflict, response.body ].each { |body| expect(body).not_to include("Zebulon") }
    end
  end

  it "sends a visitor to sign in without reading anything (AC-4.3)", :aggregate_failures do
    user # an instance with an account, or the first-run redirect comes first
    allow(CollectionImport).to receive(:new)

    post collection_import_path, params: { fingerprint: "x" }

    expect(response).to redirect_to(new_session_path)
    expect(CollectionImport).not_to have_received(:new)
  end
end
