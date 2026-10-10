require "rails_helper"

# Spec 015 AC-7.3: admins find the catalog and jobs pages where they find user administration.
RSpec.describe "Admin navigation", type: :request do
  def links(selector) = Nokogiri::HTML5(response.body).css("#{selector} a").map { |link| [ link.text.squish, link["href"] ] }

  it "links Catalog and Jobs for an admin, on the More page and in the avatar menu", :aggregate_failures do
    sign_in_as(create(:admin))

    get more_path

    expected = [ [ "Users and sign-up", admin_users_path ], [ "Catalog", admin_catalog_path ], [ "Jobs", admin_jobs_path ] ]
    expect(links(".c-more")).to eq(expected)
    expect(links(".c-appbar .c-menu__list")).to eq(expected)
  end

  it "shows a member neither link", :aggregate_failures do
    sign_in_as(create(:user))

    get more_path

    expect(links(".c-more")).to be_empty
    expect(links(".c-appbar .c-menu__list")).to be_empty
  end
end
