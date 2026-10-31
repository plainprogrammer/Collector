require "rails_helper"

# Spec 025 AC-5.3: "Import collection" in the account menu leads to the upload page, and an export file previews.
RSpec.describe "Import preview", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:path) { Rails.root.join("tmp/import-preview-#{SecureRandom.hex(4)}.json") }

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
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end
end
