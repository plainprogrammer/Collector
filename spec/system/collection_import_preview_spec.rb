require "rails_helper"

# Spec 025 AC-5.3: "Import collection" in the account menu leads to the upload page, and an export file previews.
RSpec.describe "Import preview", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:path) { Rails.root.join("tmp/import-preview-#{SecureRandom.hex(4)}.json") }
  let(:own_export) do
    deck = create(:deck, account: user.account, name: long_name)
    create_lot_in_zone(deck, "main", quantity: 3)
    create(:deck, account: user.account, name: "Elves", format: "commander")
    JSON.parse(CollectionExport.new(account: user.account, at: Time.current).to_json)
  end
  let(:long_name) { "Izzet Tempo with a rather long name for a phone" }

  after { FileUtils.rm_f(path) }


  it "previews an export file chosen from the account menu", :aggregate_failures do
    create(:lot, account: user.account, entry: create(:mtg_printing).entry, quantity: 2)
    path.write(CollectionExport.new(account: user.account, at: Time.current).to_json)
    visit collection_path
    find(".c-avatar").click
    click_on "Import collection"
    attach_file "Export file", path.to_s
    click_on "Preview import"

    expect(page).to have_css("h1", text: "Import preview")
    expect(page).to have_text("This file can be applied.")
    within(find(".c-stat", text: "Lots unchanged")) { expect(page).to have_css("dd", text: "1") }
  end

  # A version 3 file whose one lot is in a location the file doesn't list.
  def version_three_file(entry)
    row = { "entry" => { "collectible_type" => entry.collectible_type, "source_id" => entry.external_key, "name" => entry.name,
                         "set_code" => entry.set.code, "collector_number" => entry.number, "language" => entry.language },
            "quantity" => 1, "finish" => nil, "condition" => nil, "price_paid" => nil, "location" => "Nowhere in the file",
            "added_at" => "2026-10-01T10:00:00Z", "changed_at" => "2026-10-01T10:00:00Z" }
    { "format" => "collector-export", "format_version" => 3, "exported_at" => "2026-10-15T09:00:00Z",
      "profile" => { "name" => user.name, "email_address" => user.email_address, "collection_view" => user.collection_view },
      "currency" => "USD", "locations" => [ { "name" => "Elsewhere" } ], "lots" => [ row ] }
  end

  # Spec 032 AC-10.3, AC-10.9: a version 3 preview with a removed lot and a problem row fits the narrowest window headless Firefox
  # opens (500px; a phone's 360px is the same layout, as the other import pages' checks hold).
  it "fits a 500px window for a version 3 file with a removed lot in a location and a problem row", :aggregate_failures do
    blue = create(:location, account: user.account, name: "Blue binder with a rather long name for a phone")
    create(:lot, account: user.account, entry: create(:mtg_printing).entry, quantity: 2, location: blue)
    path.write(JSON.generate(version_three_file(create(:mtg_printing).entry)))
    page.driver.browser.manage.window.resize_to(500, 900)
    visit new_collection_import_preview_path
    attach_file "Export file", path.to_s
    click_on "Preview import"

    expect(page).to have_text("Its location “Nowhere in the file” isn't one of the file's locations.")
    expect(page).to have_text("in Blue binder with a rather long name for a phone")
    expect(page_fits_sideways?).to be(true)
  end

  # Spec 062 AC-7.1, AC-7.5: the collector's own export, decks and a copy in a zone included, previews with the Decks section; a
  # version 4 file with a changed deck and a removed deck fits the narrowest window headless Firefox opens.
  def preview_file(data)
    path.write(JSON.generate(data))
    visit new_collection_import_preview_path
    attach_file "Export file", path.to_s
    click_on "Preview import"
  end


  it "shows the Decks section of the collector's own export", :aggregate_failures do
    preview_file(own_export)

    expect(page).to have_css("#decks .c-section__title", text: "Decks")
    within(find(".c-stat", text: "Decks unchanged")) { expect(page).to have_css("dd", text: "2") }
  end

  it "fits 500px for a file that changes one deck's format and removes another", :aggregate_failures do
    data = own_export
    data["decks"] = data["decks"].select { |deck| deck["name"] == long_name }.map { |deck| deck.merge("format" => "casual") }
    page.driver.browser.manage.window.resize_to(500, 900)
    preview_file(data)

    expect(page).to have_css("#format_changed_decks li", text: "#{long_name}:")
    expect(page).to have_css("#removed_decks li", text: "Elves")
    expect(page_fits_sideways?).to be(true)
  end
end
