require "rails_helper"

# Spec 070 AC-5.3: a collection after a replacement exports and restores on a fresh account as the same collection, the same
# deck page's counts included.
RSpec.describe "Export and import after replacing a proxy", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let(:target) { create(:user, name: "Target", email_address: "target@example.test") }
  let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }

  def export(user, at: Time.utc(2026, 11, 11, 12)) = JSON.parse(CollectionExport.new(account: user.account, at:).to_json)

  def same_collection?(one, other)
    ExportFormatRules.same_collection?(one.merge("profile" => one["profile"].except("name", "email_address")),
      other.merge("profile" => other["profile"].except("name", "email_address")))
  end

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  it "restores the deck with the lowered proxy and the moved copies as the same collection", :aggregate_failures do
    deck = create(:deck, account: source.account, name: "Izzet Tempo")
    proxy = create(:deck_proxy, zone: deck.zone("main"), account: source.account, entry:, finish: "foil", quantity: 3)
    lot = create(:lot, account: source.account, entry:, location: create(:location, account: source.account, name: "Blue binder"), quantity: 2, finish: "foil")
    Deck::Proxy::UseCopies.new(proxy:, typed: { lot.id.to_s => "2" }, shown: { lot.id.to_s => "2" }).save

    original = export(source)
    apply!(target, original)

    expect(original["proxies"].map { it["quantity"] }).to eq([ 1 ])
    expect(same_collection?(original, export(target))).to be(true)
    restored = Deck::Page.new(target.account.decks.includes(:location).sole)
    expect([ restored.owned, restored.proxy ]).to eq([ 2, 1 ])
  end
end
