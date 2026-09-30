require "rails_helper"

# AC-1.5: every page this feature builds fits a 360px screen. Firefox won't open a window
# narrower than 500px, so each page is loaded in a 360px frame (spec/support/narrow_frame.rb).
RSpec.describe "Pages at 360px", type: :system do
  it "never scrolls sideways", :aggregate_failures do
    user = create(:admin)
    lot = create(:lot, account: user.account, quantity: 9_999)
    visit new_session_path
    [ new_session_path, new_registration_path ].each do |path|
      expect(open_in_narrow_frame(path, width: 360, height: 800, ready: "main")).to eq([ 360, true ]), "#{path} scrolls sideways at 360px"
    end
    system_sign_in_as(user)
    expect(page).to have_css(".c-avatar") # signed in; the frame must not be added to the sign-in page mid-redirect
    [ collection_path, catalog_entries_path(q: lot.entry.name), catalog_entry_path(lot.entry), catalog_identity_path(lot.entry.identity),
      new_catalog_entry_lot_path(lot.entry), edit_lot_path(lot), new_lot_removal_path(lot), more_path, admin_users_path,
      new_admin_user_path ].each do |path|
      expect(open_in_narrow_frame(path, width: 360, height: 800, ready: "main")).to eq([ 360, true ]), "#{path} scrolls sideways at 360px"
    end
  end
end
