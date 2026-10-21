require "rails_helper"

# Spec 015 AC-7.3: admins find the catalog and jobs pages where they find user administration. More also holds "Add by
# number" after the export and the import, which the avatar menu doesn't (spec 026, superseding spec 022 decision 6), and Locations before the export (spec 029).
RSpec.describe "Admin navigation", type: :request do
  def links(selector) = Nokogiri::HTML5(response.body).css("#{selector} a").map { |link| [ link.text.squish, link["href"] ] }

  it "links Catalog and Jobs for an admin, on the More page and in the avatar menu", :aggregate_failures do
    sign_in_as(create(:admin))

    get more_path

    menu = [ [ "Export collection", collection_export_path ], [ "Import collection", new_collection_import_preview_path ] ]
    admin = [ [ "Users and sign-up", admin_users_path ], [ "Catalog", admin_catalog_path ], [ "Jobs", admin_jobs_path ] ]
    expect(links(".c-more")).to eq([ [ "Locations", locations_path ], *menu, [ "Add by number", collection_number_entry_path ], *admin ])
    expect(links(".c-appbar .c-menu__list")).to eq([ *menu, *admin ])
  end

  it "shows a member the export, the import and Add by number, neither admin link", :aggregate_failures do
    sign_in_as(create(:user))

    get more_path

    menu = [ [ "Export collection", collection_export_path ], [ "Import collection", new_collection_import_preview_path ] ]
    expect(links(".c-more")).to eq([ [ "Locations", locations_path ], *menu, [ "Add by number", collection_number_entry_path ] ])
    expect(links(".c-appbar .c-menu__list")).to eq(menu)
  end
end
