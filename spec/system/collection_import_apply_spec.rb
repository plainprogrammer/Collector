require "rails_helper"

# Spec 028 AC-7.2: choose a file, preview it, apply it.
RSpec.describe "Apply an import", type: :system do
  let!(:user) { system_sign_in_as(create(:user)) }
  let(:path) { Rails.root.join("tmp/import-apply-#{SecureRandom.hex(4)}.json") }

  after { FileUtils.rm_f(path) }

  it "ends on the collection with a notice and the file's lots", :aggregate_failures do
    kept = create(:mtg_printing).entry
    other = create(:mtg_printing).entry
    create(:lot, account: user.account, entry: other, quantity: 2)
    path.write(JSON.generate(import_file(user, [ import_row(kept, quantity: 3) ])))

    visit new_collection_import_preview_path
    attach_file "Export file", path.to_s
    click_on "Preview import"
    expect(page).to have_button("Apply import")
    check "I understand this removes 1 lot"
    click_on "Apply import"

    expect(page).to have_css("#status", text: "Imported: 1 lot added, 0 changed, 1 removed")
    expect(page).to have_text(kept.name)
    expect(user.account.lots.pluck(:quantity)).to eq([ 3 ])
  end
end
