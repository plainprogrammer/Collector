require "rails_helper"

# Spec 068 Story 7: previewing and applying a file with proxies, through the pages, the round trip and the stale preview.
RSpec.describe "Importing proxies", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:deck) { create(:deck, account:, name: "Izzet Tempo") }
  let(:entry) { create(:mtg_printing).entry }

  def html = Nokogiri::HTML5(response.body)
  def export(account: self.account) = CollectionExport.new(account:, at: Time.utc(2026, 11, 11)).to_h
  def preview(data) = post(collection_import_preview_path, params: { export_file: import_upload_file(JSON.generate(data)) })
  def apply(confirm: false) = post(collection_import_path, params: { fingerprint: account.reload.import_upload.fingerprint, confirm_removal: (confirm ? "1" : nil) }.compact)
  def entry_hash(entry) = { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name, "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language }

  # Signs the first collector out and a new one in; returns the new user.
  def switch_to_new_collector
    create(:user).tap do |other|
      delete session_path
      sign_in_as(other)
    end
  end

  before { sign_in_as(user) }

  it "restores a collection's proxies into a fresh account, and the second export is the same collection (AC-7.4)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry:, finish: "nonfoil", quantity: 1)
    create_lot_in_zone(deck, "main", entry:, quantity: 4)
    first = export
    other_user = switch_to_new_collector

    preview(first)
    expect(response).to have_http_status(:ok)
    post collection_import_path, params: { fingerprint: other_user.account.reload.import_upload.fingerprint }
    expect(response).to have_http_status(:see_other)

    second = export(account: other_user.account)
    expect(second["proxies"]).to eq(first["proxies"])
    expect(ExportFormatRules.same_collection?(first, second.merge("profile" => first["profile"], "currency" => first["currency"]))).to be(true)
    preview(second)
    expect(response).to have_http_status(:ok)
    expect(html.text).to include("This file has nothing to change")
  end

  it "previews a Proxies section with the four counts and the removed list, and asks for the confirmation naming proxies (AC-7.7, AC-7.9)", :aggregate_failures do
    held = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    gone = create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry: create(:mtg_printing).entry, quantity: 3)
    data = export.merge("proxies" => [ export["proxies"].find { it["zone"] == "main" }.merge("quantity" => 5) ])

    preview(data)

    expect(response).to have_http_status(:ok)
    stats = html.css("#proxies .c-stat").to_h { [ it.at_css("dt").text, it.at_css("dd").text ] }
    expect(stats).to eq("Proxies added" => "0", "Proxies changed" => "1", "Proxies unchanged" => "0", "Proxies removed" => "1")
    expect(html.at_css("#removed_proxies li").text).to include(gone.entry.name, "Izzet Tempo › Sideboard", "×3")
    expect(html.at_css("label.c-check").text).to include("I understand this removes 1 proxy")
    expect(held.reload.quantity).to eq(2) # a preview writes nothing
  end

  it "refuses an apply without the box, and applies with it, writing and removing the proxies (AC-7.9, AC-7.10)", :aggregate_failures do
    kept = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    gone = create(:deck_proxy, zone: deck.zone("sideboard"), account:, entry: create(:mtg_printing).entry, quantity: 3)
    fresh = create(:mtg_printing).entry
    data = export.merge("proxies" => [ export["proxies"].find { it["zone"] == "main" }.merge("quantity" => 5),
                                       { "deck" => "Izzet Tempo", "zone" => "considering", "entry" => entry_hash(fresh), "finish" => nil, "quantity" => 1 } ])
    preview(data)

    apply
    expect(response).to have_http_status(:unprocessable_content)
    expect(Deck::Proxy.count).to eq(2)

    apply(confirm: true)

    expect(response).to redirect_to(collection_path)
    expect(flash[:notice]).to eq("Imported: 0 lots added, 0 changed, 0 removed; 1 proxy added, 1 changed, 1 removed")
    expect(kept.reload.quantity).to eq(5) # the same row: its id survives
    expect { gone.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(Deck::Proxy.where(catalog_entry_id: fresh.id, finish: nil).pick(:quantity, :location_id)).to eq([ 1, deck.zone("considering").id ])
  end

  it "writes a proxy-only change without clearing the working state, and a second apply is nothing to change (AC-7.11)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    data = export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 3) ])
    preview(data)
    allow(CollectionImport::WorkingState).to receive(:clear!)

    apply

    expect(CollectionImport::WorkingState).not_to have_received(:clear!)
    expect(Deck::Proxy.sole.quantity).to eq(3)
    preview(data)
    expect(html.text).to include("This file has nothing to change")
  end

  it "makes the preview stale when a proxy changes between the preview and the apply (AC-7.12)", :aggregate_failures do
    proxy = create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    preview(export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 3) ]))
    proxy.update!(quantity: 9)

    apply

    expect(response).to have_http_status(:conflict)
    expect(proxy.reload.quantity).to eq(9)
  end

  it "removes the proxies of a deck the file drops, counted among the removed (decision 16)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    data = export.merge("decks" => [], "proxies" => [], "lots" => [])
    preview(data)
    expect(html.at_css("label.c-check").text).to include("1 deck and 1 proxy")

    apply(confirm: true)

    expect([ Deck.count, Deck::Proxy.count ]).to eq([ 0, 0 ])
  end

  it "leaves the proxies of a version 3 file's collector alone and says so (AC-7.8)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)
    v3 = export.except("proxies", "decks").merge("format_version" => 3, "lots" => [])
    v3["lots"] = []

    preview(v3)

    expect(html.at_css("#decks_stay").text).to include("so your decks would stay")
    expect(html.at_css("#decks_stay").text).to include("This file was written before proxies existed, so your proxies would stay.")
    expect(html.at_css("#proxies")).to be_nil
  end

  it "lists a proxy row with problems as 'Proxy N', says the file can't be applied, and stores nothing (AC-7.6)", :aggregate_failures do
    create(:deck_proxy, zone: deck.zone("main"), account:, entry:, finish: "foil", quantity: 2)

    preview(export.merge("proxies" => [ export["proxies"].first.merge("quantity" => 0) ]))

    expect(response).to have_http_status(:ok)
    expect(html.text).to include("This file can't be applied")
    expect(html.at_css("#problem_proxies li .c-import__number").text).to eq("Proxy 1")
    expect(html.at_css("#problem_proxies li").text).to include("quantity isn't valid")
    expect(account.reload.import_upload).to be_nil
  end

  it "refuses a version 4 file without proxies as not well-formed (AC-7.5)", :aggregate_failures do
    preview(export.except("proxies"))

    expect(response).to have_http_status(:unprocessable_content)
    expect(html.text).to include("proxies")
  end

  it "writes rows the model accepts, with an account, a zone of a deck, a listed finish and a quantity in range (AC-7.10)", :aggregate_failures do
    deck
    data = export.merge("proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 7 } ])
    preview(data)

    apply

    proxy = Deck::Proxy.sole
    expect(proxy.valid?).to be(true)
    expect([ proxy.account, proxy.zone, proxy.entry, proxy.finish, proxy.quantity ]).to eq([ account, deck.zone("main"), entry, "foil", 7 ])
    expect(proxy.created_at).to be_within(1.minute).of(Time.current)
  end

  it "clears no working state for a proxy-only change (AC-7.11)", :aggregate_failures do
    deck
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16))
    data = export.merge("decks" => [ { "name" => "Izzet Tempo", "collectible_type" => "mtg", "format" => "modern" } ],
                        "proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 1 } ])
    preview(data)

    apply

    expect(account.reload.number_entry).to be_present
    expect(Deck::Proxy.count).to eq(1)
  end

  it "clears the working state when the same file also changes a lot (spec 028 decision 7)", :aggregate_failures do
    deck
    NumberEntry.add!(account:, entry:, quantity: 1, finish: "foil", line_key: SecureRandom.hex(16))
    data = export.merge("decks" => [ { "name" => "Izzet Tempo", "collectible_type" => "mtg", "format" => "modern" } ],
                        "proxies" => [ { "deck" => "Izzet Tempo", "zone" => "main", "entry" => entry_hash(entry), "finish" => "foil", "quantity" => 1 } ],
                        "lots" => [ { "entry" => entry_hash(entry), "quantity" => 2, "finish" => "foil", "condition" => nil, "price_paid" => nil, "location" => nil,
                                      "added_at" => "2026-11-01T10:00:00Z", "changed_at" => "2026-11-01T10:00:00Z" } ])
    preview(data)

    apply

    expect(account.reload.number_entry).to be_nil
    expect(Deck::Proxy.count).to eq(1)
  end
end
