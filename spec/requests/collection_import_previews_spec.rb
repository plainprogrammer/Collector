require "rails_helper"

# Spec 025: the import preview's pages. A collector uploads an export file and sees what applying it would do.
RSpec.describe "Import preview", type: :request do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }

  def printing(**entry) = create(:mtg_printing, entry: create(:catalog_entry, **entry)).entry

  def row(entry, quantity: 1, **fields)
    { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                   "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
      "quantity" => quantity, "finish" => nil, "condition" => nil, "price_paid" => nil,
      "added_at" => "2026-10-01T10:00:00Z", "changed_at" => "2026-10-01T10:00:00Z" }.merge(fields.stringify_keys)
  end

  def stranger = row(build(:catalog_entry, external_key: "not-#{SecureRandom.hex(4)}"))

  def file(lots, **fields)
    { "format" => "collector-export", "format_version" => 1, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => "grid" },
      "currency" => "USD", "lots" => lots }.merge(fields.stringify_keys)
  end

  def upload(data, type: "application/json", name: "export.json")
    Rack::Test::UploadedFile.new(StringIO.new(data.is_a?(String) ? data : JSON.generate(data)), type, original_filename: name)
  end

  def preview(data, **options) = post(collection_import_preview_path, params: { export_file: upload(data, **options) })

  def html = Nokogiri::HTML5(response.body)

  def stat(label) = html.css(".c-stat").find { |stat| stat.at_css("dt").text == label }.then { |stat| [ stat.at_css("dd").text, stat.at_css("small").text ] }

  # Every table's row count, and its newest updated_at where it has one (AC-1.8).
  def snapshot
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).sort.to_h do |table|
      quoted = connection.quote_table_name(table)
      newest = connection.column_exists?(table, :updated_at) ? connection.select_value("SELECT MAX(updated_at) FROM #{quoted}") : nil
      [ table, [ connection.select_value("SELECT COUNT(*) FROM #{quoted}"), newest ] ]
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "offers the upload form, outside Turbo (AC-1.1)", :aggregate_failures do
      get new_collection_import_preview_path
      form = html.at_css("form.c-form")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect([ form["action"], form["method"], form["enctype"], form["data-turbo"] ]).to eq([ collection_import_preview_path, "post", "multipart/form-data", "false" ])
      expect(form.at_css("input[type=file][name=export_file]")["accept"]).to eq(".json,application/json")
      expect(form.at_css("input[type=submit]")["value"]).to eq("Preview import")
      expect(form.at_css("label[for=export_file]").text).to eq("Export file")
    end

    it "puts the CSRF token in the upload form (AC-1.1)" do
      ActionController::Base.allow_forgery_protection = true
      get new_collection_import_preview_path

      expect(html.at_css("form.c-form input[name=authenticity_token]")).to be_present
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "shows what applying the file would do (AC-1.2)", :aggregate_failures do
      a, b, c, d, e = Array.new(5) { printing }
      { a => 3, b => 2, c => 4 }.each { |entry, quantity| create(:lot, account: user.account, entry:, quantity:, created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10)) }
      create(:lot, account: user.account, entry: d, quantity: 7)
      preview(file([ row(a, quantity: 3), row(b, quantity: 5), row(c, quantity: 4, changed_at: "2026-10-02T10:00:00Z"), row(e, quantity: 6) ]))

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(html.at_css("h1").text).to eq("Import preview")
      expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Exported 2026-10-15 09:00 UTC · 4 rows · USD")
      expect(html.at_css(".c-import .c-status__message").text.squish).to eq("This file can be applied. Previewing changed nothing in your collection.")
      expect([ stat("Lots added"), stat("Lots changed"), stat("Lots unchanged"), stat("Lots removed") ])
        .to eq([ [ "1", "6 copies" ], [ "2", "6 copies become 9" ], [ "1", "3 copies" ], [ "1", "7 copies" ] ])
      expect(html.css("#removed_lots li").map { |item| item.text.squish }).to eq([ "#{d.name} #{d.set.code.upcase} · #{d.number} · EN ×7" ])
      expect(html.at_css("#held_lots").text).to eq("Held by rows with problems: 0 lots, 0 copies.")
      expect(html.at_css("#problem_rows")).to be_nil
    end

    it "lists each row that can't be applied, with its reasons and counts (AC-2.1)", :aggregate_failures do
      known = printing(name: "Serra Angel", number: "27", set: create(:catalog_set, code: "dmr"))
      preview(file([ row(known, finish: "etched", condition: "mint", price_paid: "12.50"), stranger ]))

      expect(html.at_css(".c-import .c-status__message--alert").text.squish)
        .to eq("This file can't be applied: 2 rows have problems. Previewing changed nothing in your collection.")
      expect(html.css("#problem_rows > li").first.text.squish)
        .to eq("Row 1 Serra Angel DMR · 27 · EN · Etched · Mint · $12.50 This printing doesn't come in etched mint isn't a condition this instance knows")
      expect(html.css("#problem_counts li").map { |item| item.text.squish })
        .to eq([ "This printing doesn't come in etched 1 row", "mint isn't a condition this instance knows 1 row", "Not in this instance's catalog 1 row" ])
    end

    it "lists the first 100 rows with problems, then says how many more (AC-2.8)", :aggregate_failures do
      preview(file(Array.new(150) { stranger }))

      expect(html.css("#problem_rows > li").size).to eq(100)
      expect(html.at_css("#problem_rows + .c-import__more").text).to eq("and 50 more")
    end

    it "lists the first 100 removed lots, then says how many more (AC-2.8)", :aggregate_failures do
      entry = printing
      150.times { |index| create(:lot, account: user.account, entry:, price_paid_cents: index) }
      preview(file([]))

      expect(html.css("#removed_lots > li").size).to eq(100)
      expect(html.at_css("#removed_lots + .c-import__more").text).to eq("and 50 more")
    end

    it "shows the catalog notice for an unloaded type the file names (AC-2.6)", :aggregate_failures do
      preview(file([ stranger ]))
      expect(html.at_css("#catalog_not_loaded")).to be_present

      create(:catalog_refresh_run, collectible_type: "mtg", status: "applied")
      preview(file([ stranger ]))
      expect(html.at_css("#catalog_not_loaded")).to be_nil
    end

    it "shows what the profile would change, and only then (AC-1.7)", :aggregate_failures do
      preview(file([], profile: { "name" => "Ada Example", "email_address" => "ada@example.test", "collection_view" => "table" }))
      expect(html.css("#profile_notes li").map { |item| item.text.squish }).to eq([
        "Your collection view would change to table.", "The file's name is Ada Example. Importing won't change yours.",
        "The file's email address is ada@example.test. Importing won't change yours." ])

      preview(file([]))
      expect(html.at_css("#profile_notes")).to be_nil
    end

    it "refuses a file it can't read, showing the upload form again with the reason (AC-3.1)", :aggregate_failures do
      {
        nil => "Choose an export file to preview.",
        "{" => "This file isn't a Collector export: it isn't readable JSON.",
        file([], format_version: 2) => "This file was written by a newer version of Collector (format version 2). This instance reads version 1.",
        file([], currency: "EUR") => "This file's prices are in EUR. This instance uses USD."
      }.each do |data, reason|
        data.nil? ? post(collection_import_preview_path, params: { export_file: "a pasted file" }) : preview(data)
        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css(".c-field--invalid .c-field__error")&.text).to eq(reason)
        expect(html.at_css("input[type=file]")["aria-describedby"]).to eq("export_file_error")
        expect(html.at_css(".c-stats, #problem_rows")).to be_nil
      end
      post collection_import_preview_path
      expect(html.at_css(".c-field__error")&.text).to eq("Choose an export file to preview.")
    end

    it "judges a file by its content, not its declared type or name (AC-3.5)", :aggregate_failures do
      preview(file([]), type: "image/png", name: "cards.txt")
      expect(response).to have_http_status(:ok)

      preview("not json at all", type: "application/json")
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "still writes nothing and queues nothing for a file with problem rows (AC-1.8, narrowed by spec 028 decision 10)", :aggregate_failures do
      entry = printing
      create(:lot, account: user.account, entry:, quantity: 2)
      data = file([ row(entry, quantity: 5), row(printing), stranger ])
      before = snapshot

      expect { preview(data) }.not_to have_enqueued_job
      expect(snapshot).to eq(before)
    end

    it "runs as many queries for 30 rows as for 2 (AC-1.9)" do
      few = Array.new(2) { row(printing) }
      many = Array.new(30) { row(printing) }
      preview(file(few)) # an earlier stored upload exists for both counted previews, which replace it

      expect(count_queries { preview(file(many)) }).to eq(count_queries { preview(file(few)) })
    end

    it "compares the file with this collector's lots only (AC-4.1)", :aggregate_failures do
      shared = printing
      other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
      create(:lot, account: other.account, entry: shared, quantity: 7_919, price_paid_cents: 7_919)
      create(:lot, account: other.account, entry: printing)
      preview(file([ row(shared) ]))

      expect([ stat("Lots added").first, stat("Lots removed").first ]).to eq(%w[1 0])
      expect(response.body).not_to include("7,919", "79.19", "Zebulon Otherperson", "zebulon.otherperson@example.test")
    end

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
        expect(response.body).to include("removes 1 lot", "can't be undone", "kept for an hour")
      end

      it "puts the CSRF token in the apply form (FR-5)" do
        ActionController::Base.allow_forgery_protection = true
        get new_collection_import_preview_path
        token = html.at_css("meta[name=csrf-token]")["content"]
        post collection_import_preview_path, params: { export_file: upload(file([ row(entry) ])) }, headers: { "X-CSRF-Token" => token }

        expect(form.at_css("input[name=authenticity_token]")).to be_present
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it "needs no checkbox when nothing is removed (AC-3.5)" do
        preview(file([ row(entry) ]))

        expect(form.at_css("input[name=confirm_removal]")).to be_nil
      end

      it "stores nothing for a file with problems, a refused file or a file with nothing to change (AC-1.1, AC-1.11)", :aggregate_failures do
        create(:lot, account: user.account, entry:, quantity: 1, created_at: Time.utc(2026, 10, 1, 10), updated_at: Time.utc(2026, 10, 1, 10))
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
        data = file([ row(entry) ])
        before = snapshot
        expect { preview(data) }.not_to have_enqueued_job
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
        expect(response.body).to include("couldn't be kept")
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

    it "previews the format's empty example, in its own currency, as nothing to change with no apply offered (AC-6.4)", :aggregate_failures do
      allow(Rails.configuration.x).to receive(:currency).and_return(Collector::Currency.fetch!("EUR"))
      bytes = ExportFormatRules.examples("valid").fetch("valid/empty.json")

      post collection_import_preview_path, params: { export_file: import_upload_file(bytes) }

      expect(response).to have_http_status(:ok) # not refused as another currency
      expect(response.body).to include("nothing to change")
      expect(html.css("form[action='#{collection_import_path}']")).to be_empty
      expect(ImportUpload.count).to eq(0)
    end
  end

  context "when signed out" do
    it "sends a visitor to sign in from either page, reading no file (AC-4.2)", :aggregate_failures do
      user
      allow(CollectionImport).to receive(:new).and_call_original

      get new_collection_import_preview_path
      expect(response).to redirect_to(new_session_path)

      sign_in_as(user)
      user.sessions.destroy_all
      preview(file([]))
      expect(response).to redirect_to(new_session_path)
      expect(CollectionImport).not_to have_received(:new)
    end
  end

  it "keeps the uploaded field out of the logs (FR-6)" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("export_file" => "a pasted file")).to eq("export_file" => "[FILTERED]")
  end
end
