require "rails_helper"

# NFR: a page's database work is bounded by the page, not by how much the collector owns or how
# many results it shows. Each page is loaded with little and with a lot of data and must run the
# same number of queries (an N+1 would add one per row).
RSpec.describe "Page query counts", type: :request do
  let(:user) { create(:user) }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

  before { sign_in_as(user) }

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    expect(response).to have_http_status(:ok)
    count
  end

  def printing(identity: create(:catalog_identity, name: "Lightning Bolt"), **attributes)
    create(:mtg_printing, entry: create(:catalog_entry, identity:, name: identity.name, **attributes)).entry
  end

  def own(entry, **attributes) = create(:lot, account: user.account, entry:, **attributes)

  it "keeps the collection page's queries independent of the number of lots" do
    own(printing, finish: "foil")
    few = queries_for(collection_path)
    29.times { |n| own(printing, finish: n.even? ? "foil" : "nonfoil") }
    expect(queries_for(collection_path)).to eq(few)
  end

  it "keeps search's queries independent of the number of result groups" do
    own(printing)
    printing(identity: Catalog::Identity.sole)
    few = queries_for(catalog_entries_path(q: "bolt"))
    11.times do
      entry = printing
      own(entry)
      printing(identity: entry.identity, language: "ja", localized_name: "稲妻")
    end
    expect(queries_for(catalog_entries_path(q: "bolt"))).to eq(few)
  end

  it "keeps the card page's queries independent of the number of lots" do
    entry = printing(identity:)
    # The first lot is of another printing: a lone lot of the page's own printing lets Rails reuse the
    # already-loaded set, which saves one query without saying anything about scaling.
    own(printing(identity:))
    few = queries_for(catalog_entry_path(entry))
    7.times { |n| own(entry, price_paid_cents: 100 * (n + 1)) }
    7.times { own(printing(identity:), finish: "foil", condition: "near_mint") }
    expect(queries_for(catalog_entry_path(entry))).to eq(few)
  end
end
