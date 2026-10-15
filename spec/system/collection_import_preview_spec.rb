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
end
