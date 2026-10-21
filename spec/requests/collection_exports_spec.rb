require "rails_helper"

# Spec 022: GET /collection/export sends the signed-in collector's collection as a file, and nobody else's.
RSpec.describe "Collection export", type: :request do
  let(:user) { create(:user, name: "Grace Example", email_address: "grace@example.test") }

  def printing = create(:mtg_printing).entry

  context "when signed in" do
    before { sign_in_as(user) }

    it "sends a well-formed file as an attachment that isn't cached", :aggregate_failures do
      create(:lot, account: user.account, entry: printing, finish: "foil", price_paid_cents: 1250)
      travel_to(Time.utc(2026, 10, 14, 23, 59, 59)) { get collection_export_path }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Content-Disposition"]).to start_with('attachment; filename="collector-export-2026-10-14.json"')
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(ExportFormatRules.problems(response.body)).to eq([])
      expect(JSON.parse(response.body)["exported_at"]).to eq("2026-10-14T23:59:59Z")
    end

    it "sends only the signed-in collector's account", :aggregate_failures do
      shared = printing
      create(:lot, account: user.account, entry: shared, quantity: 2)
      other = create(:user, name: "Zebulon Otherperson", email_address: "zebulon.otherperson@example.test")
      create(:lot, account: other.account, entry: shared, quantity: 8_888, price_paid_cents: 77_777)
      create(:lot, account: other.account, entry: printing)

      get collection_export_path
      file = JSON.parse(response.body)

      expect(file["profile"]["email_address"]).to eq("grace@example.test")
      expect(file["lots"].map { |lot| [ lot["entry"]["source_id"], lot["quantity"] ] }).to eq([ [ shared.external_key, 2 ] ])
      expect(file["lots"].map { |lot| lot.values_at("quantity", "price_paid") }.flatten).not_to include(8_888, "777.77")
      expect(response.body).not_to include("Zebulon Otherperson", "zebulon.otherperson@example.test")
    end

    it "answers no format suffix" do
      get "/collection/export.json"

      expect(response).to have_http_status(:not_found)
    end

    it "sends an empty collection as a file with no lots" do
      get collection_export_path

      expect(JSON.parse(response.body)["lots"]).to eq([])
    end

    it "runs as many queries for 30 lots as for 2" do
      2.times { create(:lot, account: user.account, entry: printing) }
      few = count_queries { get collection_export_path }
      28.times { create(:lot, account: user.account, entry: printing) }

      expect(count_queries { get collection_export_path }).to eq(few)
    end

    it "sends this account's locations and no other account's (AC-6.7)", :aggregate_failures do
      create(:location, account: user.account, name: "Blue binder")
      create(:location, name: "Zebulon's crate")

      get collection_export_path

      expect(JSON.parse(response.body)["locations"]).to eq([ { "name" => "Blue binder" } ])
      expect(response.body).not_to include("Zebulon")
    end

    it "runs as many queries for 30 locations as for 2 (NFR)" do
      2.times { create(:location, account: user.account) }
      few = count_queries { get collection_export_path }
      28.times { create(:location, account: user.account) }

      expect(count_queries { get collection_export_path }).to eq(few)
    end
  end

  context "when signed out" do
    it "sends the visitor to sign in, with no file, and lands them on the collection afterwards", :aggregate_failures do
      user # an instance with a user, or FirstRun sends the visitor to sign up
      get collection_export_path
      expect(response).to redirect_to(new_session_path)
      expect(response.media_type).not_to eq("application/json")

      sign_in_as(user)
      expect(response).to redirect_to(collection_path)
    end

    it "keeps a page an earlier request stored as the one to return to" do
      user
      get catalog_entries_path
      get collection_export_path

      sign_in_as(user)
      expect(response).to redirect_to(catalog_entries_path)
    end
  end
end
