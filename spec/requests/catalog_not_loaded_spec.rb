require "rails_helper"

# Spec 015 Story 1 and FR-6: while a catalog has no applied refresh, the pages where people look for cards say so.
RSpec.describe "The not-loaded notice", type: :request do
  def notice = Nokogiri::HTML5(response.body).at_css("main #catalog_not_loaded.c-status__message--alert")

  def notice_text = notice&.text&.squish

  context "when the catalog isn't loaded" do
    before { create(:catalog_refresh_run, status: "failed") }

    it "tells an admin on search, the scanner and More, with the way to load it (AC-1.1)", :aggregate_failures do
      sign_in_as(create(:admin))

      [ catalog_entries_path, scanner_path, more_path ].each do |path|
        get path
        expect(notice_text).to eq("The card catalog hasn't been loaded yet. Go to the catalog page to load it."), path
        expect(notice.at_css("a")["href"]).to eq(admin_catalog_path), path
      end
    end

    it "tells a member on search and the scanner to ask an admin, with no link (AC-1.2)", :aggregate_failures do
      sign_in_as(create(:user))

      [ catalog_entries_path, scanner_path ].each do |path|
        get path
        expect(notice_text).to eq("The card catalog hasn't been loaded yet. Ask an admin to load it."), path
        expect(notice.at_css("a")).to be_nil, path
      end
      get more_path
      expect(notice).to be_nil
    end
  end

  it "says nothing once a refresh has applied (AC-1.3)", :aggregate_failures do
    create(:catalog_refresh_run, status: "applied")
    sign_in_as(create(:admin))

    [ catalog_entries_path, scanner_path, more_path ].each do |path|
      get path
      expect(notice).to be_nil, path
    end
  end

  context "with more than one catalog type", :other_catalog do
    before { sign_in_as(create(:admin)) }

    it "names the one type that isn't loaded (FR-6)" do
      create(:catalog_refresh_run, status: "applied")

      get catalog_entries_path

      expect(notice_text).to eq("The Pocket Monsters catalog hasn't been loaded yet. Go to the catalog page to load it.")
    end

    it "names every type that isn't loaded (FR-6)" do
      get catalog_entries_path

      expect(notice_text).to eq("The Magic: The Gathering and Pocket Monsters catalogs haven't been loaded yet. " \
        "Go to the catalog page to load them.")
    end
  end

  it "queues no refresh when the first admin signs up (AC-1.5, FR-6)", :aggregate_failures do
    expect {
      post registration_path, params: { user: { name: "Ann", email_address: "ann@example.test", password: "correct horse battery",
                                                password_confirmation: "correct horse battery" } }
    }.not_to have_enqueued_job

    expect(User.sole).to be_admin
  end
end
